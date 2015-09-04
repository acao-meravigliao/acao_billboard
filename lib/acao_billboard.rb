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

require 'serialport'

module AcaoBillboard

class App < Ygg::Agent::Base
  self.app_name = 'acao_billboard'
  self.app_version = VERSION
  self.task_class = Task

  def prepare_options(o)
    o.on("--debug-out", "Shows output messages") { |v| @config['acao_billboard.debug_out'] = true }

    super
  end

  def prepare_default_config
    app_config_files << File.join(File.dirname(__FILE__), '..', 'config', 'acao_billboard.conf')
    app_config_files << '/etc/yggdra/acao_billboard.conf'
  end

  def agent_boot
    @msg_queue = @amqp.ask(AM::AMQP::MsgDeclareQueue.new(
      name: 'ygg.acao.billboard.queue',
      options: {
        durable: false,
        auto_delete: true,
      }
    )).value.queue_id

    @msg_exchange = @amqp.ask(AM::AMQP::MsgDeclareExchange.new(
      name: 'ygg.acao.meteo',
      type: :topic,
      options: {
        durable: true,
        auto_delete: false,
      }
    )).value.exchange_id

    @amqp.ask(AM::AMQP::MsgBind.new(queue_id: @msg_queue, exchange_id: @msg_exchange, options: { routing_key: '#' })).value

    @msg_consumer = @amqp.ask(AM::AMQP::MsgSubscribe.new(
      queue_id: @msg_queue,
      send_to: self.actor_ref,
      manual_ack: true)).value.consumer_tag

    @serial = SerialPort.new(
      @config['acao_billboard.serial.device'],
      'baud' => @config['acao_billboard.serial.speed'],
      'data_bits' => 8,
      'stop_bits' => 1,
      'parity' => SerialPort::NONE)

    @keys_freshness = {}
    @meteo = {}

    every(5.seconds) do
      head = "A.C.A.O.  128.45 MHz".ljust(20)
      datetime = (Time.now.strftime "%H:%M   %d/%m/%Y").ljust(20)

      if @keys_freshness['wind_speed'] && @keys_freshness['wind_speed'] > (Time.now - 30.seconds)
        gust = @meteo['wind_2m_gst'].to_f > 4 ?
                "\x11Gst #{'%.0f' % (@meteo['wind_2m_gst'].to_f * 3.6)}" :
                ""

        wind = "#{wind_dir_name2(wind: @meteo['wind_dir'])} #{'%.2g' % ('%.1f' % (@meteo['wind_speed'].to_f * 3.6))} km/h #{gust}".ljust(22)
      else
        wind = 'INOP'
      end

      if @keys_freshness['qfe'] && @keys_freshness['qfe'] > (Time.now - 30.seconds)
        pressuretemp = "QNH #{'%.0f' % (@meteo['qnh'] / 100)} hPa #{'%0.0f' % @meteo['temperature']} C".ljust(20)
      else
        pressuretemp = 'INOP'
      end

      if mycfg.debug_out
        log.info '*' * (20+2)
        log.info '*' + head + '*'
        log.info '*' + datetime + '*'
        log.info '*' + wind + '*'
        log.info '*' + pressuretemp + '*'
        log.info '*' * (20+2)
      end

      @serial.write(
        "\x02\x01" +
#        "\x18\x1E#{head}\x02" +
        "\x18\x1E#{datetime}\x02" +
        "\x18\x1E#{wind}\x02" +
        "\x18\x1E#{''.ljust(22)}\x02" +
        "\x18\x1E#{pressuretemp}\x02\x00")
    end
  end

  def actor_shutdown
    @serial.write("\x02\x01" +
      "\x19\x1E#{'INOP'.ljust(22)}\x02" +
      "\x19\x1E#{'INOP'.ljust(22)}\x02" +
      "\x19\x1E#{'INOP'.ljust(22)}\x02" +
      "\x19\x1E#{'INOP'.ljust(22)}\x02\x00")
  end

  def handle(message)
    case message
    when AM::AMQP::MsgDelivery
      if message.delivery_info.consumer_tag == @msg_consumer
#        if message.payload['msg_type'] == 'station_update'
#          log.info "From #{message.payload['station_id']} #{message.payload['data']['wind_speed']}"

        message.payload['data'].keys.each do |key|
          @keys_freshness[key] = message.properties[:timestamp]
        end

        @meteo.merge!(message.payload['data'])

#        end

        @amqp.tell AM::AMQP::MsgAck.new(delivery_tag: message.delivery_info.delivery_tag)
      else
        super
      end
    else
      super
    end
  end

  protected

  def wind_dir_name(wind:, range: 360)
    s = range / 16.0

    name = case wind % range
    when 0..s, s*15..range  ; 'N'
    when s*1..s*3           ; 'NE'
    when s*3..s*5           ; 'E'
    when s*5..s*7           ; 'SE'
    when s*7..s*9           ; 'S'
    when s*9..s*11          ; 'SW'
    when s*11..s*13         ; 'W'
    when s*13..s*15         ; 'NW'
    end
  end

  def wind_dir_name2(wind:, range: 360)
    s = range / 32.0

    name = case wind % range
    when 0..s, s*31..range  ; 'N'
    when s*1..s*3           ; 'NNE'
    when s*3..s*5           ; 'NE'
    when s*5..s*7           ; 'ENE'
    when s*7..s*9           ; 'E'
    when s*9..s*11          ; 'ESE'
    when s*11..s*13         ; 'SE'
    when s*13..s*15         ; 'SSE'
    when s*15..s*17         ; 'S'
    when s*17..s*19         ; 'SSW'
    when s*19..s*21         ; 'SW'
    when s*21..s*23         ; 'WSW'
    when s*23..s*25         ; 'W'
    when s*25..s*27         ; 'WNW'
    when s*27..s*29         ; 'NW'
    when s*29..s*31         ; 'NNW'
    end
  end
end

end
