# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "opal/vienna/pouchdb_adapter/version"

Gem::Specification.new do |spec|
  spec.name          = "vienna-pouchdb"
  spec.version       = Vienna::PouchDBAdapter::VERSION
  spec.authors       = ["Vitor Capela"]
  spec.email         = ["dodecaphonic@gmail.com"]

  spec.summary       = "A Vienna Adapter for PouchDB"
  spec.description   = "vienna-pouchdb-adapter bridges Vienna and PouchDB using opal-pouchdb"
  spec.homepage      = "https://github.com/dodecaphonic/vienna-pouchdb-adapter"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables      = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  spec.test_files       = `git ls-files -- {test,spec,features}/*`.split("\n")
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "opal", ">= 0.7.0", "< 0.9.0"
  spec.add_runtime_dependency "opal-vienna", "~> 0.7.0"
  spec.add_runtime_dependency "opal-pouchdb", "~> 0.1.1"
  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "opal-rspec", "~> 0.4.0"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "rake", "~> 10.0"
end
