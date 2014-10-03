require_relative 'frame'

module Nsq
  class Message < Frame

    attr_reader :attempts
    attr_reader :id
    attr_reader :body

    def initialize(data, connection)
      super
      @timestamp_in_nanoseconds, @attempts, @id, @body = @data.unpack('Q>s>a16a*')
      @body.force_encoding('UTF-8')
    end

    def finish
      connection.fin(id)
    end

    def requeue(timeout = 0)
      connection.req(id, timeout)
    end

    def touch
      connection.touch(id)
    end

    def timestamp
      Time.at(@timestamp_in_nanoseconds / 1_000_000_000.0)
    end

  end
end
