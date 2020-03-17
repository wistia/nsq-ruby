require_relative '../../spec_helper'
require 'json'
require 'timeout'

describe Nsq::Consumer do
  before do
    @cluster = NsqCluster.new(nsqd_count: 2, nsqlookupd_count: 1)
  end

  after do
    @cluster.destroy
  end


  describe 'when connecting to nsqd directly' do
    before do
      @nsqd = @cluster.nsqd.first
      @consumer = new_consumer(nsqlookupd: nil, nsqd: "#{@nsqd.host}:#{@nsqd.tcp_port}", max_in_flight: 10)
    end
    after do
      @consumer.terminate
    end


    describe '::new' do
      it 'should throw an exception when trying to connect to a server that\'s down' do
        @nsqd.stop

        expect{
          new_consumer(nsqlookupd: nil, nsqd: "#{@nsqd.host}:#{@nsqd.tcp_port}")
        }.to raise_error(Errno::ECONNREFUSED)
      end
    end


    # This is testing the behavior of the consumer, rather than the size method itself
    describe '#size' do
      it 'doesn\'t exceed max_in_flight for the consumer' do
        # publish a bunch of messages
        (@consumer.max_in_flight * 2).times do
          @nsqd.pub(@consumer.topic, 'some-message')
        end

        wait_for{@consumer.size >= @consumer.max_in_flight}
        expect(@consumer.size).to eq(@consumer.max_in_flight)
      end
    end

    describe '#pause' do
      it 'should not receive any message when paused' do
        @consumer.pause
        @nsqd.pub(@consumer.topic, 'some-message')
        assert_timeout(1) do
          @consumer.pop
        end
      end
    end

    describe '#resume' do
      it 'should get back messages when paused consumer is resumed' do
        @consumer.pause
        @nsqd.pub(@consumer.topic, 'some-message')
        Thread.new {
          sleep 0.5
          @consumer.resume
        }
        assert_no_timeout(1) do
          @consumer.pop
        end
      end
    end

    describe '#pop' do
      it 'can pop off a message' do
        @nsqd.pub(@consumer.topic, 'some-message')
        assert_no_timeout(1) do
          msg = @consumer.pop
          expect(msg.body).to eq('some-message')
          msg.finish
        end
      end

      it 'can pop off many messages' do
        10.times{@nsqd.pub(@consumer.topic, 'some-message')}
        assert_no_timeout(1) do
          10.times{@consumer.pop.finish}
        end
      end

      it 'can receive messages with unicode characters' do
        @nsqd.pub(@consumer.topic, '☺')
        expect(@consumer.pop.body).to eq('☺')
      end

      it 'blocks when there are no messages' do
        assert_timeout do
          @consumer.pop
        end
      end
    end


    describe '#pop_without_blocking' do
      it 'can pop off a message' do
        @nsqd.pub(@consumer.topic, 'some-message')
        wait_for{ @consumer.size > 0 }
        msg = @consumer.pop_without_blocking
        expect(msg.body).to eq('some-message')
        msg.finish
      end

      it 'does not block and immediately returns nil if there are no messages' do
        assert_no_timeout(1) do
          expect(@consumer.pop_without_blocking).to eq(nil)
        end
      end
    end


    describe '#req' do
      it 'can successfully requeue a message' do
        # queue a message
        @nsqd.pub(TOPIC, 'twice')

        msg = @consumer.pop

        expect(msg.body).to eq('twice')

        # requeue it
        msg.requeue

        req_msg = @consumer.pop
        expect(req_msg.body).to eq('twice')
        expect(req_msg.attempts).to eq(2)
      end
    end
  end


  describe 'when using lookupd' do
    before do
      @expected_messages = (1..20).to_a.map(&:to_s)
      @expected_messages.each_with_index do |message, idx|
        @cluster.nsqd[idx % @cluster.nsqd.length].pub(TOPIC, message)
      end

      @consumer = new_consumer(max_in_flight: 10)
    end

    after do
      @consumer.terminate
    end

    describe '#pop' do
      it 'receives messages from both queues' do
        received_messages = []

        # gather all the messages
        assert_no_timeout(2) do
          @expected_messages.length.times do
            msg = @consumer.pop
            received_messages << msg.body
            msg.finish
          end
        end

        expect(received_messages.sort).to eq(@expected_messages.sort)
      end
    end

    # This is testing the behavior of the consumer, rather than the size method itself
    describe '#size' do
      it 'doesn\'t exceed max_in_flight for the consumer' do
        wait_for{@consumer.size >= @consumer.max_in_flight}
        expect(@consumer.size).to eq(@consumer.max_in_flight)
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

      msg1 = @consumer.pop
      expect(msg1.body).to eq('slow')
      expect(msg1.attempts).to eq(1)

      # NOTE: In nsqd 0.3.6, the introduction of the centralized queue instead
      # of per channel workers also brought a 5 second
      # `QueueScanRefreshInterval`. So even though we set `msg_timeout` to 1
      # second, our messages won't be requeued any faster than 5 seconds.
      #
      # https://github.com/nsqio/nsq/blob/v0.3.6/nsqd/options.go#L104

      # Wait for our message to be reclaimed by nsqd and then finish it so we
      # can get another.
      assert_no_timeout(10) do
        msg2 = @consumer.pop
        expect(msg2.body).to eq('slow')
        expect(msg2.attempts).to eq(2)
      end
    end


    # This is like the test above, except we touch the message to reset its
    # timeout
    it 'should be able to touch a message to reset its timeout' do
      @nsqd.pub(TOPIC, 'slow')

      msg1 = @consumer.pop
      expect(msg1.body).to eq('slow')

      # touch the message in the middle of a sleep session whose total just
      # exceeds the msg_timeout
      sleep(@msg_timeout / 2.0 + 0.1)
      msg1.touch
      sleep(@msg_timeout / 2.0 + 0.1)
      msg1.finish

      # if our touch didn't work, we should receive a message
      assert_timeout do
        @consumer.pop
      end
    end


    describe '#drop_and_add_connections' do
      context 'lookupd returns nsqd instances that are down' do
        it 'should log an error and not explode' do
          # expect an error log call
          expect(@consumer).to receive(:error)

          expect {
            @consumer.send(:drop_and_add_connections, ['127.0.0.1:4321'])
          }.to_not raise_error
        end
      end
    end
  end


  describe 'with a high max_in_flight and tons of messages' do
    it 'should receive all messages in a reasonable amount of time' do
      expected_messages = (1..10_000).to_a.map(&:to_s)
      expected_messages.each_slice(100) do |slice|
        @cluster.nsqd.sample.mpub(TOPIC, *slice)
      end

      consumer = new_consumer(max_in_flight: 1000)
      received_messages = []

      assert_no_timeout(5) do
        expected_messages.length.times do
          msg = consumer.pop
          received_messages << msg.body
          msg.finish
        end
      end

      consumer.terminate

      expect(received_messages.sort).to eq(expected_messages.sort)
    end
  end


  describe 'when max_attempts is set' do
    before do
      @nsqd = @cluster.nsqd.first
      @msg_timeout = 1
      @max_attempts = 1
      @consumer = new_consumer(
        nsqlookupd: nil,
        nsqd: "#{@nsqd.host}:#{@nsqd.tcp_port}",
        msg_timeout: @msg_timeout * 1000, # in milliseconds
        max_attempts: @max_attempts
      )
    end
    after do
      @consumer.terminate
    end


    it 'should only receive a message max_attempts number of times' do
      @nsqd.pub(TOPIC, 'max')

      msg1 = @consumer.pop
      expect(msg1.body).to eq('max')
      expect(msg1.attempts).to eq(1)

      assert_timeout do
        @consumer.pop
      end
    end
  end
end
