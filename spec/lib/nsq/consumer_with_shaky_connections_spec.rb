require_relative '../../spec_helper'

describe Nsq::Consumer do

  before do
    @nsqd_count = 3
    @cluster = NsqCluster.new(nsqlookupd_count: 2, nsqd_count: @nsqd_count)
    @cluster.block_until_running

    # publish a message to each queue
    # so that when the consumer starts up, it will connect to all of them
    @cluster.nsqd.each do |nsqd|
      nsqd.pub(TOPIC, 'hi')
    end

    @consumer = new_consumer(max_in_flight: 20, discovery_interval: 0.1)
    wait_for { @consumer.connections.length == @nsqd_count }
  end

  after do
    @consumer.terminate
    @cluster.destroy
  end


  it 'should drop a connection when an nsqd goes down' do
    @cluster.nsqd.last.stop

    wait_for{@consumer.connections.length == @nsqd_count - 1}
  end


  it 'should add a connection when an nsqd comes back online' do
    @cluster.nsqd.last.stop
    wait_for{@consumer.connections.length == @nsqd_count - 1}

    @cluster.nsqd.last.start
    wait_for{@consumer.connections.length == @nsqd_count}
  end


  it 'should continue processing messages from live queues when one queue is down' do
    # shut down the last nsqd
    @cluster.nsqd.last.stop

    # make sure there are more messages on each queue than max in flight
    50.times{@cluster.nsqd[0].pub(TOPIC, 'hay')}
    50.times{@cluster.nsqd[1].pub(TOPIC, 'hay')}

    assert_no_timeout do
      100.times do
        msg = @consumer.messages.pop
        if msg.connection.alive?
          msg.finish
        else
          @consumer.messages.push msg
        end
      end
    end
  end


  it 'should process messages from a new queue when it comes online' do
    begin
      nsqd = @cluster.nsqd.last
      nsqd.stop

      thread = Thread.new do
        nsqd.start
        nsqd.block_until_running
        nsqd.pub(TOPIC, 'needle')
      end

      wait_for do
        string = nil
        until string == 'needle'
          msg = @consumer.messages.pop
          string = msg.body
          msg.finish
        end
        true
      end

      thread.join
    end
  end


  it 'should be able to handle all queues going offline and coming back' do
    begin
      expected_messages = @cluster.nsqd.map{|nsqd| nsqd.tcp_port.to_s}

      thread = Thread.new do
        @cluster.nsqd.each { |q| q.stop }
        @cluster.nsqd.each { |q| q.start }
        @cluster.block_until_running

        @cluster.nsqd.each_with_index do |nsqd, idx|
          nsqd.pub(TOPIC, expected_messages[idx])
        end
      end

      assert_no_timeout(60) do
        received_messages = []

        while (expected_messages & received_messages).length < expected_messages.length do
          msg = @consumer.messages.pop
          received_messages << msg.body
          puts msg.body
          msg.finish
        end

        # ladies and gentlemen, we got 'em
      end

    ensure
      thread.join
    end
  end

=begin
  it 'should be able to rely on the second nsqlookupd if the first dies' do
    @cluster.nsqlookupd.first.stop

    producer = new_producer(@cluster.nsqd.first, :topic => 'new-topic')
    producer.write('new message on new topic')
    consumer = new_consumer(:topic => 'new-topic')

    Timeout::timeout(5) do
      msg = consumer.queue.pop
      msg.content.must_equal 'new message on new topic'
    end
  end
=end

end

