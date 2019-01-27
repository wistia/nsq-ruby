module Nsq
  class NsqdsProducer
    include Nsq::AttributeLogger

    STRATEGY_FAILOVER = :failover
    STRATEGY_ROUNDROBIN = :round_robin
    STRATEGIES = [STRATEGY_FAILOVER, STRATEGY_ROUNDROBIN].freeze

    attr_reader :topic

    def initialize(opts = {})
      @nsqds = opts.delete(:nsqds)
      @strategy = opts.delete(:strategy) || STRATEGY_FAILOVER
      @attempts = opts.delete(:strategy_attempts)
      @topic = opts[:topic]

      if !STRATEGIES.include?(@strategy)
        raise ArgumentError, "strategy should be one of #{STRATEGIES.join(", ")}"
      end

      if @nsqds && !@nsqds.is_a?(Array)
        raise ArgumentError, "nsqds should be an array of hosts 'host:port'"
      elsif !@nsqds
        @nsqds = ['127.0.0.1:4150']
      end

      @index = 0
      @producers = @nsqds.map do |nsqd|
        Producer.new(opts.merge(nsqd: nsqd))
      end
    end

    def terminate
      @producers.each do |producer|
        producer.terminate
      end
    end

    def write(*raw_messages)
      each_provider(:write, raw_messages)
    end

    def deferred_write(delay, *raw_messages)
      each_provider(:deferred_write, delay, raw_messages)
    end

    def deferred_write_to_topic(topic, delay, *raw_messages)
      each_provider(:deferred_write_to_topic, topic, delay, raw_messages)
    end

    def write_to_topic(topic, *raw_messages)
      each_provider(:write_to_topic, topic, raw_messages)
    end

    protected

    def each_provider(action, *args)
      attempt = 0
      begin
        @producers[@index].send(action, *args)
        inc_index if @strategy == STRATEGY_ROUNDROBIN
      rescue => ex
        error producer: @producers[@index].nsqd, msg: "fail to #{action} message: #{ex.message}", exception: ex.class
        inc_index
        attempt += 1
        raise ex if attempt == @attempts
        retry
      end
    end

      def inc_index
        @index = (@index + 1 ) % @producers.length
      end
  end
end
