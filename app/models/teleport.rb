require 'json'
require 'net/http'
require 'uri'
require 'digest/sha2'

class Logger
  def self.log_send(json, address)
    puts "\n\n"
    puts "Teleporting data to #{address}"
    puts "   #{json.to_s}"
    puts "Completed.\n"
  end

  def self.server_not_online(e)
    puts "========"
    puts "Central server is not online."
    puts e.message
    puts "========"
  end

  def self.connection_fail(e)
    puts "========"
    puts "Fail sending info to the central server"
    puts e.message
    puts "========"
  end
end

class Teleport
  @@config = YAML::load(File.open(Rails.root.to_s + '/config/teleport.yml')) 
  
  def initialize(method)
    method
  end

  POST = Net::HTTP::Post
  DELETE = Net::HTTP::Delete
  PUT = Net::HTTP::Put

  def commit(json, method)
    begin
      @@config["targets"].each{ |address|
        uri = URI.parse(address)
        http = Net::HTTP.new(uri.host,uri.port)
        req = method.new(uri.request_uri)
        req.body = json
        req["Content-Type"] = "application/json"
        response = http.request(req)
        Logger.log_send(json, address)
      }
    rescue Errno::ECONNREFUSED => e
      Logger.server_not_online(e)
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      Logger.connection_fail(e)
    end
  end

  # Using SHA2 => no collisions, 512 bits output
  def gen_key(record)
    return Digest::SHA2.hexdigest(record.to_s)
  end

  def handle_record(record)
    from = record.class.to_s
    record = record.serializable_hash
    record = record.merge({"__key" => gen_key(record)})
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
    #Not executing for creatting new tuples
    if !record.created_at_change.nil?
      return false
    end

    #old_record for the key-generation proccess
    old_record = record.dup
    record.changes.each { |attr,values|
      old_record[attr] = values.first
    }

    #generating new keys
    key = gen_key(old_record.serializable_hash)
    new_key = gen_key(record.serializable_hash)

    #preparing updates
    update = record.changed_attributes
    update.each { |k,v|
      update[k] = record[k]
    }
    update = update.merge({"__key" => new_key})
    info = {"update" => update}

    info = info.merge({"__key"=> key})
    json = info.to_json
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
