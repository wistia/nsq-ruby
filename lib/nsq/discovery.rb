require 'json'
require 'net/http'
require 'uri'

require_relative 'logger'

# Connects to nsqlookup's to find the nsqd instances for a given topic
module Nsq
  class Discovery
    include Nsq::AttributeLogger

    # lookupd addresses must be formatted like so: '<host>:<http-port>'
    def initialize(lookupds)
      @lookupds = lookupds
    end

    # Returns an array of nsqds instances
    #
    # nsqd instances returned are strings in this format: '<host>:<tcp-port>'
    #
    #     discovery.nsqds
    #     #=> ['127.0.0.1:4150', '127.0.0.1:4152']
    #
    # If all nsqlookupd's are unreachable, raises Nsq::DiscoveryException
    #
    def nsqds
      gather_nsqds_from_all_lookupds do |lookupd|
        get_nsqds(lookupd)
      end
    end

    # Returns an array of nsqds instances that have messages for
    # that topic.
    #
    # nsqd instances returned are strings in this format: '<host>:<tcp-port>'
    #
    #     discovery.nsqds_for_topic('a-topic')
    #     #=> ['127.0.0.1:4150', '127.0.0.1:4152']
    #
    # If all nsqlookupd's are unreachable, raises Nsq::DiscoveryException
    #
    def nsqds_for_topic(topic)
      gather_nsqds_from_all_lookupds do |lookupd|
        get_nsqds(lookupd, topic)
      end
    end


    private

    def gather_nsqds_from_all_lookupds
      nsqd_list = @lookupds.map do |lookupd|
        yield(lookupd)
      end.flatten

      # All nsqlookupds were unreachable, raise an error!
      if nsqd_list.length > 0 && nsqd_list.all? { |nsqd| nsqd.nil? }
        raise DiscoveryException
      end

      nsqd_list.compact.uniq
    end

    # Returns an array of nsqd addresses
    # If there's an error, return nil
    def get_nsqds(lookupd, topic = nil)
      uri_scheme = 'http://' unless lookupd.match(%r(https?://))
      uri = URI.parse("#{uri_scheme}#{lookupd}")

      uri.query = "ts=#{Time.now.to_i}"
      if topic
        uri.path = '/lookup'
        uri.query += "&topic=#{URI.escape(topic)}"
      else
        uri.path = '/nodes'
      end

      begin
        body = Net::HTTP.get(uri)
        data = JSON.parse(body)
        producers = data['producers'] || # v1.0.0-compat
                      (data['data'] && data['data']['producers'])

        if producers
          producers.map do |producer|
            "#{producer['broadcast_address']}:#{producer['tcp_port']}"
          end
        else
          []
        end
      rescue Exception => e
        error "Error during discovery for #{lookupd}: #{e}"
        nil
      end
    end

  end
end
