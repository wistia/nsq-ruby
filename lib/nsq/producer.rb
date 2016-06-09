require_relative 'client_base'

module Nsq
  class Producer < ClientBase
    attr_reader :topic

    def initialize(opts = {})
      @connections = {}
      @topic = opts[:topic]
      @discovery_interval = opts[:discovery_interval] || 60
      @ssl_context = opts[:ssl_context]

      nsqlookupds = []
      if opts[:nsqlookupd]
        nsqlookupds = [opts[:nsqlookupd]].flatten
        discover_repeatedly(
          nsqlookupds: nsqlookupds,
          interval: @discovery_interval
        )

      elsif opts[:nsqd]
        nsqds = [opts[:nsqd]].flatten
        nsqds.each{|d| add_connection(d)}

      else
        add_connection('127.0.0.1:4150')
      end

      at_exit{terminate}
    end

    def write(*raw_messages)
      if !@topic
        raise 'No topic specified. Either specify a topic when instantiating the Producer or use write_to_topic.'
      end

      write_to_topic(@topic, *raw_messages)
    end

    def deferred_write(at, *raw_messages)
      if !@topic
        raise 'No topic specified. Either specify a topic when instantiating the Producer or use write_to_topic.'
      end

      if %w(Time DateTime Date).include? at.class.to_s
        at = at.to_i * 1000
      end

      deferred_write_to_topic(@topic, at, *raw_messages)
    end

    def write_to_topic(topic, *raw_messages)
      # return error if message(s) not provided
      raise ArgumentError, 'message not provided' if raw_messages.empty?

      # stringify the messages
      messages = raw_messages.map(&:to_s)

      # get a suitable connection to write to
      connection = connection_for_write

      if messages.length > 1
        connection.mpub(topic, messages)
      else
        connection.pub(topic, messages.first)
      end
    end

    def deferred_write_to_topic(topic, at, *raw_messages)
      raise ArgumentError, 'message not provided' if raw_messages.empty?
      messages = raw_messages.map(&:to_s)
      connection = connection_for_write
      messages.each do |msg|
        connection.dpub(topic, at, msg)
      end
    end

    private
    def connection_for_write
      # Choose a random Connection that's currently connected
      # Or, if there's nothing connected, just take any random one
      connections_currently_connected = connections.select{|_,c| c.connected?}
      connection = connections_currently_connected.values.sample || connections.values.sample

      # Raise an exception if there's no connection available
      unless connection
        raise 'No connections available'
      end

      connection
    end

  end
end
