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
  def initialize(function)
    function
  end

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
      puts "Central server is not online."
      puts e.message
      puts "============================================="
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      puts "============================================="
      puts "Fail!"
      puts e.message
      puts "============================================="
    end
  end

  def handle_record(record)
    from = record.class.to_s
    record = record.serializable_hash
    record = record.merge({"__key" => record.to_s.crypt("id")})
    return {from => record}.to_json
  end

  def after_create(record)
    json = handle_record(record)
    commit(json, POST)
  end

  def after_destroy(record)
    json = handle_record(record)
    commit(json, DELETE)
  end

  def after_save(record)
    #Condition to avoid the 'save' trigger after a 'create'
    record.changed_attributes.each { |k,v|
      return false if v == nil
    }

    #preparing updates
    update = record.changed_attributes
    update.each { |k,v|
      update[k] = record[k]
    }
    update = {"update" => update}

    #old_record for the key-generation proccess
    old_record = record.dup
    record.changes.each { |attr,values|
      old_record[attr] = values.first
    }

    #generating the new key
    key = old_record.serializable_hash.to_s.crypt("id")

    # decision:
    # => a composed key: (__key + created_at) is not being
    # => cuz it set let two or more sources change the same     # tuple in the central database.
    record = update.merge({"__key"=> key})
    json = record.to_json
    commit(json, PUT)
  end

  def before_create(record)
    after_create(record)
  end

  def before_destroy(record)
    after_destroy(record)
  end

  def before_save(record)
    after_save(record)
  end
end

class Person < ActiveRecord::Base
  #this methods must be static to the model
  def self.my_after_create
  end

  after_create Teleport.new(my_after_create)
  after_destroy Teleport.new(nil)
  after_save Teleport.new(nil)
end
