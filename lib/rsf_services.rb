#!/usr/bin/env ruby

# file: rsf_services.rb

require 'rscript'
require 'dws-registry'


class RScriptRW < RScript
  
  attr_accessor :type
  
  def initialize(log: log)
    super(log: log)
  end
  
  def read(args=[])
    
    @log.info 'RScript/read: args: '  + args.inspect if @log
    
    threads = []
    
    if args.to_s[/\/\/job:/] then 

      ajob = []
      
      args.each_index do |i| 
        if args[i].to_s[/\/\/job:/] then          
          ajob << "@id='#{$'}' and @type='#{self.type.to_s}'"; args[i] = nil
        end
      end

      args.compact!

      out = read_rsf(args) do |doc|
        
        doc.root.xpath('//job').each do |x| 
          x.attributes[:type] = type.to_s unless x.attributes[:type]
        end
        
        if @log then
          @log.info 'RScriptRW/read: code: '  + doc.xml.inspect         
        end
        
        doc.root.xpath("//job[#{ajob.join(' or ')}]").map do |job|
          job.xpath('script').map {|s| read_script(s)}.join("\n")
        end.join("\n")        
      end

      raise "job not found" unless out.length > 0
      out
      
    else    
      out = read_rsf(args) {|doc| doc.root.xpath('//script')\
                            .map {|s| read_script(s)}}.join("\n") 
    end    
          
    @log.info 'RScript/read: code: '  + out.inspect if @log

    [out, args]    
    
  end
  
end

class RSFServices < RScriptRW
  
  class PackageMethod
    
    def initialize(parent, type: :get)      
      @parent = parent
      @parent.type = type
    end
    
    private
    
    def method_missing(method_name, *args)
      Package.new @parent, method_name.to_s
    end        
    
  end  
  
  
  class Package
    
    def initialize(obj, package, debug: debug)

      @obj, @package, @debug = obj, package, debug

      @url = File.join(@obj.package_basepath, package + '.rsf')
      doc = Rexle.new open(@url, 
                           'UserAgent' => 'RSFServices::Package reader').read
      a = doc.root.xpath 'job/attribute::id'
      
      a.each do |attr|
        
        method_name = attr.value.gsub('-','_') 

        define_singleton_method method_name.to_sym do |*args|
          run_job method_name, args
        end

      end

    end

    private
    
    def run_job(method_name, *args)
      
      puts 'inside Package::run_job: args: ' + args.inspect if @debug
      
      args.flatten!(1)
      params = args.find {|x| x.is_a? Hash} ? args.pop : {}
      a = ['//job:' + method_name, @url, args].flatten(1)
      
      if @debug then
        puts 'a: ' + a.inspect
        puts 'params: ' + params.inspect
      end
      
      @obj.run a, params
    end
    

  end  

  attr_reader :services, :package_basepath, :registry

  def initialize(reg=nil, package_basepath: '', log: nil, debug: true)
    
    @log, @debug = log, debug

    super(log: log)

    @package_basepath, @services = package_basepath, {}

    if reg then

      @registry = @services['registry'] = reg
      
      # load the system/startup RSF jobs

      startup = reg.get_key('system/startup')
      
      jobs =  startup.xpath('*[load="1"]').inject({}) do |r, job|
        settings = reg.get_keys("system/packages/#{job.name}/*")\
                          .inject({}){|r,x| r.merge(x.name.to_sym => x.text) }
        r.merge(job.name => settings)
      end
      
      jobs.each do |package, settings| 
        r = run_job(package.to_s, 'load', settings, 
                                                package_path: settings[:url])
      end
    end

  end
  
  
  def delete()
    PackageMethod.new self, type: :delete
  end    
  
  def get()
    PackageMethod.new self
  end  
  
  def put()
    PackageMethod.new self, type: :put
  end  
  
  def post()
    PackageMethod.new self, type: :post
  end

  def run_job(package, jobs, params={}, *qargs, 
                  package_path: ("%s/%s.rsf" % [@package_basepath, package]))

    if @log then
      @log.info 'RSFServices/run job: ' + 
          ("package: %s jobs: %s params: %s qargs: %s " + \
            " package_path: %s" % [package, jobs, params, qargs, package_path])
    end
    
    yield(params) if block_given?    
    
    a = [package_path, jobs.split(/\s/).map{|x| "//job:%s" % x} ,qargs].flatten

    c, args = read(a)

    rws = self

    begin
      
      @log.info 'RSFServices/run job: code: ' + c if @log 

      r = eval c
      
      @log.info 'RSFServices/run job: result: ' + r if @log 
      
      return r

    rescue Exception => e  
      
      params = {}
      err_label = e.message.to_s + " :: \n" + e.backtrace.join("\n")            
      @log.debug 'RSFServices/run_job/error: ' + err_label if @log

    end
    
  end    
  
  private
  
  def method_missing(method_name, *args)
    self.type = :get
    Package.new self, method_name.to_s, debug: @debug
  end    
  
end
