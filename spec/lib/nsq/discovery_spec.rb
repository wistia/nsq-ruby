require_relative '../../spec_helper'

NSQD_COUNT = 5

describe Nsq::Discovery do
  before do
    @cluster = NsqCluster.new(nsqd_count: NSQD_COUNT, nsqlookupd_count: 2)
    @topic = 'some-topic'

    # make sure each nsqd has a message for this topic
    # leave the last nsqd without this topic for testing
    @cluster.nsqd.take(NSQD_COUNT-1).each do |nsqd|
      nsqd.pub(@topic, 'some-message')
    end
    @cluster.nsqd.last.pub('some-other-topic', 'some-message')

    @expected_topic_lookup_nsqds = @cluster.nsqd.take(NSQD_COUNT-1).map{|d|"#{d.host}:#{d.tcp_port}"}.sort
    @expected_all_nsqds = @cluster.nsqd.map{|d|"#{d.host}:#{d.tcp_port}"}.sort
  end

  after do
    @cluster.destroy
  end


  def new_discovery(cluster_lookupds)
    lookupds = cluster_lookupds.map do |lookupd|
      "#{lookupd.host}:#{lookupd.http_port}"
    end

    # one lookupd has scheme and one does not
    lookupds.last.prepend 'http://'

    Nsq::Discovery.new(lookupds)
  end


  describe 'a single nsqlookupd' do
    before do
      @discovery = new_discovery([@cluster.nsqlookupd.first])
    end

    describe '#nsqds' do
      it 'returns all nsqds' do
        nsqds = @discovery.nsqds
        expect(nsqds.sort).to eq(@expected_all_nsqds)
      end
    end

    describe '#nsqds_for_topic' do
      it 'returns [] for a topic that doesn\'t exist' do
        nsqds = @discovery.nsqds_for_topic('topic-that-does-not-exists')
        expect(nsqds).to eq([])
      end

      it 'returns all nsqds' do
        nsqds = @discovery.nsqds_for_topic(@topic)
        expect(nsqds.sort).to eq(@expected_topic_lookup_nsqds)
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
        expect(nsqds.sort).to eq(@expected_topic_lookup_nsqds)
      end
    end
  end


  describe 'multiple nsqlookupds, but one is down' do
    before do
      @downed_nsqlookupd = @cluster.nsqlookupd.first
      @downed_nsqlookupd.stop

      @discovery = new_discovery(@cluster.nsqlookupd)
    end

    describe '#nsqds_for_topic' do
      it 'returns all nsqds' do
        nsqds = @discovery.nsqds_for_topic(@topic)
        expect(nsqds.sort).to eq(@expected_topic_lookup_nsqds)
      end
    end
  end
end
