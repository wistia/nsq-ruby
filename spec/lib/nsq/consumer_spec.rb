require_relative '../../spec_helper'
require 'json'
require 'timeout'

describe Nsq::Consumer do
  before do
    @cluster = NsqCluster.new(nsqd_count: 1)
    @cluster.block_until_running
    @nsqd = @cluster.nsqd.first
    @topic = 'some-topic'
    @consumer = create_consumer
  end
  after do
    @consumer.terminate
    @cluster.destroy
  end

  def create_consumer(opts = {})
    Nsq::Consumer.new({
      topic: @topic,
      channel: 'some-channel',
      host: @nsqd.host,
      port: @nsqd.tcp_port,
      max_in_flight: 1
    }.merge(opts))
  end


  describe '#on_terminate' do
    it 'closes the connection' do
      connection = @consumer.instance_variable_get(:@connection)
      # Once from our call, once from the #terminate in our `after` block
      expect(connection.wrapped_object).to receive(:close).exactly(2)
      @consumer.send :on_terminate
    end
  end

  describe '#messages' do
    it 'can pop off a message' do
      @nsqd.pub(@topic, 'some-message')
      assert_no_timeout(1) do
        msg = @consumer.messages.pop
        expect(msg.body).to eq('some-message')
        msg.finish
      end
    end

    it 'can pop off many messages' do
      10.times{@nsqd.pub(@topic, 'some-message')}
      assert_no_timeout(1) do
        10.times{@consumer.messages.pop.finish}
      end
    end
  end

end
