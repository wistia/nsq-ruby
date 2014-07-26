require_relative '../../spec_helper'
require 'json'
require 'timeout'

describe Nsq::Consumer do
  before do
    @cluster = NsqCluster.new(nsqd_count: 2, nsqlookupd_count: 1)
    @cluster.block_until_running
  end

  after do
    @cluster.destroy
  end


  describe 'when connecting to nsqd directly' do
    before do
      @nsqd = @cluster.nsqd.first
      @consumer = new_consumer(nsqlookupd: nil, nsqd: "#{@nsqd.host}:#{@nsqd.tcp_port}")
    end
    after do
      @consumer.terminate
    end


    describe '#messages' do
      it 'can pop off a message' do
        @nsqd.pub(@consumer.topic, 'some-message')
        assert_no_timeout(1) do
          msg = @consumer.messages.pop
          expect(msg.body).to eq('some-message')
          msg.finish
        end
      end

      it 'can pop off many messages' do
        10.times{@nsqd.pub(@consumer.topic, 'some-message')}
        assert_no_timeout(1) do
          10.times{@consumer.messages.pop.finish}
        end
      end
    end


    describe '#req' do
      it 'can successfully requeue a message' do
        # queue a message
        @nsqd.pub(TOPIC, 'twice')

        msg = @consumer.messages.pop

        expect(msg.body).to eq('twice')

        # requeue it
        msg.requeue

        req_msg = @consumer.messages.pop
        expect(req_msg.body).to eq('twice')
        expect(req_msg.attempts).to eq(2)
      end
    end
  end


  describe 'when using lookupd' do

    describe '#messages' do
      it 'receives messages from both queues' do
        expected_messages = (1..20).to_a.map(&:to_s)

        # distribute messages amongst the queues
        expected_messages.each_with_index do |message, idx|
          @cluster.nsqd[idx % @cluster.nsqd.length].pub(TOPIC, message)
        end

        received_messages = []

        # gather all the messages
        consumer = new_consumer
        assert_no_timeout(2) do
          expected_messages.length.times do
            msg = consumer.messages.pop
            received_messages << msg.body
            msg.finish
          end
        end

        expect(received_messages.sort).to eq(expected_messages.sort)
        consumer.terminate
      end

    end
  end


  describe 'with a low message timeout' do
    before do
      @nsqd = @cluster.nsqd.first
      @msg_timeout = 1
      @consumer = new_consumer(
        nsqlookupd: nil,
        nsqd: "#{@nsqd.host}:#{@nsqd.tcp_port}",
        msg_timeout: @msg_timeout * 1000 # in milliseconds
      )
    end
    after do
      @consumer.terminate
    end


    # This testing that our msg_timeout is being honored
    it 'should give us the same message over and over' do
      @nsqd.pub(TOPIC, 'slow')

      msg1 = @consumer.messages.pop
      expect(msg1.body).to eq('slow')
      expect(msg1.attempts).to eq(1)

      # wait for it to be reclaimed by nsqd and then finish it so we can get
      # another. this fin won't actually succeed, because the message is no
      # longer in flight
      sleep(@msg_timeout + 0.1)
      msg1.finish

      assert_no_timeout do
        msg2 = @consumer.messages.pop
        expect(msg2.body).to eq('slow')
        expect(msg2.attempts).to eq(2)
      end
    end


    # This is like the test above, except we touch the message to reset its
    # timeout
    it 'should be able to touch a message to reset its timeout' do
      @nsqd.pub(TOPIC, 'slow')

      msg1 = @consumer.messages.pop
      expect(msg1.body).to eq('slow')

      # touch the message in the middle of a sleep session whose total just
      # exceeds the msg_timeout
      sleep(@msg_timeout / 2.0 + 0.1)
      msg1.touch
      sleep(@msg_timeout / 2.0 + 0.1)
      msg1.finish

      # if our touch didn't work, we should receive a message
      assert_timeout do
        @consumer.messages.pop
      end
    end
  end

end
