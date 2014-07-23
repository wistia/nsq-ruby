require_relative '../../spec_helper'
require 'json'

describe Nsq::Producer do

  before do
    @cluster = NsqCluster.new(nsqd_count: 1)
    @cluster.block_until_running
    @nsqd = @cluster.nsqd.first
  end

  after do
    @cluster.destroy
  end

  let(:topic) { 'some-topic' }

  subject(:producer) do
    Nsq::Producer.new(
      topic: topic,
      host: @nsqd.host,
      port: @nsqd.tcp_port
    )
  end

  def message_count
    topics_info = JSON.parse(@nsqd.stats.body)['data']['topics']
    topic_info = topics_info.select{|t| t['topic_name'] == topic }.first
    if topic_info
      topic_info['message_count']
    else
      0
    end
  end

  describe '#write' do
    it 'can queue a message' do
      producer.write('some-message')
      expect(message_count).to eq(1)
    end

    it 'can queue multiple messages at once' do
      producer.write(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
      expect(message_count).to eq(10)
    end
  end

end
