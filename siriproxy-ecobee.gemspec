$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "siriproxy-ecobee"
  s.version     = "1.0"
  s.author      = "joshua stein"
  s.email       = "jcs@jcs.org"
  s.homepage    = "https://github.com/jcs/siriproxy-ecobee"
  s.summary     = %q{A Siri Proxy plugin to adjust an Ecobee thermostat}
  s.description = %q{This is a plugin for Siri Proxy that will communicate with Ecobee's website and perform actions or return data about an Ecobee Internet-enabled thermostat.}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "json"
  s.add_runtime_dependency "httparty"
end
