class Teleconfig
  private
  @@targets = ["http://127.0.0.1:3001"]

  public
  def get_targets
    return @@targets
  end
end

class Logger
  def self.log_send(json, address)
    puts "\n\n"
    puts "Teleporting data to #{address}"
    puts "   #{json.to_s}"
    puts "Completed.\n"
  end
end
