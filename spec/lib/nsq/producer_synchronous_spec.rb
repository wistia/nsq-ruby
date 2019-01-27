require_relative '../../spec_helper'

describe Nsq::Producer do
  context 'with a synchronous producer without retry' do
    before do
      @cluster = NsqCluster.new(nsqd_count: 1)
      @nsqd = @cluster.nsqd.first
      @producer = new_producer(@nsqd, synchronous: true, retry_attempts: 0)
    end

    after do
      @producer.terminate if @producer
      @cluster.destroy
    end

    describe '#write' do
      it 'should raise an error when nsqd is down' do
        @nsqd.stop

        expect{
          @producer.write('fail')
        }.to raise_error(Nsq::UnexpectedFrameError)
      end
    end
  end

  context 'with a synchronous producer with retries (default behavior)' do
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

        Thread.new { sleep 3 ; @nsqd.start }

        expect{ @producer.write('fail') }.not_to raise_error
      end
    end
  end
end
