module TlsSpecHelpers
  def tls_file(cert_name)
    "#{File.dirname(__FILE__)}/tls_certs/#{cert_name.to_s}.pem"
  end

  def tls_certs
    @tls_certs ||= {
      client_cert: tls_file('nsq-client-cert'),
      client_key:  tls_file('nsq-client-key'),
      ca_cert:     tls_file('nsq-ca-cert'),
      server_cert: tls_file('nsq-server-cert'),
      server_key:  tls_file('nsq-server-key'),
    }
  end

  def ssl_context
    {
      key: tls_certs[:client_key],
      certificate: tls_certs[:client_cert],
      ca_certificate: tls_certs[:ca_cert]
    }
  end
end

RSpec.configure do |config|
  config.include TlsSpecHelpers
end
