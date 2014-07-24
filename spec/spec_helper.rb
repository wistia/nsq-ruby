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
