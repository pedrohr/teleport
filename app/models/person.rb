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

  POST = Net::HTTP::Post
  DELETE = Net::HTTP::Delete
  PUT = Net::HTTP::Put

  class Logger
    def self.log_send(json, address)
      puts "\n\n"
      puts "Teleporting data to #{address}"
      puts "   #{json.to_s}"
      puts "Completed.\n"
    end
  end

  def commit(json, method)
    begin
      Teleconfig.new.get_targets.each{ |address|
        uri = URI.parse(address)
        http = Net::HTTP.new(uri.host,uri.port)
        req = method.new(uri.request_uri)
        req.body = json
        req["Content-Type"] = "application/json"
        response = http.request(req)
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

  #ISSUE: dont need to send the whole JSON. Just the key.

  def after_create(record)
    json = record.to_json
    commit(json, POST)
  end

  def after_destroy(record)
    json = record.to_json
    commit(json, DELETE)
  end
end

class Person < ActiveRecord::Base
  after_create Teleport.new
  after_destroy Teleport.new
end
