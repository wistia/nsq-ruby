require_relative 'connection'

module Nsq
  class Consumer

    attr_reader :host
    attr_reader :port
    attr_reader :topic
    attr_reader :messages
    attr_reader :max_in_flight

    # We include Celluloid for its finalizer logic - consider removing
    include Celluloid
    finalizer :on_terminate

    def initialize(opts = {})
      @host = opts[:host] || '127.0.0.1'
      @port = opts[:port] || 4150
      @topic = opts[:topic] || raise(ArgumentError, 'topic is required')
      @channel = opts[:channel] || raise(ArgumentError, 'channel is required')
      @max_in_flight = opts[:max_in_flight] || 1

      @messages = Queue.new

      @connection = Connection.new(@host, @port)
      @connection.subscribe_and_listen(@topic, @channel, @messages, @max_in_flight)
    end


    private
    def on_terminate
      @connection.async.stop_listening_for_messages
      @connection.async.close
    end
  end
end
