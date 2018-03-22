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
    
    def initialize(parent, package_basepath, type: :get)      
      @parent, @package_basepath, @type = parent, package_basepath, type
      @parent.type = type
    end
    
    private
    
    def method_missing(method_name, *args)
      Package.new @parent, @package_basepath, method_name.to_s
    end        
    
  end  
  
  
  class Package
    
    def initialize(obj, parent_url, package)

      @obj, @package = obj, package

      @url = File.join(parent_url, package + '.rsf')
      doc = Rexle.new open(@url, 
                           'UserAgent' => 'RSFServices::Package reader').read
      a = doc.root.xpath 'job/attribute::id'
      
      a.each do |attr|
        method_name = attr.value.gsub('-','_') 
        method = "def %s(*args); run_job('%s', args) ; end" % \
                                                            ([method_name] * 2)
        self.instance_eval(method)
      end

    end

    private
    
    def run_job(method_name, *args)
      
      args.flatten!(1)
      params = args.pop if args.find {|x| x.is_a? Hash}
      a = ['//job:' + method_name, @url, args].flatten(1)
  
      @obj.run a #, params
    end
    

  end  

  attr_reader :services

  def initialize(reg=nil, package_basepath: '', log: nil)
    
    @log = log

    super(log: log)

    @package_basepath, @services = package_basepath, {}

    if reg then

      @services['registry'] = if reg.is_a? String then
        reg = DWSRegistry.new reg_path
      else
        reg
      end
      
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
  
  def get()
    PackageMethod.new self, @package_basepath, type: :get
  end  
  
  def post()
    PackageMethod.new self, @package_basepath, type: :post
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
    Package.new self, @package_basepath, method_name.to_s
  end    
  
end
