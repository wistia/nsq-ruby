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
    it 'can write a message onto the queue and read it back off again' do
      producer = new_producer(@nsqd, ssl_context: ssl_context)
      topic = producer.topic
      producer.write('some-tls-message')
      wait_for { message_count(topic) == 1 }
      expect(message_count(topic)).to eq(1)

      consumer = new_consumer(ssl_context: ssl_context)
      msg = consumer.pop
      expect(msg.body).to eq('some-tls-message')
      msg.finish

      expect(msg.connection.instance_variable_get(:@socket)).
        to be_instance_of(OpenSSL::SSL::SSLSocket)

      producer.terminate
      consumer.terminate
    end
  end

  describe 'when using a simple tls connection' do
    it 'can write a message onto the queue and read it back off again' do
      producer = new_producer(@nsqd, ssl: true)
      topic = producer.topic
      producer.write('some-tls-message')
      wait_for { message_count(topic) == 1 }
      expect(message_count(topic)).to eq(1)

      consumer = new_consumer(ssl: true)
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
