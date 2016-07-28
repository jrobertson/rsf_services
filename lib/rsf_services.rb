#!/usr/bin/env ruby

# file: rsf_services.rb

require 'rscript'
require 'dws-registry'
require 'logger'


class RSFServices < RScript
  
  # this class (Package) is a modified copy of the code from 
  # the rsf_services gem on 28-Jul 2016
  
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

  def initialize(reg=nil, package_basepath: '', logfile: nil)
    
    @log = Logger.new logfile, 'daily' if logfile

    super(logfile: logfile)

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

  def run_job(package, jobs, params={}, *qargs, 
                  package_path: ("%s/%s.rsf" % [@package_basepath, package]))

    log 'run job' + ("package: %s jobs: %s params: %s qargs: %s " + \
            " package_path: %s" % [package, jobs, params, qargs, package_path])
    yield(params) if block_given?    
    
    a = [package_path, jobs.split(/\s/).map{|x| "//job:%s" % x} ,qargs].flatten

    result, args = read(a)

    rws = self

    begin
      
      log 'result : ' +  result

      r = eval result
      
      log  'r : ' + r.inspect
      return r

    rescue Exception => e  
      params = {}
      err_label = e.message.to_s + " :: \n" + e.backtrace.join("\n")      
      log 'err_label : ' + err_label.inspect
      log(err_label)
    end
    
  end  
  
  
  private
  
  def log(msg)

    @log.debug ':::'  + msg[0..250] if @log

  end
  
  def method_missing(method_name, *args)
    Package.new self, @package_basepath, method_name.to_s
  end    
   
end