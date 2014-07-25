```Ruby
require 'nsq'
producer = Nsq::Producer.new(topic: 'some-topic')
producer.write('some-message')
```

```Ruby
require 'nsq'
consumer = Nsq::Consumer.new(
  topic: 'some-topic',
  channel: 'some-channel'
)
message = consumer.messages.pop
message.finish
```

# Structure

Consumer
Discovery
Connection

# Requirements

NSQ v0.2.28 or later (due to IDENTITY metadata specification)


# TODO

- test
  - requeue
  - touch

- feature
  - should we take messages out of the queue when a connection dies?
  - mechanism to write and wait for ok response (for connecting and subscribing?)

- health
  - kill consumer_connection in favor of one queue

- api
  - should we have a nicer api instead of: consumer.messages.pop?
  - consumer.queue_size
  - consumer.next_message

