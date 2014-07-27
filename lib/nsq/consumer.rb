require_relative 'connection'
require_relative 'discovery'
require_relative 'logger'

module Nsq
  class Consumer
    include Nsq::AttributeLogger
    @@log_attributes = [:topic]

    attr_reader :topic
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
      @msg_timeout = opts[:msg_timeout]

      # This is where we queue up the messages we receive from each connection
      @messages = Queue.new

      # This is where we keep a record of our active nsqd connections
      # The key is a string with the host and port of the instance (e.g.
      # '127.0.0.1:4150') and the key is the Connection instance.
      @connections = {}

      if !@nsqlookupds.empty?
        @discovery = Discovery.new(@nsqlookupds)
        discover_repeatedly
      else
        # normally, we find nsqd instances to connect to via nsqlookupd(s)
        # in this case let's connect to an nsqd instance directly
        add_connection(opts[:nsqd] || '127.0.0.1:4150', @max_in_flight)
      end

      at_exit{terminate}
    end


    def terminate
      @discovery_thread.kill if @discovery_thread
      drop_all_connections
    end


    # pop the next message off the queue
    def pop
      @messages.pop
    end


    # returns the number of messages we have locally in the queue
    def size
      @messages.size
    end


    private
    def discover_repeatedly
      @discovery_thread = Thread.new do
        loop do
          discover
          sleep @discovery_interval
        end
      end
      @discovery_thread.abort_on_exception = true
    end


    def discover
      nsqds = @discovery.nsqds_for_topic(@topic)

      # drop nsqd connections that are no longer in lookupd
      missing_nsqds = @connections.keys - nsqds
      missing_nsqds.each do |nsqd|
        drop_connection(nsqd)
      end

      # add new ones
      new_nsqds = nsqds - @connections.keys
      new_nsqds.each do |nsqd|
        # Be conservative and start new connections with RDY 1
        # This helps ensure we don't exceed @max_in_flight across all our
        # connections momentarily.
        add_connection(nsqd, 1)
      end

      # balance RDY state amongst the connections
      redistribute_ready
    end


    def add_connection(nsqd, max_in_flight)
      info "+ Adding connection #{nsqd}"
      host, port = nsqd.split(':')
      connection = Connection.new(
        host: host,
        port: port,
        topic: @topic,
        channel: @channel,
        queue: @messages,
        msg_timeout: @msg_timeout,
        max_in_flight: max_in_flight
      )
      @connections[nsqd] = connection
    end


    def drop_connection(nsqd)
      info "- Dropping connection #{nsqd}"
      connection = @connections.delete(nsqd)
      connection.close
      redistribute_ready
    end


    def redistribute_ready
      @connections.values.each do |connection|
        connection.max_in_flight = max_in_flight_per_connection
        connection.re_up_ready
      end
    end


    def drop_all_connections
      @connections.keys.each do |nsqd|
        drop_connection(nsqd)
      end
    end


    # Be conservative, but don't set a connection's max_in_flight below 1
    def max_in_flight_per_connection(number_of_connections = @connections.length)
      [@max_in_flight / number_of_connections, 1].max
    end
  end
end
