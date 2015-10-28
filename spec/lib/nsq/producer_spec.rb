require_relative '../../spec_helper'
require 'json'

describe Nsq::Producer do

  def message_count(topic = @producer.topic)
    topics_info = JSON.parse(@nsqd.stats.body)['data']['topics']
    topic_info = topics_info.select{|t| t['topic_name'] == topic }.first
    if topic_info
      topic_info['message_count']
    else
      0
    end
  end

  context 'connecting directly to a single nsqd' do

    def new_consumer(topic = TOPIC)
      Nsq::Consumer.new(
        topic: topic,
        channel: CHANNEL,
        nsqd: "#{@nsqd.host}:#{@nsqd.tcp_port}",
        max_in_flight: 1
      )
    end

    before do
      @cluster = NsqCluster.new(nsqd_count: 1)
      @nsqd = @cluster.nsqd.first
      @producer = new_producer(@nsqd)
    end

    after do
      @producer.terminate if @producer
      @cluster.destroy
    end

    describe '::new' do
      it 'should throw an exception when trying to connect to a server that\'s down' do
        @nsqd.stop

        expect{
          new_producer(@nsqd)
        }.to raise_error
      end
    end

    describe '#connected?' do
      it 'should return true when it is connected' do
        expect(@producer.connected?).to eq(true)
      end

      it 'should return false when nsqd is down' do
        @nsqd.stop
        wait_for{!@producer.connected?}
        expect(@producer.connected?).to eq(false)
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

        expect{
          10.times{@producer.write('fail')}
        }.to_not raise_error
      end

      it 'will attempt to resend messages when it reconnects to nsqd' do
        @nsqd.stop

        # Write 10 messages while nsqd is down
        10.times{|i| @producer.write(i)}

        @nsqd.start

        messages_received = []

        begin
          consumer = new_consumer
          assert_no_timeout(5) do
            # TODO: make the socket fail faster
            # We only get 8 or 9 of the 10 we send. The first few can be lost
            # because we can't detect that they didn't make it.
            8.times do |i|
              msg = consumer.pop
              messages_received << msg.body
              msg.finish
            end
          end
        ensure
          consumer.terminate
        end

        expect(messages_received.uniq.length).to eq(8)
      end

      # Test PUB
      it 'can send a single message with unicode characters' do
        @producer.write('☺')
        consumer = new_consumer
        assert_no_timeout do
          expect(consumer.pop.body).to eq('☺')
        end
        consumer.terminate
      end

      # Test MPUB as well
      it 'can send multiple message with unicode characters' do
        @producer.write('☺', '☺', '☺')
        consumer = new_consumer
        assert_no_timeout do
          3.times do
            msg = consumer.pop
            expect(msg.body).to eq('☺')
            msg.finish
          end
        end
        consumer.terminate
      end

    end

    describe '#write_to_topic' do
      it 'can queue a single message for a topic' do
        @producer.write_to_topic('topic-a', 'some-message')
        @producer.write_to_topic('topic-b', 'some-message')
        wait_for{message_count('topic-a')==1}
        wait_for{message_count('topic-b')==1}
        expect(message_count('topic-a')).to eq(1)
        expect(message_count('topic-b')).to eq(1)
      end

      it 'can queue multiple messages at once for a topic' do
        @producer.write_to_topic('topic-a', 1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
        @producer.write_to_topic('topic-b', 1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
        wait_for{message_count('topic-a')==10}
        wait_for{message_count('topic-b')==10}
        expect(message_count('topic-a')).to eq(10)
        expect(message_count('topic-b')).to eq(10)
      end

      it 'puts correct messages on correct topics' do
        consumer_a = new_consumer('topic-a')
        consumer_b = new_consumer('topic-b')

        @producer.write_to_topic('topic-a', 1, 2)
        @producer.write_to_topic('topic-b', 3, 4)
        @producer.write_to_topic('topic-a', 5)

        wait_for{message_count('topic-a') == 3}
        wait_for{message_count('topic-b') == 2}

        a_msgs = [1, 2, 5].map{|i| i.to_s}
        b_msgs = [3, 4].map{|i| i.to_s}
        3.times do
          a = consumer_a.pop
          expect(a_msgs).to include(a.body)
          a_msgs.delete(a.body)
          a.finish
        end
        2.times do
          b = consumer_b.pop
          expect(b_msgs).to include(b.body)
          b_msgs.delete(b.body)
          b.finish
        end

        expect(consumer_a.size).to eq(0)
        expect(consumer_b.size).to eq(0)

        consumer_a.terminate
        consumer_b.terminate
      end
    end

  end

  context 'connecting via nsqlookupd' do

    before do
      @cluster = NsqCluster.new(nsqd_count: 2, nsqlookupd_count: 1)
      @producer = new_lookupd_producer

      # wait for it to connect to all nsqds
      wait_for{ @producer.connections.length == @cluster.nsqd.length }
    end

    after do
      @producer.terminate if @producer
      @cluster.destroy
    end


    describe '#connections' do
      it 'should be connected to all nsqds' do
        expect(@producer.connections.length).to eq(@cluster.nsqd.length)
      end

      it 'should drop a connection when an nsqd goes offline' do
        @cluster.nsqd.first.stop
        wait_for{ @producer.connections.length == @cluster.nsqd.length - 1 }
        expect(@producer.connections.length).to eq(@cluster.nsqd.length - 1)
      end
    end


    describe '#connected?' do
      it 'should return true if it\'s connected to at least one nsqd' do
        expect(@producer.connected?).to eq(true)
      end

      it 'should return false when it\'s not connected to any nsqds' do
        @cluster.nsqd.each{|nsqd| nsqd.stop}
        wait_for{ !@producer.connected? }
        expect(@producer.connected?).to eq(false)
      end
    end


    describe '#write' do
      it 'writes to a random connection' do
        expect_any_instance_of(Nsq::Connection).to receive(:pub)
        @producer.write('howdy!')
      end

      it 'raises an error if there are no connections to write to' do
        @cluster.nsqd.each{|nsqd| nsqd.stop}
        wait_for{ @producer.connections.length == 0 }
        expect {
          @producer.write('die')
        }.to raise_error
      end
    end

  end
end
