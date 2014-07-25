require_relative '../logger'

module Nsq
  class Frame
    attr_reader :data
    attr_reader :connection

    def initialize(data, connection)
      @data = data
      @connection = connection
    end
  end
end
