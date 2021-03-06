#
# Copyright (C) 2015-2015, Daniele Orlandi
#
# Author:: Daniele Orlandi <daniele@orlandi.com>
#
# License:: You can redistribute it and/or modify it under the terms of the LICENSE file.
#

$:.push File.expand_path('../lib', __FILE__)
require 'acao_billboard/version'

Gem::Specification.new do |s|
  s.name        = 'acao_billboard'
  s.version     = AcaoBillboard::VERSION
  s.authors     = ['Daniele Orlandi']
  s.email       = ['daniele@orlandi.com']
  s.homepage    = 'https://acao.it/'
  s.summary     = %q{Receives meteo info and shows it on the billboard}
  s.description = %q{Receives meteo info and shows it on the billboard}

  s.rubyforge_project = 'acao_billboard'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  # specify any dependencies here; for example:
  # s.add_development_dependency 'rspec'

  s.add_runtime_dependency 'ygg_agent', '~> 2.8'
  s.add_runtime_dependency 'activesupport'
  s.add_runtime_dependency 'serialport'
end
