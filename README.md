# Introducing the RSF_services gem

The RSF_services gem provides a convenient way to run a Ruby Script File (RSF) related service as well as adhoc jobs. When a new RSFServices object is initialized it reads the XML registry to run the jobs which are present within the system/startup section.

## installation

`gem install rsf_services`


## Example

    require 'rsf_services'

    rs = RSFServices.new '/tmp/registry.xml'

file: /tmp/registry.xml

<pre>
&lt;?xml version='1.0' encoding='UTF-8'?&gt;
&lt;root&gt;
  &lt;system&gt;
    &lt;startup&gt;
      &lt;r2&gt;
        &lt;load&gt;1&lt;/load&gt;
      &lt;/r2&gt;
    &lt;/startup&gt;
    &lt;packages&gt;
      &lt;r2&gt;
        &lt;url&gt;http://a0.jamesrobertson.eu/qbx/r/dandelion_a2/r2.rsf&lt;/url&gt;
      &lt;/r2&gt;
    &lt;/packages&gt;
  &lt;/system&gt;
&lt;/root&gt;
</pre>

RSF package: http://a0.jamesrobertson.eu/qbx/r/dandelion_a2/r2.rsf

<pre>
&lt;package&gt;
  &lt;job id='load'&gt;  
    &lt;script&gt;      
      'params.inspect'
    &lt;/script&gt;  
  &lt;/job&gt;
&lt;/package&gt;    
</pre>

## Resources

* [jrobertson/rsf_services](https://github.com/jrobertson/rsf_services)

rsf_services gem
