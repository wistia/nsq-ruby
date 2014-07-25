require 'nsq-cluster'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'nsq'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

require 'timeout'
def assert_no_timeout(time = 1, &block)
  expect{
    Timeout::timeout(time) do
      yield
    end
  }.not_to raise_error
end

# Block execution until a condition is met
# Times out after 5 seconds by default
#
# example:
#   wait_for { @consumer.queue.length > 0 }
#
def wait_for(timeout = 5, &block)
  Timeout::timeout(timeout) do
    loop do
      break if yield
      sleep(0.1)
    end
  end
end

TOPIC = 'some-topic'
CHANNEL = 'some-channel'

def new_consumer(opts = {})
  lookupd = @cluster.nsqlookupd.map{|l| "#{l.host}:#{l.http_port}"}
  Nsq::Consumer.new({
    topic: TOPIC,
    channel: CHANNEL,
    nsqlookupd: lookupd,
    max_in_flight: 1
  }.merge(opts))
end


def new_producer(nsqd, opts = {})
  Nsq::Producer.new({
    topic: TOPIC,
    nsqd: "#{nsqd.host}:#{nsqd.tcp_port}"
  }.merge(opts))
end
