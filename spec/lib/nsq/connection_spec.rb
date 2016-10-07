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
      }.to raise_error
    end

    it 'should raise an exception if it connects to something that isn\'t nsqd' do
      expect{
        # try to connect to the HTTP port instead of TCP
        Nsq::Connection.new(host: @nsqd.host, port: @nsqd.http_port)
      }.to raise_error
    end

    it 'should raise an exception if max_in_flight is above what the server supports' do
      expect{
        # try to connect to the HTTP port instead of TCP
        Nsq::Connection.new(host: @nsqd.host, port: @nsqd.tcp_port, max_in_flight: 1_000_000)
      }.to raise_error
    end

    context 'tls usage' do
      it 'tls is used when tls_v1 is true and ssl_context provided' do
        params = {
          host: @nsqd.host,
          port: @nsqd.tcp_port,
          tls_v1: true,
          ssl_context: ssl_context
        }

        conn = Nsq::Connection.new(params)
        expect(conn.instance_variable_get(:@socket)).
          to be_an_instance_of(OpenSSL::SSL::SSLSocket)
        conn.close
      end
      it 'tls is used when tls_v1 is true and no ssl_context provided' do
        params = {
          host: @nsqd.host,
          port: @nsqd.tcp_port,
          tls_v1: true
        }

        conn = Nsq::Connection.new(params)
        expect(conn.instance_variable_get(:@socket)).
          to be_an_instance_of(OpenSSL::SSL::SSLSocket)
        conn.close
      end
      it 'tls not used when tls_v1 is false and ssl_context provided' do
        params = {
          host: @nsqd.host,
          port: @nsqd.tcp_port,
          tls_v1: false,
          ssl_context: ssl_context
        }

        conn = Nsq::Connection.new(params)
        expect(conn.instance_variable_get(:@socket)).
          to be_an_instance_of(TCPSocket)
        conn.close
      end
      it 'tls not used when tls_v1 is false and no ssl_context provided' do
        params = {
          host: @nsqd.host,
          port: @nsqd.tcp_port,
          tls_v1: false
        }

        conn = Nsq::Connection.new(params)
        expect(conn.instance_variable_get(:@socket)).
          to be_an_instance_of(TCPSocket)
        conn.close
      end
    end

    context 'when an ssl_context is provided' do
      it 'raises when a key is not provided' do
        params = {
          host: @nsqd.host,
          port: @nsqd.tcp_port,
          ssl_context: {
            certificate: 'blank',
          }
        }

        expect{
          Nsq::Connection.new(params)
        }.to raise_error ArgumentError, /key/
      end

      it 'raises when a certificate is not provided' do
        params = {
          host: @nsqd.host,
          port: @nsqd.tcp_port,
          ssl_context: {
            key: 'blank',
          }
        }

        expect{
          Nsq::Connection.new(params)
        }.to raise_error ArgumentError, /certificate/
      end

      it 'raises when the key or cert files are not readable' do
        params = {
          host: @nsqd.host,
          port: @nsqd.tcp_port,
          ssl_context: {
            key: 'not_a_file',
            certificate: 'not_a_file'
          }
        }

        expect{
          Nsq::Connection.new(params)
        }.to raise_error LoadError, /unreadable/
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
