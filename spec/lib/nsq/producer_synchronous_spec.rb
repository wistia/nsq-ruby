require_relative '../../spec_helper'

describe Nsq::Producer do
  context 'with a synchronous producer' do
    before do
      @cluster = NsqCluster.new(nsqd_count: 1)
      @nsqd = @cluster.nsqd.first
      @producer = new_producer(@nsqd, synchronous: true)
    end

    after do
      @producer.terminate if @producer
      @cluster.destroy
    end

    describe '#write' do
      it 'shouldn\'t raise an error when nsqd is down' do
        @nsqd.stop

        expect{
          @producer.write('fail')
        }.to raise_error(RuntimeError, "No data from socket")
      end
    end
  end
end
