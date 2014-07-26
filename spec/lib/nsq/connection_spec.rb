require_relative '../../spec_helper'

describe Nsq::Connection do
  before do
    @cluster = NsqCluster.new(nsqd_count: 1)
    @cluster.block_until_running
    @nsqd = @cluster.nsqd.first
    @connection = Nsq::Connection.new(host: @cluster.nsqd[0].host, port: @cluster.nsqd[0].tcp_port)
  end
  after do
    @connection.close
    @cluster.destroy
  end


  describe '::new' do
    it 'should raise an exception if it cannot connect to nsqd' do
      @nsqd.stop
      @nsqd.block_until_stopped

      expect{
        Nsq::Connection.new(host: @nsqd.host, port: @nsqd.tcp_port)
      }.to raise_error
    end

    it 'should raise an exception if it connects to something that isn\'t nsqd' do
      expect{
        # try to connect to the HTTP port instead of TCP
        Nsq::Connection.new(host: @nsqd.host, port: @nsqd.http_port)
      }.to raise_error
    end
  end


  describe '#close' do
    it 'can be called multiple times, without issue' do
      expect{
        10.times{@connection.close}
      }.not_to raise_error
    end
  end


  # This is really testing the ability for Connection to reconnect
  describe '#connected?' do
    before do
      # For speedier timeouts
      set_speedy_connection_timeouts!
    end

    it 'should return true when nsqd is up and false when nsqd is down' do
      wait_for{@connection.connected?}
      expect(@connection.connected?).to eq(true)
      @nsqd.stop
      wait_for{!@connection.connected?}
      expect(@connection.connected?).to eq(false)
      @nsqd.start
      wait_for{@connection.connected?}
      expect(@connection.connected?).to eq(true)
    end

  end


  describe 'private methods' do
    describe '#frame_class_for_type' do
      MAX_VALID_TYPE = described_class::FRAME_CLASSES.length - 1
      it "returns a frame class for types 0-#{MAX_VALID_TYPE}" do
        (0..MAX_VALID_TYPE).each do |type|
          expect(
            described_class::FRAME_CLASSES.include?(
              @connection.send(:frame_class_for_type, type)
            )
          ).to be_truthy
        end
      end
      it "raises an error if invalid type > #{MAX_VALID_TYPE} specified" do
        expect {
          @connection.send(:frame_class_for_type, 3)
        }.to raise_error(RuntimeError)
      end
    end


    describe '#handle_response' do
      it 'responds to heartbeat with NOP' do
        frame = Nsq::Response.new(described_class::RESPONSE_HEARTBEAT, @connection)
        expect(@connection).to receive(:nop)
        @connection.send(:handle_response, frame)
      end
    end
  end
end
