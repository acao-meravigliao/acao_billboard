#!/usr/bin/env ruby
#
# Copyright (C) 2015-2015, Daniele Orlandi
#
# Author:: Daniele Orlandi <daniele@orlandi.com>
#
# License:: You can redistribute it and/or modify it under the terms of the LICENSE file.
#

require 'ygg/agent/base'

require 'acao_billboard/version'
require 'acao_billboard/task'

module AcaoBillboard

class App < Ygg::Agent::Base
  self.app_name = 'acao_billboard'
  self.app_version = VERSION
  self.task_class = Task

  def prepare_default_config
    app_config_files << File.join(File.dirname(__FILE__), '..', 'config', 'acao_billboard.conf')
    app_config_files << '/etc/yggdra/acao_billboard.conf'
  end

  def agent_boot
  end
end
