require_relative 'client_base'
require_relative 'connection'
require_relative 'logger'

module Nsq
  class Producer < ClientBase
    include Nsq::AttributeLogger
    @@log_attributes = [:host, :port, :topic]

    attr_reader :host
    attr_reader :port
    attr_reader :topic

    def initialize(opts = {})
      @connections = {}
      @topic = opts[:topic] || raise(ArgumentError, 'topic is required')
      @discovery_interval = opts[:discovery_interval] || 60

      nsqlookupds = []
      if opts[:nsqlookupd]
        nsqlookupds = [opts[:nsqlookupd]].flatten
        @discovery = Discovery.new(nsqlookupds)
        discover_repeatedly(discover_by_topic: false)

      elsif opts[:nsqd]
        nsqds = [opts[:nsqd]].flatten
        nsqds.each{|d| add_connection(d)}

      else
        add_connection('127.0.0.1:4150')
      end

      at_exit{terminate}
    end


    def write(*raw_messages)
      # stringify the messages
      messages = raw_messages.map(&:to_s)

      # get a suitable connection to write to
      connection = connection_for_write

      if messages.length > 1
        connection.mpub(@topic, messages)
      else
        connection.pub(@topic, messages.first)
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
