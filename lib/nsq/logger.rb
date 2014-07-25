require 'logger'
module Nsq
  @@logger = Logger.new(nil)


  def self.logger
    @@logger
  end


  def self.logger=(new_logger)
    @@logger = new_logger
  end


  module AttributeLogger
    def self.included(klass)
      klass.send :class_variable_set, :@@log_attributes, []
    end

    %w(fatal error warn info debug).map{|m| m.to_sym}.each do |level|
      define_method level do |msg|
        Nsq.logger.send(level, "#{prefix} #{msg}")
      end
    end


    private
    def prefix
      attrs = self.class.send(:class_variable_get, :@@log_attributes)
      if attrs.count > 0
        "[#{attrs.map{|a| "#{a.to_s}: #{self.send(a)}"}.join(' ')}] "
      else
        ''
      end
    end
  end
end