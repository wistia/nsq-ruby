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
      @consumer.terminate
      @cluster.destroy
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


  describe 'when using lookupd' do
    before do
      @cluster = NsqCluster.new(nsqd_count: 2, nsqlookupd_count: 1)
      @cluster.block_until_running
      @topic = 'some-topic'
      lookupd = @cluster.nsqlookupd.first
      @consumer = Nsq::Consumer.new(
        topic: @topic,
        channel: 'some-channel',
        lookupd: "#{lookupd.host}:#{lookupd.http_port}",
        max_in_flight: 1
      )
    end
    after do
      @consumer.terminate
      @cluster.destroy
    end

    describe '#messages' do
      it 'receives messages from both queues' do
        expected_messages = (1..20).to_a.map(&:to_s)

        # distribute messages amongst the queues
        expected_messages.each_with_index do |message, idx|
          @cluster.nsqd[idx % @cluster.nsqd.length].pub(@topic, message)
        end

        received_messages = []

        # gather all the messages
        assert_no_timeout(2) do
          expected_messages.length.times do
            msg = @consumer.messages.pop
            received_messages << msg.body
            msg.finish
          end
        end

        expect(received_messages.sort).to eq(expected_messages.sort)
      end

    end
  end

end
