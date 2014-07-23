module Nsq
  class Message < Frame

    attr_reader :timestamp
    attr_reader :attempts
    attr_reader :id
    attr_reader :body

    def initialize(data)
      super
      @timestamp, @attempts, @id, @body = @data.unpack("Q>s>a16a*")
    end

    def finish
      # whatever
    end
  end
end
