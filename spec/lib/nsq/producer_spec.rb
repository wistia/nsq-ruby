require_relative '../../spec_helper'
require 'json'

describe Nsq::Producer do
  before do
    @cluster = NsqCluster.new(nsqd_count: 1)
    @cluster.block_until_running
    @nsqd = @cluster.nsqd.first
    @producer = new_producer(@nsqd)
  end
  after do
    @cluster.destroy
  end


  def message_count
    topics_info = JSON.parse(@nsqd.stats.body)['data']['topics']
    topic_info = topics_info.select{|t| t['topic_name'] == @producer.topic }.first
    if topic_info
      topic_info['message_count']
    else
      0
    end
  end


  describe '#write' do
    it 'can queue a message' do
      @producer.write('some-message')
      wait_for{message_count==1}
      expect(message_count).to eq(1)
    end

    it 'can queue multiple messages at once' do
      @producer.write(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
      wait_for{message_count==10}
      expect(message_count).to eq(10)
    end
  end
end
