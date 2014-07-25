require_relative '../../spec_helper'
require 'json'
require 'timeout'

describe Nsq::Consumer do

  describe 'when connecting to nsqd directly' do

    before do
      @cluster = NsqCluster.new(nsqd_count: 1)
      @cluster.block_until_running
      @nsqd = @cluster.nsqd.first
      @consumer = new_consumer(nsqlookupd: nil, nsqd: "#{@nsqd.host}:#{@nsqd.tcp_port}")
    end
    after do
      @consumer.terminate
      @cluster.destroy
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

  end


  describe 'when using lookupd' do
    before do
      @cluster = NsqCluster.new(nsqd_count: 2, nsqlookupd_count: 1)
      @cluster.block_until_running
    end
    after do
      @cluster.destroy
    end

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

end
