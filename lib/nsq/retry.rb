require_relative 'exceptions'

require 'timeout'

module Nsq
    # Retry the supplied block with exponential backoff.
    #
    # Borrowed liberally from:
    # https://github.com/ooyala/retries/blob/master/lib/retries.rb
    def self.with_retries(opts = {}, &block)
      base_sleep_seconds = 0.5
      max_sleep_seconds = 300 # 5 minutes

      # Let's do this thing
      attempts = 0
      max_attempts = opts[:max_attempts] || 100

      begin
        attempts += 1
        return block.call(attempts)

      rescue UnexpectedFrameError, ErrorFrameException, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
             Errno::ENETDOWN, Errno::ENETUNREACH, Errno::ETIMEDOUT, Timeout::Error => ex

        raise ex if attempts >= max_attempts

        # The sleep time is an exponentially-increasing function of base_sleep_seconds.
        # But, it never exceeds max_sleep_seconds.
        sleep_seconds = [base_sleep_seconds * (2 ** (attempts - 1)), max_sleep_seconds].min
        # Randomize to a random value in the range sleep_seconds/2 .. sleep_seconds
        sleep_seconds = sleep_seconds * (0.5 * (1 + rand()))
        # But never sleep less than base_sleep_seconds
        sleep_seconds = [base_sleep_seconds, sleep_seconds].max

        warn "Failed to connect: #{ex}. Retrying in #{sleep_seconds.round(1)} seconds."

        sleep(sleep_seconds)

        retry
      end
    end
end
