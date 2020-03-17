require_relative '../../spec_helper'

describe Nsq::Connection do
  before do
    @cluster = NsqCluster.new(nsqd_count: 1)
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

      expect{
        Nsq::Connection.new(host: @nsqd.host, port: @nsqd.tcp_port)
      }.to raise_error(Errno::ECONNREFUSED)
    end

    it 'should raise an exception if it connects to something that isn\'t nsqd' do
      expect{
        # try to connect to the HTTP port instead of TCP
        Nsq::Connection.new(host: @nsqd.host, port: @nsqd.http_port)
      }.to raise_error(RuntimeError, /Bad frame type specified/)
    end

    it 'should raise an exception if max_in_flight is above what the server supports' do
      expect{
        # try to connect to the HTTP port instead of TCP
        Nsq::Connection.new(host: @nsqd.host, port: @nsqd.tcp_port, max_in_flight: 1_000_000)
      }.to raise_error(RuntimeError, "max_in_flight is set to 1000000, server only supports 2500")
    end

    %w(tls_options ssl_context).map(&:to_sym).each do |tls_options_key|
      context "when #{tls_options_key} is provided" do
        it 'validates when tls_v1 is true' do
          params = {
            host: @nsqd.host,
            port: @nsqd.tcp_port,
            tls_v1: true
          }
          params[tls_options_key] = {
            certificate: 'blank'
          }

          expect{
            Nsq::Connection.new(params)
          }.to raise_error ArgumentError, /key/
        end
        it 'skips validation when tls_v1 is false' do
          params = {
            host: @nsqd.host,
            port: @nsqd.tcp_port,
            tls_v1: false
          }
          params[tls_options_key] = {
            certificate: 'blank'
          }

          expect{
            Nsq::Connection.new(params)
          }.not_to raise_error
        end
        it 'raises when a key is not provided' do
          params = {
            host: @nsqd.host,
            port: @nsqd.tcp_port,
            tls_v1: true
          }
          params[tls_options_key] = {
            certificate: 'blank'
          }

          expect{
            Nsq::Connection.new(params)
          }.to raise_error ArgumentError, /key/
        end

        it 'raises when a certificate is not provided' do
          params = {
            host: @nsqd.host,
            port: @nsqd.tcp_port,
            tls_v1: true
          }
          params[tls_options_key] = {
            key: 'blank'
          }

          expect{
            Nsq::Connection.new(params)
          }.to raise_error ArgumentError, /certificate/
        end

        it 'raises when the key or cert files are not readable' do
          params = {
            host: @nsqd.host,
            port: @nsqd.tcp_port,
            tls_v1: true
          }
          params[tls_options_key] = {
            key: 'blank',
            certificate: 'blank'
          }

          expect{
            Nsq::Connection.new(params)
          }.to raise_error LoadError, /unreadable/
        end
      end
    end
  end


  describe '#close' do
    it 'can be called multiple times, without issue' do
      expect{
        10.times{@connection.close}
      }.not_to raise_error
    end
  end

  describe '#pause' do
    it 'should send rdy(0)' do
      expect(@connection).to receive(:rdy).with(0)
      @connection.pause
      expect(@connection.paused?).to eq(true)
    end

    it 'should be a no-op' do
      expect(@connection).to receive(:rdy).with(0).exactly(1).times
      @connection.pause
      @connection.pause
    end
  end

  describe '#resume' do
    it 'should set back the rdy value to the max_in_flight' do
      @connection.pause
      expect(@connection).to receive(:rdy).with(@connection.max_in_flight)
      @connection.resume
      expect(@connection.paused?).to eq(false)
    end

    it 'should be a no-op if not paused' do
      expect(@connection).not_to receive(:rdy)
      @connection.resume
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
