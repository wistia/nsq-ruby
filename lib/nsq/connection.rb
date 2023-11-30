require 'json'
require 'socket'
require 'openssl'
require 'timeout'

require_relative 'retry'
require_relative 'exceptions'
require_relative 'frames/error'
require_relative 'frames/message'
require_relative 'frames/response'
require_relative 'selectable_queue'
require_relative 'logger'

module Nsq
  class Connection
    include Nsq::AttributeLogger
    @@log_attributes = [:host, :port]

    attr_reader :host
    attr_reader :port
    attr_accessor :max_in_flight
    attr_reader :presumed_in_flight

    USER_AGENT = "nsq-ruby/#{Nsq::Version::STRING}"
    RESPONSE_HEARTBEAT = '_heartbeat_'
    RESPONSE_OK = 'OK'


    def initialize(opts = {})
      @host = opts[:host] || (raise ArgumentError, 'host is required')
      @port = opts[:port] || (raise ArgumentError, 'port is required')
      @response_queue = opts[:response_queue]
      @queue = opts[:queue]
      @topic = opts[:topic]
      @channel = opts[:channel]
      @msg_timeout = opts[:msg_timeout] || 60_000 # 60s
      @max_in_flight = opts[:max_in_flight] || 1
      @tls_options = opts[:tls_options]
      @max_attempts = opts[:max_attempts]
      if opts[:ssl_context]
        if @tls_options
          warn 'ssl_context and tls_options both set. Using tls_options. Ignoring ssl_context.'
        else
          @tls_options = opts[:ssl_context]
          warn 'ssl_context will be deprecated nsq-ruby version 3. Please use tls_options instead.'
        end
      end
      @tls_v1 = !!opts[:tls_v1]

      if @tls_options
        if @tls_v1
          validate_tls_options!
        else
          warn 'tls_options was provided, but tls_v1 is false. Skipping validation of tls_options.'
        end
      end

      if @msg_timeout < 1000
        raise ArgumentError, 'msg_timeout cannot be less than 1000. it\'s in milliseconds.'
      end

      # for outgoing communication
      @write_queue = SelectableQueue.new(10000)

      # For indicating that the connection has died.
      # We use a Queue so we don't have to poll. Used to communicate across
      # threads (from read_write_loop to connect_and_monitor).
      @death_queue = Queue.new

      @connected = false
      @presumed_in_flight = 0

      open_connection
      start_monitoring_connection
    end


    def connected?
      @connected
    end


    # close the connection and don't try to re-open it
    def close
      stop_monitoring_connection
      close_connection
    end


    def rdy(count)
      write "RDY #{count}\n"
    end


    def fin(message_id)
      write "FIN #{message_id}\n"
      decrement_in_flight
    end


    def req(message_id, timeout)
      write "REQ #{message_id} #{timeout}\n"
      decrement_in_flight
    end


    def touch(message_id)
      write "TOUCH #{message_id}\n"
    end


    def pub(topic, message)
      write ["PUB #{topic}\n", message.bytesize, message].pack('a*l>a*')
    end

    def dpub(topic, delay_in_ms, message)
      write ["DPUB #{topic} #{delay_in_ms}\n", message.bytesize, message].pack('a*l>a*')
    end

    def mpub(topic, messages)
      body = messages.map do |message|
        [message.bytesize, message].pack('l>a*')
      end.join

      write ["MPUB #{topic}\n", body.bytesize, messages.size, body].pack('a*l>l>a*')
    end


    # Tell the server we are ready for more messages!
    def re_up_ready
      rdy(@max_in_flight)
      # assume these messages are coming our way. yes, this might not be the
      # case, but it's much easier to manage our RDY state with the server if
      # we treat things this way.
      @presumed_in_flight = @max_in_flight
    end


    private

    def sub(topic, channel)
      write_to_socket "SUB #{topic} #{channel}\n"
    end

    def cls
      write "CLS\n"
    end


    def nop
      write "NOP\n"
    end


    def write(raw)
      @write_queue.push(message: raw)
    end

    def write_to_socket(raw)
      debug ">>> #{raw.inspect}"
      @socket.write(raw)
    end

    def identify
      hostname = Socket.gethostname
      metadata = {
        client_id: hostname,
        hostname: hostname,
        feature_negotiation: true,
        heartbeat_interval: 30_000, # 30 seconds
        output_buffer: 16_000, # 16kb
        output_buffer_timeout: 250, # 250ms
        tls_v1: @tls_v1,
        snappy: false,
        deflate: false,
        sample_rate: 0, # disable sampling
        user_agent: USER_AGENT,
        msg_timeout: @msg_timeout
      }.to_json
      write_to_socket ["IDENTIFY\n", metadata.length, metadata].pack('a*l>a*')

      # Now wait for the response!
      frame = receive_frame
      server = JSON.parse(frame.data)

      if @max_in_flight > server['max_rdy_count']
        raise "max_in_flight is set to #{@max_in_flight}, server only supports #{server['max_rdy_count']}"
      end

      @server_version = server['version']
    end


    def handle_response(frame)
      if frame.data == RESPONSE_HEARTBEAT
        debug 'Received heartbeat'
        nop
      elsif frame.data == RESPONSE_OK
        @response_queue.push(frame) if @response_queue
        debug 'Received OK'
      else
        die "Received response we don't know how to handle: #{frame.data}"
      end
    end

    def handle_error(frame)
      if @response_queue
        @response_queue.push(frame)
      else
        error "Error received: #{frame.data}"
      end
    end

    def receive_frame
      if buffer = @socket.read(8)
        size, type = buffer.unpack('l>l>')
        size -= 4 # we want the size of the data part and type already took up 4 bytes
        data = @socket.read(size)
        frame_class = frame_class_for_type(type)
        return frame_class.new(data, self)
      end
    end

    FRAME_CLASSES = [Response, Error, Message]
    def frame_class_for_type(type)
      raise "Bad frame type specified: #{type}" if type > FRAME_CLASSES.length - 1
      [Response, Error, Message][type]
    end


    def decrement_in_flight
      @presumed_in_flight -= 1

      if server_needs_rdy_re_ups?
        # now that we're less than @max_in_flight we might need to re-up our RDY state
        threshold = (@max_in_flight * 0.2).ceil
        re_up_ready if @presumed_in_flight <= threshold
      end
    end


    def start_read_write_loop
      @read_write_loop_thread ||= Thread.new{read_write_loop}
    end


    def stop_read_write_loop
      # if the loop has died because of a connection error, the thread is
      # already stopped, otherwise we want to terminate the producer connection
      # and a custom-made message is sent signaling to the loop to stop
      # gracefully
      if @read_write_loop_thread
        @write_queue.push(message: :stop_loop) if @read_write_loop_thread.alive?
        @read_write_loop_thread.join
        @read_write_loop_thread = nil
      end
    end

    def read_write_loop
      loop do
        begin
          ready, _, _ = IO.select([@socket, @write_queue])

          if ready.include?(@socket)
            frame = receive_frame
            if frame.is_a?(Response)
              handle_response(frame)
            elsif frame.is_a?(Error)
              handle_error(frame)
            elsif frame.is_a?(Message)
              debug "<<< #{frame.body}"
              if @max_attempts && frame.attempts > @max_attempts
                fin(frame.id)
              else
                @queue.push(frame) if @queue
              end
            else
              die(UnexpectedFrameError.new(frame))
            end
          end

          if ready.include?(@write_queue)
            data = @write_queue.pop
            return if data[:message] == :stop_loop
            write_to_socket(data[:message])
          end
        rescue IO::WaitReadable
          retry
        end
      end
    rescue Exception => ex
      die(ex)
    end

    # Waits for death of connection
    def start_monitoring_connection
      @connection_monitor_thread ||= Thread.new{monitor_connection}
      @connection_monitor_thread.abort_on_exception = true
    end


    def stop_monitoring_connection
      @connection_monitor_thread.kill if @connection_monitor_thread
      @connection_monitor = nil
    end

    def monitor_connection
      loop do
        # wait for death, hopefully it never comes
        cause_of_death = @death_queue.pop
        warn "Died from: #{cause_of_death}"

        debug 'Reconnecting...'
        reconnect(cause_of_death)
        debug 'Reconnected!'

        # clear all death messages, since we're now reconnected.
        # we don't want to complete this loop and immediately reconnect again.
        @death_queue.clear
      end
    end


    # close the connection if it's not already closed and try to reconnect
    # over and over until we succeed!
    def reconnect(cause_of_death)
      close_connection
      Nsq::with_retries do
        # If a synchronous producer received messages during the reconnection
        # period those messages must fail if they expect an acknowledgement
        # Between each reconnection attempt, we ensure the `connection.write`
        # are not blocked by returning the exception which lead to the initial
        # disconnection.
        push_error_pending_writes cause_of_death if @response_queue
        open_connection
      end
    end

    def push_error_pending_writes cause_of_death
      while !@write_queue.empty?
        data = @write_queue.pop
        @response_queue.push(cause_of_death) if @response_queue
      end
    end

    def open_connection
      @socket = TCPSocket.new(@host, @port)
      # write the version and IDENTIFY directly to the socket to make sure
      # it gets to nsqd ahead of anything in the `@write_queue`
      write_to_socket '  V2'
      identify
      upgrade_to_ssl_socket if @tls_v1

      @connected = true

      # we need to re-subscribe if there's a topic specified
      if @topic
        debug "Subscribing to #{@topic}"
        sub(@topic, @channel)
        frame = receive_frame
        raise ErrorFrameException(frame.data) if frame.is_a?(Error)
        re_up_ready
      end

      start_read_write_loop
    end


    # closes the connection and stops listening for messages
    def close_connection
      cls if connected?
      stop_read_write_loop
      @socket.close if @socket
      @socket = nil
      @connected = false
    end


    # this is called when there's a connection error in the read or write loop
    # it triggers `connect_and_monitor` to try to reconnect
    def die(reason)
      @connected = false
      @death_queue.push(reason)
    end


    def upgrade_to_ssl_socket
      ssl_opts = [@socket, openssl_context].compact
      @socket = OpenSSL::SSL::SSLSocket.new(*ssl_opts)
      @socket.sync_close = true
      @socket.connect
    end


    def openssl_context
      return unless @tls_options

      context = OpenSSL::SSL::SSLContext.new
      context.cert = OpenSSL::X509::Certificate.new(File.read(@tls_options[:certificate]))
      context.key = OpenSSL::PKey::RSA.new(File.read(@tls_options[:key]))
      if @tls_options[:ca_certificate]
        context.ca_file = @tls_options[:ca_certificate]
      end
      context.verify_mode = @tls_options[:verify_mode] || OpenSSL::SSL::VERIFY_NONE
      context
    end

    def server_needs_rdy_re_ups?
      # versions less than 0.3.0 need RDY re-ups
      # see: https://github.com/bitly/nsq/blob/master/ChangeLog.md#030---2014-11-18
      major, minor = @server_version.split('.').map(&:to_i)
      major == 0 && minor <= 2
    end


    def validate_tls_options!
      [:key, :certificate].each do |key|
        unless @tls_options.has_key?(key)
          raise ArgumentError.new "@tls_options requires a :#{key}"
        end
      end

      [:key, :certificate, :ca_certificate].each do |key|
        if @tls_options[key] && !File.readable?(@tls_options[key])
          raise LoadError.new "@tls_options :#{key} is unreadable"
        end
      end
    end
  end
end
