require_relative 'connection'

module Nsq
  class Producer

    attr_reader :host
    attr_reader :port
    attr_reader :topic

    def initialize(opts = {})
      @host = opts[:host] || '127.0.0.1'
      @port = opts[:port] || 4150
      @topic = opts[:topic] || raise(ArgumentError, 'topic is required')

      @connection = Connection.new(@host, @port)
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
