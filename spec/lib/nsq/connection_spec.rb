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

  describe '#frame_class_for_type' do
    FRAME_CLASSES = [Nsq::Error, Nsq::Message, Nsq::Response]
    it 'returns a frame object for types 0-2' do
      (0..2).each do |type|
        expect(
          FRAME_CLASSES.include?(@connection.send(:frame_class_for_type, type))
        ).to be_truthy
      end
    end
  end
end
