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

    # Given a topic, returns an array of nsqds instances that have messages for
    # that topic.
    #
    # nsqd instances returned are strings in this format: '<host>:<tcp-port>'
    #
    #     discovery.nsqds_for_topic('some-topic')
    #     #=> ['127.0.0.1:4150', '127.0.0.1:4152']
    #
    def nsqds_for_topic(topic)
      @lookupds.map do |lookupd|
        get_nsqds_for_topic(lookupd, topic)
      end.flatten.uniq
    end


    private

    def get_nsqds_for_topic(lookupd, topic)
      uri = URI.parse("http://#{lookupd}")
      uri.path = '/lookup'
      uri.query = "topic=#{topic}&ts=#{Time.now.to_i}"
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
      rescue => e
        #TODO: log this!
        []
      end
    end

  end
end
