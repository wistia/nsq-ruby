require_relative 'connection'
require_relative 'logger'

module Nsq
  class Producer
    include Nsq::AttributeLogger
    @@log_attributes = [:host, :port, :topic]

    attr_reader :host
    attr_reader :port
    attr_reader :topic


    def initialize(opts = {})
      @nsqd = opts[:nsqd] || '127.0.0.1:4150'
      @host, @port = @nsqd.split(':')

      @topic = opts[:topic] || raise(ArgumentError, 'topic is required')

      @connection = Connection.new(@host, @port)

      at_exit{@connection.close}
    end


    def write(*raw_messages)
      # stringify them
      messages = raw_messages.map(&:to_s)

      if messages.length > 1
        @connection.mpub(@topic, messages)
      else
        @connection.pub(@topic, messages.first)
      end
    end


  end
end
