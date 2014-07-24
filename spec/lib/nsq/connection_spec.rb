require_relative '../../spec_helper'

describe Nsq::Connection do
  before do
    @cluster = NsqCluster.new(nsqd_count: 1)
    @cluster.block_until_running
    @connection = Nsq::Connection.new(@cluster.nsqd[0].host, @cluster.nsqd[0].tcp_port)
  end
  after do
    @cluster.destroy
  end


  describe '#close' do
    it 'can be called multiple times, without issue' do
      expect{
        10.times{@connection.close}
      }.not_to raise_error
    end
  end


  describe 'private methods' do
    describe 'NSQ commands' do
      describe '#identify' do
        it 'generates a correct id' do
          expect(@connection).to receive(:write).with(
            %Q{IDENTIFY\n\x00\x00\x01.{\"client_id\":\"robbys-macbook-pro.local\",\"hostname\":\"Robbys-MacBook-Pro.local\",\"feature_negotiation\":false,\"heartbeat_interval\":30000,\"output_buffer\":16000,\"output_buffer_timeout\":250,\"tls_v1\":false,\"snappy\":false,\"deflate\":false,\"sample_rate\":0,\"user_agent\":\"nsq-ruby-client/0.0.1\",\"msg_timeout\":60000}}
          )
          @connection.send :identify
        end
      end
    end
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
