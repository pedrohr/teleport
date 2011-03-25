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

class Teletransporter < Teleconfig
#  @attributes = nil
#  def initialize
#    @attributes = nil
#  end

#  def initialize(attributes)
#    @attributes = attributes
#  end

  def commit(json)
    begin
      Teleconfig.new.get_targets.each{ |address|
        uri = URI.parse(address)
        http = Net::HTTP.new(uri.host,uri.port)
        req = Net::HTTP::Post.new(uri.request_uri)
        req.body = json
        req["Content-Type"] = "application/json"
        response = http.request(req)
        puts "Response #{response.code} #{response.message}:
          #{response.body}"
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

  def create_json(record, type)
    fields = record.attributes
    fields["@type"] = type
    fields.to_json
  end

  def after_save(record)
    json = create_json(record,"save")
    commit(json)
  end

  def after_destroy(record)
    json = create_json(record,"destroy")
    commit(json)
  end
end


class Person < ActiveRecord::Base
  after_save Teletransporter.new
  after_destroy Teletransporter.new
end
