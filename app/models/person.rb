# -*- coding: utf-8 -*-
require 'pp'
require 'json'

require 'net/http'
require 'uri'

class Teleconfig
  private
  @@targets = ["http://127.0.0.1:3001"]

  public
  def get_targets
    return @@targets
  end
end

class Teleport < Teleconfig
#  @attributes = nil
#  def initialize
#    @attributes = nil
#  end

#  def initialize(attributes)
#    @attributes = attributes
#  end

  class Logger
    def self.log_send(json, address)
      puts "\n\n"
      puts "Teleporting data to #{address}"
      puts "   #{json.to_s}"
      puts "Completed.\n"
    end
  end

  def commit(json)
    begin
      Teleconfig.new.get_targets.each{ |address|
        uri = URI.parse(address)
        http = Net::HTTP.new(uri.host,uri.port)
        req = Net::HTTP::Put.new(uri.request_uri)
        req.body = json
        req["Content-Type"] = "application/json"
        response = http.request(req)
#        puts "Response #{response.code} #{response.message}:
#          #{response.body}"
        Logger.log_send(json, address)
      }
    rescue Errno::ECONNREFUSED => e
      puts "============================================="
      puts "Server not online."
      puts e.message
      puts "============================================="
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      puts "============================================="
      puts "Fail!"
      puts e.message
      puts "============================================="
    end
  end

  def after_save(record)
    json = record.to_json
    commit(json)
  end

  def after_destroy(record)
    json = record.to_json
    commit(json)
  end
end


class Person < ActiveRecord::Base
  after_save Teleport.new
  after_destroy Teleport.new
end
