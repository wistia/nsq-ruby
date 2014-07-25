require_relative 'connection'
require_relative 'logger'

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
    end


    def subscribe
      Nsq.log.info "#{@port} Subscribing"
      sub(@topic, @channel)
      re_up_ready
    end


    private
    def open_connection
      super
      subscribe
    end


  end
end
