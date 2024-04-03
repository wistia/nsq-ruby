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

    describe '::new that is paused' do
      it 'should throw an exception when trying to connect to a server that\'s paused' do
        @nsqd.pause_process

        expect{
          new_consumer(nsqlookupd: nil, nsqd: "#{@nsqd.host}:#{@nsqd.tcp_port}")
        }.to raise_error(Errno::ECONNREFUSED)

      end
    end

    describe '::new that is later paused should show as unhealty due to missing keepalives' do
      it 'should show as unhealthy' do
        puts "\nlong running test"
        consumer = new_consumer(nsqlookupd: nil, nsqd: "#{@nsqd.host}:#{@nsqd.tcp_port}")
        expect(consumer.connected?).to eq(true)
        @nsqd.pause_process
        sleep 50  # need to be able to configure this through opts to lower this.
        expect(consumer.connected?).to eq(false)
      end
    end


  end
end
