require_relative '../../spec_helper'

describe Nsq::Consumer do

  before do
    set_speedy_connection_timeouts!

    @nsqd_count = 3
    @cluster = NsqCluster.new(nsqlookupd_count: 2, nsqd_count: @nsqd_count)

    # publish a message to each queue
    # so that when the consumer starts up, it will connect to all of them
    @cluster.nsqd.each do |nsqd|
      nsqd.pub(TOPIC, 'hi')
    end

    @consumer = new_consumer(max_in_flight: 20, discovery_interval: 0.1)
    wait_for{@consumer.connections.length == @nsqd_count}
  end

  after do
    @consumer.terminate
    @cluster.destroy
  end


  # This is really testing that the discovery loop works as expected.
  #
  # The consumer won't evict connections if they go down, the connection itself
  # will try to reconnect.
  #
  # But, when nsqd goes down, nsqlookupd will see that its gone and unregister
  # it. So when the next time the discovery loop runs, that nsqd will no longer
  # be listed.
  it 'should drop a connection when an nsqd goes down and add one when it comes back' do
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

    assert_no_timeout(5) do
      100.times{@consumer.pop.finish}
    end
  end


  it 'should process messages from a new queue when it comes online' do
    nsqd = @cluster.nsqd.last
    nsqd.stop

    thread = Thread.new do
      nsqd.start
      nsqd.pub(TOPIC, 'needle')
    end

    assert_no_timeout(5) do
      string = nil
      until string == 'needle'
        msg = @consumer.pop
        string = msg.body
        msg.finish
      end
      true
    end

    thread.join
  end


  it 'should be able to rely on the second nsqlookupd if the first dies' do
    bad_lookupd = @cluster.nsqlookupd.first
    bad_lookupd.stop

    @cluster.nsqd.first.pub('new-topic', 'new message on new topic')
    consumer = new_consumer(topic: 'new-topic')

    assert_no_timeout do
      msg = consumer.pop
      expect(msg.body).to eq('new message on new topic')
      msg.finish
    end

    consumer.terminate
  end


  it 'should be able to handle all queues going offline and coming back' do
    expected_messages = @cluster.nsqd.map{|nsqd| nsqd.tcp_port.to_s}

    @cluster.nsqd.each{|q| q.stop}
    @cluster.nsqd.each{|q| q.start}

    @cluster.nsqd.each_with_index do |nsqd, idx|
      nsqd.pub(TOPIC, expected_messages[idx])
    end

    assert_no_timeout(10) do
      received_messages = []

      while (expected_messages & received_messages).length < expected_messages.length do
        msg = @consumer.pop
        received_messages << msg.body
        msg.finish
      end

      # ladies and gentlemen, we got 'em
    end
  end

end

