require_relative 'discovery'
require_relative 'connection'
require_relative 'logger'

module Nsq
  class ClientBase
    include Nsq::AttributeLogger
    @@log_attributes = [:topic]

    attr_reader :topic
    attr_reader :connections

    def connected?
      @connections.values.any?(&:connected?)
    end


    def terminate
      @discovery_thread.kill if @discovery_thread
      drop_all_connections
    end


    private

    # discovers nsqds from an nsqlookupd repeatedly
    #
    #   opts:
    #     nsqlookups: ['127.0.0.1:4161'],
    #     topic: 'topic-to-find-nsqds-for',
    #     interval: 60
    #
    def discover_repeatedly(opts = {})
      @discovery_thread = Thread.new do

        @discovery = Discovery.new(opts[:nsqlookupds])

        loop do
          begin
            nsqds = nsqds_from_lookupd(opts[:topic])
            drop_and_add_connections(nsqds)
          rescue DiscoveryException
            # We can't connect to any nsqlookupds. That's okay, we'll just
            # leave our current nsqd connections alone and try again later.
            warn 'Could not connect to any nsqlookupd instances in discovery loop'
          end
          sleep opts[:interval]
        end

      end

      @discovery_thread.abort_on_exception = true
    end


    def nsqds_from_lookupd(topic = nil)
      if topic
        @discovery.nsqds_for_topic(topic)
      else
        @discovery.nsqds
      end
    end


    def drop_and_add_connections(nsqds)
      # drop nsqd connections that are no longer in lookupd
      missing_nsqds = @connections.keys - nsqds
      missing_nsqds.each do |nsqd|
        drop_connection(nsqd)
      end

      # add new ones
      new_nsqds = nsqds - @connections.keys
      new_nsqds.each do |nsqd|
        begin
          add_connection(nsqd)
        rescue Exception => ex
          error "Failed to connect to nsqd @ #{nsqd}: #{ex}"
        end
      end

      # balance RDY state amongst the connections
      connections_changed
    end


    def add_connection(nsqd, options = {})
      info "+ Adding connection #{nsqd}"
      host, port = nsqd.split(':')
      connection = Connection.new({
        host: host,
        port: port,
        ssl_context: @ssl_context,
        tls_options: @tls_options,
        tls_v1: @tls_v1
      }.merge(options))
      @connections[nsqd] = connection
    end


    def drop_connection(nsqd)
      info "- Dropping connection #{nsqd}"
      connection = @connections.delete(nsqd)
      connection.close if connection
      connections_changed
    end


    def drop_all_connections
      @connections.keys.each do |nsqd|
        drop_connection(nsqd)
      end
    end


    # optional subclass hook
    def connections_changed
    end
  end
end
