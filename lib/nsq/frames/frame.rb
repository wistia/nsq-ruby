module Nsq
  class Frame

    attr_reader :data
    attr_reader :connection

    def initialize(data, connection)
      @data = data
      @connection = connection
    end

    def self.build(type, data, connection)
      case type
      when 0
        Response.new(data, connection)
      when 1
        Error.new(data, connection)
      when 2
        Message.new(data, connection)
      else
        raise "Bad frame type encountered: #{type}"
      end
    end

  end
end
