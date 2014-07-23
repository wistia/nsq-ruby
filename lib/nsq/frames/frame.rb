module Nsq
  class Frame

    attr_reader :data

    def initialize(data)
      @data = data
    end

    def self.build(type, data)
      case type
      when 0
        Response.new(data)
      when 1
        Error.new(data)
      when 2
        Message.new(data)
      else
        raise "Bad frame type encountered: #{type}"
      end
    end

  end
end
