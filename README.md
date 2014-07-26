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
  - what happens when you connect to nsqlookupd instead of nsqd?

- feature
  - should consumer and producer raise an error on construction when they fail to connect?
  - should we take messages out of the queue when a connection dies?
  - mechanism to write and wait for ok response (for connecting and subscribing?)

- api
  - should we have a nicer api instead of: consumer.messages.pop?
  - consumer.queue_size
  - consumer.next_message

- questions
  - is it possible to be in a state of complete brokeness without knowing it ...
    i.e. your connections are all dead and not coming back

- tune up README
