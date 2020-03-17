require 'logger'
module Nsq
  @@logger = Logger.new(nil)
  @@logger_fields_as_hash = false


  def self.logger
    @@logger
  end


  def self.logger_fields_as_hash
    @@logger_fields_as_hash
  end


  def self.logger=(new_logger)
    @@logger = new_logger
  end


  def self.logger_fields_as_hash=(value)
    @@logger_fields_as_hash = value
  end


  module AttributeLogger
    def self.included(klass)
      klass.send :class_variable_set, :@@log_attributes, []
    end

    %w(fatal error warn info debug).map{|m| m.to_sym}.each do |level|
      define_method level do |msg|
        if Nsq.logger_fields_as_hash
          Nsq.logger.send(level, prefix_hash.merge!(msg: msg))
        else
          Nsq.logger.send(level, "#{prefix} #{msg}")
        end
      end
    end


    private
    def prefix_hash
      attrs = self.class.send(:class_variable_get, :@@log_attributes)
      hash = {}
      attrs.each do |attr|
        hash[attr.to_s] = self.send(attr)
      end
      return hash
    end


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
