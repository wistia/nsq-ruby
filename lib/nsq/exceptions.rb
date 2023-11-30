module Nsq
  # Raised when nsqlookupd discovery fails
  class DiscoveryException < StandardError; end

  class ErrorFrameException < StandardError; end

  class UnexpectedFrameError < StandardError
    def initialize(frame)
      @frame = frame
    end

    def message
      if @frame
        return "unexpected frame value #{frame.data}"
      end
      return 'empty frame from socket'
    end
  end
end
