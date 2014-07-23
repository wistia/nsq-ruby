require_relative 'frame'

module Nsq
  class Message < Frame

    attr_reader :timestamp
    attr_reader :attempts
    attr_reader :id
    attr_reader :body

    def initialize(data, connection)
      super
      @timestamp, @attempts, @id, @body = @data.unpack('Q>s>a16a*')
    end

    def finish
      connection.fin(id)
    end

    def requeue
      connection.req(id)
    end

    def touch
      connection.touch(id)
    end

  end
end
