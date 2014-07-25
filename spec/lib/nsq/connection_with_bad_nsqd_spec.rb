require_relative '../../spec_helper'

describe Nsq::Connection do
  before do
    @cluster = NsqCluster.new(nsqd_count: 1)
    @cluster.block_until_running
    @nsqd = @cluster.nsqd.first

    # make this thing retry connections like crazy!
    allow_any_instance_of(Nsq::Connection).to receive(:snooze).and_return(0.01)
  end
  after do
    @cluster.destroy
  end


  describe 'when nsqd starts down' do
    before do
      @nsqd.stop
      @nsqd.block_until_stopped
    end

    it 'shouldn\'t explode' do
      expect{
        @connection = Nsq::Connection.new(@nsqd.host, @nsqd.tcp_port)
      }.not_to raise_error
    end

    it 'should connect when nsqd comes online' do
      @connection = Nsq::Connection.new(@nsqd.host, @nsqd.tcp_port)
      @nsqd.start
      wait_for{@connection.connected?}
    end

    # this is just connection refused error, what about network unreachable
    # or if nsqd is acting weird?
  end


  describe 'when nsqd goes down after we\'re connected' do
    before do
      @connection = Nsq::Connection.new(@nsqd.host, @nsqd.tcp_port)
      wait_for{@connection.connected?}
    end

    it 'should detect that it\'s down' do
      expect(@connection.connected?).to eq(true)
      @nsqd.stop
      wait_for{!@connection.connected?}
      expect(@connection.connected?).to eq(false)
    end

    it 'should reconnect when it\'s back' do
      expect(@connection.connected?).to eq(true)
      @nsqd.stop
      wait_for{!@connection.connected?}
      @nsqd.start
      wait_for{@connection.connected?}
      expect(@connection.connected?).to eq(true)
    end
  end


end
