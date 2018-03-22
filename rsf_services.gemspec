Gem::Specification.new do |s|
  s.name = 'rsf_services'
  s.version = '0.5.2'
  s.summary = 'Runs within a DRb server to run RSF jobs, as well as ' + 
      'other services.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/rsf_services.rb']
  s.add_runtime_dependency('rscript', '~> 0.4', '>= 0.4.0')
  s.add_runtime_dependency('dws-registry', '~> 0.4', '>= 0.4.0')
  s.signing_key = '../privatekeys/rsf_services.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/rsf_services'
  s.required_ruby_version = '>= 2.1.2'
end
