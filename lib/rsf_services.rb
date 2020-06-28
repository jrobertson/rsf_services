#!/usr/bin/env ruby

# file: rsf_services.rb

#require 'rscript'
require 'app-mgr'
require 'dws-registry'



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
    
    def initialize(obj, package, debug: false)

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

  def initialize(reg=nil, package_basepath: '', log: nil, debug: false, 
                 app_rsf: nil)
    
    @log, @debug = log, debug
    
    puts 'inside RSF_services' if @debug

    super(log: log, debug: debug)

    @package_basepath, @services = package_basepath, {}
    
    @initialized = {}

    if reg then

      @registry = @services['registry'] = if reg.is_a? String then
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
    
    @app = AppMgr.new(rsf: app_rsf, reg: reg, rsc: self) if app_rsf

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

  def run_job(package, jobs, params={}, *qargs)
    
    puts 'inside run_job' #if @debug

    package_path = "%s/%s.rsf" % [@package_basepath, package]
                   
    if @log or @debug then
      msg = 'RSFServices/run job: ' + 
          ("package: %s jobs: %s params: %s qargs: %s " + \
            " package_path: %s" % [package, jobs, params, qargs, package_path])
      @log.info msg if @log
      puts msg if @debug
    end
    
    yield(params) if block_given?    
    
    a = [package_path, jobs.split(/\s/).map{|x| "//job:%s" % x} ,qargs].flatten(2)
    
    puts 'a: ' + a.inspect if @debug

    c, args, _ = read(a)
    puts 'c: ' + c.inspect if @debug
    rws, reg, app = self, @registry, @app

    begin
      
      @log.info 'RSFServices/run job: code: ' + c if @log and c.is_a? String

      # if there is a job id called *initialize* then execute if it hasn't 
      # already been executed

      if self.jobs(package_path).include? :initialize and 
          !@initialized[package_path]  and jobs != 'initialize' then
        run_job(package, 'initialize')
        @initialized[package_path] = true
      end

      r = eval c
      puts 'r: ' + r.inspect if @debug
      #thread = Thread.new {Thread.current[:v] = eval c}
      #thread.join
      #r = thread[:v] 
      
      @log.info 'RSFServices/run job: result: ' + r if @log and r.is_a? String
      
      return r

    rescue Exception => e  
      
      params = {}
      err_label = e.message.to_s + " :: \n" + e.backtrace.join("\n")            
      @log.debug 'RSFServices/run_job/error: ' + err_label if @log

    end
  
  end
  
  def package_methods(package)
    
    url = File.join(@package_basepath, package + '.rsf')    
    doc = Rexle.new open(url, 'UserAgent' => 'ClientRscript').read    
    doc.root.xpath('job/attribute::id').map {|x| x.value.to_s.gsub('-','_') }

  end
  
  private
  
  def method_missing2(method_name, *args)
    self.type = :get
    Package.new self, method_name.to_s, debug: @debug
  end    
  
end
