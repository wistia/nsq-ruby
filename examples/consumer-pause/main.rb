#!/usr/bin/env ruby

lib = File.expand_path("../../../lib", __FILE__)
$:.unshift(lib)

require 'nsq'
require 'logger'

logger = Logger.new STDOUT

consumer = Nsq::Consumer.new(
  topic: 'test-pause',
  channel: 'default',
  max_in_flight: 2,
)

2.times do |i|
  Thread.new {
    loop do
      msg = consumer.pop
      puts "#{i} MSG #{msg.id}: #{msg.body}"
      sleep 2
      msg.finish
    end
  }
end

producer = Nsq::Producer.new(
  topic: 'test-pause',
)

producer.write Time.now
producer.write Time.now
producer.write Time.now
producer.write Time.now

logger.info "pausing consumer"
consumer.pause
logger.info "consumer paused"

producer.write Time.now
producer.write Time.now

sleep 5

logger.info "resuming consumer"
consumer.resume
logger.info "consumer resumed"

sleep 5
