require_relative 'connection'
require_relative 'discovery'

module Nsq
  class Consumer

    attr_reader :topic
    attr_reader :messages
    attr_reader :max_in_flight
    attr_reader :discover_interval

    def initialize(opts = {})
      if opts[:nsqlookupd]
        @nsqlookupds = [opts[:nsqlookupd]].flatten
      else
        @nsqlookupds = []
      end

      @topic = opts[:topic] || raise(ArgumentError, 'topic is required')
      @channel = opts[:channel] || raise(ArgumentError, 'channel is required')
      @max_in_flight = opts[:max_in_flight] || 1
      @discover_interval = opts[:discover_interval] || 60

      @messages = Queue.new
      @connections = {}

      if !@nsqlookupds.empty?
        @discovery = Discovery.new(@nsqlookupds)
        discover_repeatedly
      else
        # normally, we find nsqd instances to connect to via nsqlookupd(s)
        # in this case let's connect to an nsqd instance directly
        add_connection(opts[:nsqd] || '127.0.0.1:4150')
      end

      at_exit{terminate}
    end


    private
    def discover_repeatedly
      @discover_thread = Thread.new do
        loop do
          discover
          sleep @discover_interval
        end
      end
    end


    def discover
      nsqds = @discovery.nsqds_for_topic(@topic)

      # remove ones that are no longer available
      @connections.keys do |nsqd|
        unless nsqds.include?(nsqd)
          drop_connection(nsqd)
        end
      end

      # add new ones
      nsqds.each do |nsqd|
        unless @connections[nsqd]
          add_connection(nsqd)
        end
      end
    end


    def add_connection(nsqd)
      host, port = nsqd.split(':')
      connection = Connection.new(host, port)
      @connections[nsqd] = connection
      connection.subscribe_and_listen(@topic, @channel, @messages, @max_in_flight)
      redistribute_ready
    end


    def drop_connection(nsqd)
      connection = @connections.delete(nsqd)
      connection.terminate
      redistribute_ready
    end


    def redistribute_ready
      @connections.values.each do |connection|
        # Be conservative, but don't set a connection's max_in_flight below 1
        max_per_connection = [@max_in_flight / @connections.length, 1].max
        connection.max_in_flight = max_per_connection
      end
    end


    def terminate
      close_all_connections
      @discover_thread && @discover_thread.kill
    end


    def close_all_connections
      @connections.values.each do |connection|
        connection.close
      end
    end
  end
end
