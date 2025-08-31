require_relative 'client'

module Nsq
  class Consumer < Client

    attr_reader :max_in_flight

    def initialize(opts = {})
      nsqlookupds = []
      nsqlookupds = [opts[:nsqlookupd]].flatten if opts[:nsqlookupd]

      topic = opts[:topic] || raise(ArgumentError, 'topic is required')
      channel = opts[:channel] || raise(ArgumentError, 'channel is required')
      max_in_flight = opts[:max_in_flight] || 1
      discovery_interval = opts[:discovery_interval] || 60
      msg_timeout = opts[:msg_timeout]
      max_attempts = opts[:max_attempts]
      ssl_context = opts[:ssl_context]
      tls_options = opts[:tls_options]
      tls_v1 = opts[:tls_v1]

      # This is where we queue up the messages we receive from each connection
      @messages = opts[:queue] || Queue.new

      # This is where we keep a record of our active nsqd connections
      # The key is a string with the host and port of the instance (e.g.
      # '127.0.0.1:4150') and the value is the Connection instance.
      @connections = {}

      opts = {
        topic: topic,
        channel: channel,
        max_in_flight: max_in_flight,
        msg_timeout: msg_timeout,
        max_attempts: max_attempts,
        ssl_context: ssl_context,
        tls_options: tls_options,
        tls_v1: tls_v1
      }

      if !nsqlookupds.empty?
        discover_repeatedly(
          opts.merge(
            nsqlookupds: nsqlookupds,
            interval: discovery_interval
          )
        )

      elsif opts[:nsqd]
        nsqds = [opts[:nsqd]].flatten
        opts[:max_in_flight] = max_in_flight_per_connection(max_in_flight, nsqds.size)

        nsqds.each{|d| add_connection(d, opts)}

      else
        add_connection('127.0.0.1:4150', opts)
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
    def add_connection(nsqd, opts = {})
      super(nsqd, {queue: @messages}.merge(opts))
    end

    # Be conservative, but don't set a connection's max_in_flight below 1
    def max_in_flight_per_connection(max_in_flight, number_of_connections = @connections.length)
      [max_in_flight / number_of_connections, 1].max
    end

    def connections_changed
      redistribute_ready
    end

    def redistribute_ready
      @connections.values.each do |connection|
        max_in_flight = connection.max_in_flight
        max_in_flight = max_in_flight_per_connection(max_in_flight) if max_in_flight > 1

        connection.max_in_flight = max_in_flight
        connection.re_up_ready
      end
    end
  end
end
