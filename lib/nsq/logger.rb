require 'logger'
module Nsq
  @@logger = Logger.new(nil)
  # Todo Logger should show host/port

  def self.log
    logger
  end


  def self.logger
    @@logger
  end


  def self.logger=(new_logger)
    @@logger = new_logger
  end
end