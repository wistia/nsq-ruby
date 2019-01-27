require_relative '../../spec_helper'
require 'json'

describe Nsq::Producer do
  def message_count(nsqd, topic = @producer.topic)
    parsed_body = JSON.parse(nsqd.stats.body)
    topics_info = (parsed_body['data'] || parsed_body)['topics']
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
      @cluster = NsqCluster.new(nsqd_count: 2)
      @producer = new_nsqds_producer(@cluster.nsqd, synchronous: true, retry_attempts: 1, ok_timeout: 1)
    end

    after do
      @producer.terminate if @producer
      @cluster.destroy
    end

    describe '::new' do
      it 'should throw an exception if one of the nsqds is down' do
        @cluster.nsqd.first.stop

        expect{
          new_nsqds_producer(@cluster.nsqd)
        }.to raise_error(Errno::ECONNREFUSED)
      end

      it 'should throw an exception if the strategy is unkown' do
        expect{
          new_nsqds_producer(@cluster.nsqd, strategy: :none)
        }.to raise_error(ArgumentError, "strategy should be one of failover, round_robin")
      end
    end

    context 'failover strategy' do
      describe '#write' do
        it 'should send a message to the first nsqd' do
          @producer.write 'first'
          wait_for{message_count(@cluster.nsqd.first)==1}
          expect(message_count(@cluster.nsqd.first)).to eq(1)
        end

        it 'should send a message to the second nsqd if the first is down' do
          @cluster.nsqd[0].stop
          @producer.write 'first'
          wait_for{message_count(@cluster.nsqd[1])==1}
          expect(message_count(@cluster.nsqd[1])).to eq(1)
        end

        it 'should send a message to the first nsqd again if the second is down' do
          @cluster.nsqd[0].stop
          sleep(5)
          @producer.write 'first'
          wait_for{message_count(@cluster.nsqd[1])==1}
          expect(message_count(@cluster.nsqd[1])).to eq(1)
          @producer.write 'second'
          wait_for{message_count(@cluster.nsqd[1])==2}
          expect(message_count(@cluster.nsqd[1])).to eq(2)

          @cluster.nsqd[0].start
          @cluster.nsqd[1].stop

          sleep(5)
          @producer.write 'third'
          wait_for{message_count(@cluster.nsqd[0])==1}
          expect(message_count(@cluster.nsqd[0])).to eq(1)
        end
      end
    end
  end
end
