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

  describe '#connected?' do
    it 'should delegate to Connection#connected?' do
      connection = @producer.instance_variable_get(:@connection)
      obj = {}
      expect(connection).to receive(:connected?).at_least(1).and_return(obj)
      expect(@producer.connected?).to equal(obj)
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

    it 'shouldn\'t raise an error when nsqd is down' do
      @nsqd.stop
      @nsqd.block_until_stopped

      expect{
        10.times{@producer.write('fail')}
      }.to_not raise_error
    end

    it 'will attempt to resend messages when it reconnects to nsqd' do
      @nsqd.stop
      @nsqd.block_until_stopped

      # Write 10 messages while nsqd is down
      10.times{|i| @producer.write(i)}

      @nsqd.start
      @nsqd.block_until_running

      messages_received = []

      assert_no_timeout(5) do
        consumer = new_consumer
        # TODO: make the socket fail faster
        # We only get 9 of the 10 we send. First one is lost because we can't
        # detect that it didn't make it.
        9.times do |i|
          msg = consumer.pop
          messages_received << msg.body
          msg.finish
        end
        consumer.terminate
      end

      expect(messages_received.uniq.length).to eq(9)
    end

    # Test PUB
    it 'can send a single message with unicode characters' do
      @producer.write('☺')
      consumer = new_consumer
      expect(consumer.pop.body).to eq('☺')
      consumer.terminate
    end

    # Test MPUB as well
    it 'can send multiple message with unicode characters' do
      @producer.write('☺', '☺', '☺')
      consumer = new_consumer
      3.times do
        msg = consumer.pop
        expect(msg.body).to eq('☺')
        msg.finish
      end
      consumer.terminate
    end
  end
end
