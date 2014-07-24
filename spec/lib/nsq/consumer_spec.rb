require_relative '../../spec_helper'
require 'json'
require 'timeout'

describe Nsq::Consumer do

  describe 'when connecting to nsqd directly' do

    before do
      @cluster = NsqCluster.new(nsqd_count: 1)
      @cluster.block_until_running
      @nsqd = @cluster.nsqd.first
      @topic = 'some-topic'
      @consumer = Nsq::Consumer.new(
        topic: @topic,
        channel: 'some-channel',
        nsqd: "#{@nsqd.host}:#{@nsqd.tcp_port}",
        max_in_flight: 1
      )
    end
    after do
      @cluster.destroy
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


  describe 'when using lookupd' do
    before do
      @cluster = NsqCluster.new(nsqd_count: 2, nsqlookupd_count: 1)
      @cluster.block_until_running
      @topic = 'some-topic'
    end
    after do
      @cluster.destroy
    end

    describe '#messages' do
      def build_consumer
        lookupd = @cluster.nsqlookupd.first
        Nsq::Consumer.new(
          topic: @topic,
          channel: 'some-channel',
          nsqlookupd: "#{lookupd.host}:#{lookupd.http_port}",
          max_in_flight: 1
        )
      end
      it 'receives messages from both queues' do
        expected_messages = (1..20).to_a.map(&:to_s)

        # distribute messages amongst the queues
        expected_messages.each_with_index do |message, idx|
          @cluster.nsqd[idx % @cluster.nsqd.length].pub(@topic, message)
        end

        received_messages = []

        # gather all the messages
        consumer = build_consumer
        assert_no_timeout(2) do
          expected_messages.length.times do
            msg = consumer.messages.pop
            received_messages << msg.body
            msg.finish
          end
        end

        expect(received_messages.sort).to eq(expected_messages.sort)
      end

    end
  end

end
