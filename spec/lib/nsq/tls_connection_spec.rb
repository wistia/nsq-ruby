require_relative '../../spec_helper'

describe Nsq::Connection do
  def message_count(topic)
    topics_info = JSON.parse(@nsqd.stats.body)['data']['topics']
    topic_info = topics_info.select{|t| t['topic_name'] == topic }.first
    if topic_info
      topic_info['message_count']
    else
      0
    end
  end

  before do
    nsqd_options = {
      tls_key: tls_certs[:server_key],
      tls_cert: tls_certs[:server_cert],
      tls_root_ca_file: tls_certs[:ca_cert],
      tls_min_version: 'tls1.2',
    }

    @cluster = NsqCluster.new(nsqd_count: 1,
                              nsqlookupd_count: 1,
                              nsqd_options: nsqd_options)

    @nsqd = @cluster.nsqd.first
  end

  after do
    @cluster.destroy
  end

  describe 'when using a full tls context' do
    %w(tls_options ssl_context).map(&:to_sym).each do |tls_options_key|
      it 'can write a message onto the queue and read it back off again' do
        params = {
          tls_v1: true
        }
        params[tls_options_key] = tls_options_fixture

        producer = new_producer(@nsqd, params)
        topic = producer.topic
        producer.write('some-tls-message')
        wait_for { message_count(topic) == 1 }
        expect(message_count(topic)).to eq(1)

        consumer = new_consumer(params)
        msg = consumer.pop
        expect(msg.body).to eq('some-tls-message')
        msg.finish

        expect(msg.connection.instance_variable_get(:@socket)).
          to be_instance_of(OpenSSL::SSL::SSLSocket)

        producer.terminate
        consumer.terminate
      end
    end
  end

  describe 'when using a simple tls connection' do
    it 'can write a message onto the queue and read it back off again' do
      producer = new_producer(@nsqd, tls_v1: true)
      topic = producer.topic
      producer.write('some-tls-message')
      wait_for { message_count(topic) == 1 }
      expect(message_count(topic)).to eq(1)

      consumer = new_consumer(tls_v1: true)
      msg = consumer.pop
      expect(msg.body).to eq('some-tls-message')
      msg.finish

      expect(msg.connection.instance_variable_get(:@socket)).
        to be_instance_of(OpenSSL::SSL::SSLSocket)

      producer.terminate
      consumer.terminate
    end
  end


  describe 'tls usage' do
    %w(tls_options ssl_context).map(&:to_sym).each do |tls_options_key|
      it 'tls is used when tls_v1 is true and @tls_options provided' do
        params = {
          host: @nsqd.host,
          port: @nsqd.tcp_port,
          tls_v1: true
        }
        params[tls_options_key] = tls_options_fixture

        conn = Nsq::Connection.new(params)
        expect(conn.instance_variable_get(:@socket)).
          to be_an_instance_of(OpenSSL::SSL::SSLSocket)
        conn.close
      end
      it 'tls not used when tls_v1 is false and @tls_options provided' do
        params = {
          host: @nsqd.host,
          port: @nsqd.tcp_port,
          tls_v1: false
        }
        params[tls_options_key] = tls_options_fixture

        conn = Nsq::Connection.new(params)
        expect(conn.instance_variable_get(:@socket)).
          to be_an_instance_of(TCPSocket)
        conn.close
      end
    end

    it 'tls is used when tls_v1 is true and no @tls_options provided' do
      params = {
        host: @nsqd.host,
        port: @nsqd.tcp_port,
        tls_v1: true
      }

      conn = Nsq::Connection.new(params)
      expect(conn.instance_variable_get(:@socket)).
        to be_an_instance_of(OpenSSL::SSL::SSLSocket)
      conn.close
    end

    it 'tls not used when tls_v1 is false and no @tls_options provided' do
      params = {
        host: @nsqd.host,
        port: @nsqd.tcp_port,
        tls_v1: false
      }

      conn = Nsq::Connection.new(params)
      expect(conn.instance_variable_get(:@socket)).
        to be_an_instance_of(TCPSocket)
      conn.close
    end
  end

end
