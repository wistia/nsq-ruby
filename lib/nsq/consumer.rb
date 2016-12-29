require_relative 'client_base'

module Nsq
  class Consumer < ClientBase

    attr_reader :max_in_flight

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
      @ssl_context = opts[:ssl_context]
      @tls_options = opts[:tls_options]
      @tls_v1 = opts[:tls_v1]

      # This is where we queue up the messages we receive from each connection
      @messages = opts[:queue] || Queue.new

      # This is where we keep a record of our active nsqd connections
      # The key is a string with the host and port of the instance (e.g.
      # '127.0.0.1:4150') and the key is the Connection instance.
      @connections = {}

      if !@nsqlookupds.empty?
        discover_repeatedly(
          nsqlookupds: @nsqlookupds,
          topic: @topic,
          interval: @discovery_interval
        )
      else
        # normally, we find nsqd instances to connect to via nsqlookupd(s)
        # in this case let's connect to an nsqd instance directly
        add_connection(opts[:nsqd] || '127.0.0.1:4150', max_in_flight: @max_in_flight)
      end
    end


    # pop the next message off the queue
    def pop
      @messages.pop
    end


    # By default, if the internal queue is empty, pop will block until
    # a new message comes in.
    #
    # Calling this method won't block. If there are no messages, it just
    # returns nil.
    def pop_without_blocking
      @messages.pop(true)
    rescue ThreadError
      # When the Queue is empty calling `Queue#pop(true)` will raise a ThreadError
      nil
    end


    # returns the number of messages we have locally in the queue
    def size
      @messages.size
    end


    private
    def add_connection(nsqd, options = {})
      super(nsqd, {
        topic: @topic,
        channel: @channel,
        queue: @messages,
        msg_timeout: @msg_timeout,
        max_in_flight: 1
      }.merge(options))
    end

    # Be conservative, but don't set a connection's max_in_flight below 1
    def max_in_flight_per_connection(number_of_connections = @connections.length)
      [@max_in_flight / number_of_connections, 1].max
    end

    def connections_changed
      redistribute_ready
    end

    def redistribute_ready
      @connections.values.each do |connection|
        connection.max_in_flight = max_in_flight_per_connection
        connection.re_up_ready
      end
    end
  end
end
