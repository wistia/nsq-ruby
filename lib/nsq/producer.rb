require_relative 'client_base'

module Nsq
  class Producer < ClientBase
    attr_reader :topic

    def initialize(opts = {})
      @connections = {}
      @topic = opts[:topic]
      @synchronous = opts[:synchronous] || false
      @discovery_interval = opts[:discovery_interval] || 60
      @ssl_context = opts[:ssl_context]
      @tls_options = opts[:tls_options]
      @tls_v1 = opts[:tls_v1]
      @retry_attempts = opts[:retry_attempts] || 5

      nsqlookupds = []
      if opts[:nsqlookupd]
        nsqlookupds = [opts[:nsqlookupd]].flatten
        discover_repeatedly(
          nsqlookupds: nsqlookupds,
          interval: @discovery_interval
        )

      elsif opts[:nsqd]
        nsqds = [opts[:nsqd]].flatten
        nsqds.each{|d| add_connection(d, {synchronous: @synchronous})}

      else
        add_connection('127.0.0.1:4150', {synchronous: @synchronous})
      end
    end

    def write(*raw_messages)
      if !@topic
        raise 'No topic specified. Either specify a topic when instantiating the Producer or use write_to_topic.'
      end

      write_to_topic(@topic, *raw_messages)
    end

    # Arg 'delay' in seconds
    def deferred_write(delay, *raw_messages)
      if !@topic
        raise 'No topic specified. Either specify a topic when instantiating the Producer or use write_to_topic.'
      end
      if delay < 0.0
        raise "Delay can't be negative, use a positive float."
      end

      deferred_write_to_topic(@topic, delay, *raw_messages)
    end

    def write_to_topic(topic, *raw_messages)
      # return error if message(s) not provided
      raise ArgumentError, 'message not provided' if raw_messages.empty?

      # stringify the messages
      messages = raw_messages.map(&:to_s)

      with_retries @retry_attempts do
        # get a suitable connection to write to
        connection = connection_for_write

        if messages.length > 1
          connection.mpub(topic, messages)
        else
          connection.pub(topic, messages.first)
        end
      end
    end

    def with_retries(attempts)
      wait = 1.0
      count = 0
      begin
        yield
      rescue => ex
        if count < attempts
          error "exception when publishing message: #{ex}, retrying in #{wait} seconds…"
          sleep(wait)
          wait = wait * 2
          count += 1
          retry
        end
        raise ex
      end
    end

    def deferred_write_to_topic(topic, delay, *raw_messages)
      raise ArgumentError, 'message not provided' if raw_messages.empty?
      messages = raw_messages.map(&:to_s)
      connection = connection_for_write
      messages.each do |msg|
        connection.dpub(topic, (delay * 1000).to_i, msg)
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
