require_relative 'exceptions'
require_relative 'selectable_queue'
require_relative 'retry'
require_relative 'client_base'

module Nsq
  class Producer < ClientBase
    attr_reader :topic, :nsqd

    def initialize(opts = {})
      @connections = {}
      @nsqd = opts[:nsqd]
      @topic = opts[:topic]
      @synchronous = opts[:synchronous] || false
      @discovery_interval = opts[:discovery_interval] || 60
      @ssl_context = opts[:ssl_context]
      @tls_options = opts[:tls_options]
      @tls_v1 = opts[:tls_v1]
      @retry_attempts = opts[:retry_attempts] || 3

      @ok_timeout = opts[:ok_timeout] || 3
      @write_queue = SelectableQueue.new(10000)

      @response_queue = SelectableQueue.new(10000) if @synchronous

      if @nsqd
        raise ArgumentError, "should be a string 'host:port'" if !@nsqd.is_a?(String)
        @connection = add_connection(@nsqd, response_queue: @response_queue)
      else
        @connection = add_connection('127.0.0.1:4150', response_queue: @response_queue)
      end

      @router_thread = Thread.new { start_router() }
    end

    def terminate
      stop_router
      @router_thread.join
      super
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

    def deferred_write_to_topic(topic, delay, *raw_messages)
      raise ArgumentError, 'message not provided' if raw_messages.empty?
      messages = raw_messages.map(&:to_s)
      messages.each do |msg|
        msg = {op: :dpub, topic: topic, at: (delay * 1000).to_i, payload: msg}
        queue(msg)
      end
    end

    def write_to_topic(topic, *raw_messages)
      # return error if message(s) not provided
      raise ArgumentError, 'message not provided' if raw_messages.empty?

      # stringify the messages
      messages = raw_messages.map(&:to_s)

      if messages.length > 1
        msg = { op: :mpub, topic: topic, payload: messages }
      else
        msg = { op: :pub, topic: topic, payload: messages.first }
      end

      queue(msg)
    end

    private

    def queue(msg)
      Nsq::with_retries max_attempts: @retry_attempts do
        msg[:result] = SizedQueue.new(1) if @synchronous
        @write_queue.push(msg)
        if msg[:result]
          Timeout::timeout(@ok_timeout) do
            value = msg[:result].pop
            raise value if value.is_a?(Exception)
          end
        end
      end
    end

    def start_router
      transactions = []
      queues = [@write_queue]
      queues << @response_queue if @response_queue
      loop do
        ready, _, _ = IO::select(queues)
        if ready.include?(@response_queue)
          frame = @response_queue.pop
          result = transactions.pop
          next if result.nil?
          if frame.is_a?(Exception)
            result.push(frame)
          elsif frame.is_a?(Response)
            result.push(nil)
          elsif frame.is_a?(Error)
            result.push(ErrorFrameException.new(frame.data))
          else
            result.push(InvalidFrameException.new(frame.data))
          end
        else
          data = @write_queue.pop
          return if data[:op] == :stop_router
          if data[:op] == :dpub
            @connection.send(data[:op], data[:topic], data[:at], data[:payload])
          else
            @connection.send(data[:op], data[:topic], data[:payload])
          end
          transactions.push(data[:result])
        end
      end
    end

    def stop_router
      @write_queue.push(op: :stop_router)
    end
  end
end
