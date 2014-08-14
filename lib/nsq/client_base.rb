module Nsq
  class ClientBase

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
    #     discover_by_topic: true
    #
    def discover_repeatedly(opts = {})
      @discovery_thread = Thread.new do
        loop do
          discover opts
          sleep @discovery_interval
        end
      end
      @discovery_thread.abort_on_exception = true
    end


    def discover(opts)
      nsqds = nil
      if opts[:discover_by_topic]
        nsqds = @discovery.nsqds_for_topic(@topic)
      else
        nsqds = @discovery.nsqds
      end

      # drop nsqd connections that are no longer in lookupd
      missing_nsqds = @connections.keys - nsqds
      missing_nsqds.each do |nsqd|
        drop_connection(nsqd)
      end

      # add new ones
      new_nsqds = nsqds - @connections.keys
      new_nsqds.each do |nsqd|
        add_connection(nsqd)
      end

      # balance RDY state amongst the connections
      connections_changed
    end


    def add_connection(nsqd)
      info "+ Adding connection #{nsqd}"
      host, port = nsqd.split(':')
      connection = Connection.new(
        host: host,
        port: port
      )
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
