#!/usr/bin/env ruby

# file: rsf_services.rb

require 'rscript'
require 'dws-registry'
require 'logger'


class RSFServices < RScript

  def initialize(reg_path='', package_basepath: '')
    super()

    @services = {}
    @package_basepath = package_basepath

    if reg_path.length > 0 then

      @services['registry'] = reg = DWSRegistry.new reg_path

      # load the system/startup RSF jobs
      jobs = reg.get_keys('system/startup/.[load="1"]').inject({}) do |r, job|
        settings = reg.get_keys("system/packages/#{job.name}/*")\
                          .inject({}){|r,x| r.merge(x.name.to_sym => x.text) }
        r.merge(job.name => settings)
      end

      jobs.each do |package, settings| 
        r = run_job(package.to_s, '//job:load', settings, 
                                                package_path: settings[:url])
      end
    end

  end

  def run_job(package, jobs, params={}, *qargs, 
                  package_path: ("%s/%s.rsf" % [@package_basepath, package]))

    yield(params) if block_given?
    result, args = read([package_path, jobs.split(/\s/),qargs].flatten)

    rws = self
    
    begin

      r = eval result
      return r

    rescue Exception => e  
      params = {}
      err_label = e.message.to_s + " :: \n" + e.backtrace.join("\n")      
      log(err_label)
    end

  end

  def log(msg)
    if @log == true then
      @logger.debug msg
    end
  end
    
end
