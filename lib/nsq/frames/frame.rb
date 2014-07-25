require_relative '../logger'

module Nsq
  class Frame
    include Nsq::AttributeLogger
    @@log_attributes = [:connection]

    attr_reader :data
    attr_reader :connection

    def initialize(data, connection)
      @data = data
      @connection = connection
    end
  end
end
