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
    @producer.terminate
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


  describe '::new' do
    it 'should throw an exception when trying to connect to a server that\'s down' do
      @nsqd.stop
      @nsqd.block_until_stopped

      expect{
        new_producer(@nsqd)
      }.to raise_error
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

    it 'should raise an error when nsqd is down' do
      @nsqd.stop
      @nsqd.block_until_stopped

      expect{
        # The socket doesn't throw an error until we write twice for some
        # reason.
        # TODO: Make the connection fail faster
        @producer.write('fail')
        @producer.write('fail')
      }.to raise_error
    end
  end
end
