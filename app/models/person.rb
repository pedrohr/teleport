require 'teleport.rb'

class Person < ActiveRecord::Base
  #this methods must be static in the model class
  def self.my_after_create
  end

  after_create Teleport.new(my_after_create)
  after_destroy Teleport.new(nil)
  after_save Teleport.new(nil)
end
