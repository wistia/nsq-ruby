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
    def nsqds
      @lookupds.map do |lookupd|
        get_nsqds(lookupd)
      end.flatten.uniq
    end

    # Returns an array of nsqds instances that have messages for
    # that topic.
    #
    # nsqd instances returned are strings in this format: '<host>:<tcp-port>'
    #
    #     discovery.nsqds_for_topic('a-topic')
    #     #=> ['127.0.0.1:4150', '127.0.0.1:4152']
    #
    def nsqds_for_topic(topic)
      @lookupds.map do |lookupd|
        get_nsqds(lookupd, topic)
      end.flatten.uniq
    end

    private

    def get_nsqds(lookupd, topic = nil)
      uri_scheme = 'http://' unless lookupd.match(%r(https?://))
      uri = URI.parse("#{uri_scheme}#{lookupd}")

      uri.query = "ts=#{Time.now.to_i}"
      if topic
        uri.path = '/lookup'
        uri.query += "&topic=#{topic}"
      else
        uri.path = '/nodes'
      end

      begin
        body = Net::HTTP.get(uri)
        data = JSON.parse(body)

        if data['data'] && data['data']['producers']
          data['data']['producers'].map do |producer|
            "#{producer['broadcast_address']}:#{producer['tcp_port']}"
          end
        else
          []
        end
      rescue Exception => e
        error "Error during discovery for #{lookupd}: #{e}"
        []
      end
    end

  end
end
