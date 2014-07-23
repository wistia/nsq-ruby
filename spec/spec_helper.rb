require 'nsq-cluster'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'nsq'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

require 'celluloid/test'
RSpec.configure do |config|
  config.before(:each) do
    without_celluloid_logging do
      Celluloid.shutdown
      Celluloid.boot
    end
  end
  config.after(:each) do
    without_celluloid_logging do
      Celluloid.shutdown
    end
  end
end

require 'celluloid'
def without_celluloid_logging(&block)
  logger = Celluloid.logger
  Celluloid.logger = nil
  yield
  Celluloid.logger = logger
end

require 'timeout'
def assert_no_timeout(time = 1, &block)
  expect{
    Timeout::timeout(time) do
      yield
    end
  }.not_to raise_error
end
