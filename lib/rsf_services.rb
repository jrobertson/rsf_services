#!/usr/bin/env ruby

# file: rsf_services.rb

require 'rscript'
require 'dws-registry'
require 'logger'


class RSFServices < RScript

  attr_reader :services

  def initialize(reg=nil, package_basepath: '', logfile: nil)
    
    @log = Logger.new logfile, 'daily' if logfile

    super(log: logfile)

    @package_basepath, @services = package_basepath, {}

    if reg then

      @services['registry'] = if reg.is_a? String then
        #reg = DWSRegistry.new reg_path
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
    
end