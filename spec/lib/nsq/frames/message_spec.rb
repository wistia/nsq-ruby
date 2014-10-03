require_relative '../../../spec_helper'

describe Nsq::Message do
  before do
    @cluster = NsqCluster.new(nsqd_count: 1)
    @nsqd = @cluster.nsqd.first
  end
  after do
    @cluster.destroy
  end

  def new_consumer
    Nsq::Consumer.new(
      topic: TOPIC,
      channel: CHANNEL,
      nsqd: "#{@nsqd.host}:#{@nsqd.tcp_port}",
      max_in_flight: 1
    )
  end

  describe '#timestamp' do
    it 'should be a Time object' do
      @nsqd.pub(TOPIC, Time.now.to_f.to_s)
      consumer = new_consumer
      expect(consumer.pop.timestamp.is_a?(Time)).to eq(true)
      consumer.terminate
    end


    it 'should be when the message was produced, not when it was received by the consumer' do
      @nsqd.pub(TOPIC, Time.now.to_f.to_s)

      # wait a tick (so the time the consumer receives the message will be
      # different than when it was published)
      sleep 0.1

      consumer = new_consumer
      msg = consumer.pop
      expect(msg.timestamp.to_f).to be_within(0.01).of(msg.body.to_f)

      consumer.terminate
    end
  end
end
