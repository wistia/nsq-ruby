require_relative 'connection'

module Nsq
  class ConsumerConnection < Connection

    attr_accessor :max_in_flight
    attr_reader :presumed_in_flight

    def initialize(host, port, topic, channel, queue)
      @queue = queue
      @presumed_in_flight = 0
      @max_in_flight = 1
      @topic = topic
      @channel = channel

      super(host, port)

      subscribe
    end


    def subscribe
      sub(@topic, @channel)
      re_up_ready
    end


    def died(reason)
      puts "#{@port} DIED: #{reason}"
      super

      sleep(1)

      # reopen in a bit
      puts "#{@port} reopening"
      open
      puts "#{@port} subscribing"
      subscribe
      puts "#{@port} done"
    end

  end
end
