require_relative 'consumer_connection'
require_relative 'discovery'
require_relative 'logger'

module Nsq
  class Consumer
    include Nsq::AttributeLogger
    @@log_attributes = [:topic]

    attr_reader :topic
    attr_reader :messages
    attr_reader :max_in_flight
    attr_reader :discovery_interval
    attr_reader :connections

    def initialize(opts = {})
      if opts[:nsqlookupd]
        @nsqlookupds = [opts[:nsqlookupd]].flatten
      else
        @nsqlookupds = []
      end

      @topic = opts[:topic] || raise(ArgumentError, 'topic is required')
      @channel = opts[:channel] || raise(ArgumentError, 'channel is required')
      @max_in_flight = opts[:max_in_flight] || 1
      @discovery_interval = opts[:discovery_interval] || 60

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


    def terminate
      @discovery_thread.kill if @discovery_thread
      drop_all_connections
    end


    private
    def discover_repeatedly
      @discovery_thread = Thread.new do
        loop do
          discover
          sleep @discovery_interval
        end
      end
    end


    def discover
      nsqds = @discovery.nsqds_for_topic(@topic)

      # remove ones that are no longer available
      @connections.keys.each do |nsqd|
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
      info "+ Adding connection #{nsqd}"
      host, port = nsqd.split(':')
      connection = ConsumerConnection.new(host, port, @topic, @channel, @messages)
      @connections[nsqd] = connection
      redistribute_ready
    end


    def drop_connection(nsqd)
      info "- Dropping connection #{nsqd}"
      connection = @connections.delete(nsqd)
      connection.close
      redistribute_ready
    end


    def redistribute_ready
      @connections.values.each do |connection|
        # Be conservative, but don't set a connection's max_in_flight below 1
        max_per_connection = [@max_in_flight / @connections.length, 1].max
        connection.max_in_flight = max_per_connection
      end
    end


    def drop_all_connections
      @connections.keys.each do |nsqd|
        drop_connection(nsqd)
      end
    end
  end
end
