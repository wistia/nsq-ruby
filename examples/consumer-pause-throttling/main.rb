#!/usr/bin/env ruby

# The goal of this example is the following
# It's not because the max_in_flight is set to 10
# that 10 jobs will be consumed at the same time, a queue can still appear.
#
# Setup :
# 3 nsqd 10.0.0.1/2/3
# with max_in_flight == 10
# Each connection will receive a max_in_flight of 3 (global max /
# number of connections) If only one nsqd receives messages, only
# 3 messages will be accepted by the consumer even if we accept a
# maximum of 10 in parallel.
#
# So using the pause/unpause mecanism, the goal is to be able to have
# max_in_flight 10 per connection
#
# When 10 messages are handled, stop accepting new message by
# pausing the consumer, until one slot gets free

lib = File.expand_path("../../../lib", __FILE__)
$:.unshift(lib)

require 'nsq'
require 'logger'

logger = Logger.new STDOUT

# PRE: start 3 nsqd registering to nsqlookupd
# nsqd -lookupd-tcp-address 127.0.0.1:4160 -broadcast-address nsqd1
# nsqd -http-address 0.0.0.0:4251 -tcp-address 0.0.0.0:4250 -lookupd-tcp-address 127.0.0.1:4160 -broadcast-address nsqd2.localhost
# nsqd -http-address 0.0.0.0:4351 -tcp-address 0.0.0.0:4350 -lookupd-tcp-address 127.0.0.1:4160 -broadcast-address nsqd3.localhost

# Produce one message each nsqd to have them known from nsqlookupd
logger.info "initializing topics on all nsqd"
Nsq::Producer.new(topic: 'test-pause-throttling', nsqd: '127.0.0.1:4150').write("nsqd1")
Nsq::Producer.new(topic: 'test-pause-throttling', nsqd: '127.0.0.1:4250').write("nsqd2")
Nsq::Producer.new(topic: 'test-pause-throttling', nsqd: '127.0.0.1:4350').write("nsqd3")

logger.info "creating consumer"
consumer = Nsq::Consumer.new(
  topic: 'test-pause-throttling',
  channel: 'default',
  max_in_flight: 30, nsqlookupds: ['http://localhost:4160'],
)

jobs_count_mutex = Mutex.new
jobs_count = 0
concurrency = 10

concurrency.times do |i|
  logger.info "create consumer thread #{i}"
  Thread.new {
    loop do
      msg = consumer.pop
      jobs_count_mutex.synchronize {
        jobs_count += 1
        logger.info "##{i} New msg, current amount: #{jobs_count}"
        if jobs_count == concurrency
          logger.info "pausing consumer"
          consumer.pause
          logger.info "consumer paused"
        end
      }
      puts "##{i} MSG #{msg.id}: #{msg.body}"

      # Long job
      sleep (Random.rand * 10).to_i

      msg.finish
      jobs_count_mutex.synchronize {
        jobs_count -= 1
        logger.info "##{i} Msg finished, current amount: #{jobs_count}"
        consumer.resume
      }
    end
  }
end

# Only producing to one nsqd instance
producer = Nsq::Producer.new( topic: 'test-pause-throttling', nsqd: '127.0.0.1:4150')

loop do
  producer.write Time.now
  sleep 0.2
end
