require_relative '../../spec_helper'

describe Nsq::Discovery do
  before(:all) do
    @nsqd_count = 4
    @cluster = NsqCluster.new(nsqd_count: @nsqd_count, nsqlookupd_count: 2)
    @cluster.block_until_running
    @topic = 'some-topic'

    # make sure each nsqd has a message for this topic
    @cluster.nsqd.each do |nsqd|
      nsqd.pub(@topic, 'some-message')
    end
  end

  after(:all) do
    @cluster.destroy
  end


  describe 'a single nsqlookupd' do
    before do
      lookupd = @cluster.nsqlookupd.first
      @lookupds = ["#{lookupd.host}:#{lookupd.http_port}"]
      @discovery = Nsq::Discovery.new(@lookupds)
    end

    it '#nsqds: finds all nsqds' do
      nsqds = @discovery.nsqds_for_topic(@topic)
      expected_nsqds = @cluster.nsqd.map { |d| "#{d.host}:#{d.tcp_port}" }
      expect(nsqds.sort).to eq(expected_nsqds.sort)
      expect(nsqds.length).to eq(@nsqd_count)
    end
  end


  describe 'multiple nsqlookupds' do
    before do
      @lookupds = @cluster.nsqlookupd.map do |lookupd|
        "#{lookupd.host}:#{lookupd.http_port}"
      end
      @discovery = Nsq::Discovery.new(@lookupds)
    end

    it '#nsqds: finds all nsqds' do
      nsqds = @discovery.nsqds_for_topic(@topic)
      expected_nsqds = @cluster.nsqd.map { |d| "#{d.host}:#{d.tcp_port}" }
      expect(nsqds.sort).to eq(expected_nsqds.sort)
      expect(nsqds.length).to eq(@nsqd_count)
    end
  end


  describe 'multiple nsqlookupds, but one is down' do
    before do
      @lookupds = @cluster.nsqlookupd.map do |lookupd|
        "#{lookupd.host}:#{lookupd.http_port}"
      end
      @downed_nsqlookupd = @cluster.nsqlookupd.first
      @downed_nsqlookupd.stop
      @discovery = Nsq::Discovery.new(@lookupds)
    end

    after do
      @downed_nsqlookupd.start
    end

    it '#nsqds: finds all nsqds' do
      nsqds = @discovery.nsqds_for_topic(@topic)
      expected_nsqds = @cluster.nsqd.map { |d| "#{d.host}:#{d.tcp_port}" }
      expect(nsqds.sort).to eq(expected_nsqds.sort)
      expect(nsqds.length).to eq(@nsqd_count)
    end

  end

end
