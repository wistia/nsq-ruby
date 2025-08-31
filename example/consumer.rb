
require "nsq"


consumer = Nsq::Consumer.new(
  nsqlookupd: "127.0.0.1:4161",
  topic: "hello",
  channel: "test"
)


loop do
  msg = consumer.pop_without_blocking
  next if msg.nil?

  puts "message: #{msg.body}"
  msg.finish
end



