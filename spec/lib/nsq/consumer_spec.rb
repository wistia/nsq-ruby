require_relative '../../spec_helper'
require 'json'

describe Nsq::Consumer do

  before do
    @cluster = NsqCluster.new(nsqd_count: 1)
    @cluster.block_until_running
    @nsqd = @cluster.nsqd.first
  end

  after do
    consumer.terminate
    @cluster.destroy
  end

  let(:topic) { 'some-topic' }

  subject(:consumer) do
    Nsq::Consumer.new(
      topic: topic,
      channel: 'some-channel',
      host: @nsqd.host,
      port: @nsqd.tcp_port
    )
  end

  describe '#messages' do
    it 'can pop off a message' do
      @nsqd.pub(topic, 'some-message')
      msg = consumer.messages.pop
      expect(msg.body).to eq('some-message')
      msg.finish
    end
  end

end
