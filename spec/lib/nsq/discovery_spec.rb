require_relative '../../spec_helper'

describe Nsq::Discovery do
  before(:all) do
    @cluster = NsqCluster.new(nsqd_count: 4, nsqlookupd_count: 2)
    @cluster.block_until_running
    @topic = 'some-topic'

    # make sure each nsqd has a message for this topic
    @cluster.nsqd.each do |nsqd|
      nsqd.pub(@topic, 'some-message')
    end

    @expected_nsqds = @cluster.nsqd.map{|d|"#{d.host}:#{d.tcp_port}"}.sort
  end

  after(:all) do
    @cluster.destroy
  end


  def new_discovery(cluster_lookupds)
    lookupds = cluster_lookupds.map do |lookupd|
      "#{lookupd.host}:#{lookupd.http_port}"
    end

    Nsq::Discovery.new(lookupds)
  end


  describe 'a single nsqlookupd' do
    before do
      @discovery = new_discovery([@cluster.nsqlookupd.first])
    end

    describe '#nsqds_for_topic' do
      it 'returns [] for a topic that doesn\'t exist' do
        nsqds = @discovery.nsqds_for_topic('topic-that-does-not-exists')
        expect(nsqds).to eq([])
      end

      it 'returns all nsqds' do
        nsqds = @discovery.nsqds_for_topic(@topic)
        expect(nsqds.sort).to eq(@expected_nsqds)
      end
    end
  end


  describe 'multiple nsqlookupds' do
    before do
      @discovery = new_discovery(@cluster.nsqlookupd)
    end

    describe '#nsqds_for_topic' do
      it 'returns all nsqds' do
        nsqds = @discovery.nsqds_for_topic(@topic)
        expect(nsqds.sort).to eq(@expected_nsqds)
      end
    end
  end


  describe 'multiple nsqlookupds, but one is down' do
    before do
      @downed_nsqlookupd = @cluster.nsqlookupd.first
      @downed_nsqlookupd.stop

      @discovery = new_discovery(@cluster.nsqlookupd)
    end

    after do
      @downed_nsqlookupd.start
    end

    describe '#nsqds_for_topic' do
      it 'returns all nsqds' do
        nsqds = @discovery.nsqds_for_topic(@topic)
        expect(nsqds.sort).to eq(@expected_nsqds)
      end
    end
  end

end
