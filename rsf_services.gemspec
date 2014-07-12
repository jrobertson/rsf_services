Gem::Specification.new do |s|
  s.name = 'rsf_services'
  s.version = '0.1.1'
  s.summary = 'Designed to run within a server to run RSF jobs, as well as otherservices.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_runtime_dependency('rscript', '~> 0.1', '>= 0.1.25')
  s.add_runtime_dependency('dws-registry', '~> 0.1', '>= 0.1.3')
  s.signing_key = '../privatekeys/rsf_services.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/rsf_services'
  s.required_ruby_version = '>= 2.1.2'
end
