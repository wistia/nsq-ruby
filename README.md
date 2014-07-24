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

- test connections dropping and exploding in weird ways
- If you req, touch, or fin a message that's already timed out -- it should explode? maybe raise an error.
- add logging
- mechanism to write and wait for ok response (for connecting and subscribing?)
- test
  x connections can be added, removed by discovery
  - connections can be fail because of network or instance blipping
  - what happens when trying to start a connection to something that isn't responding

- gotchas
  - can't be assumed that if you pop a message that you'll be able to fin, req, touch it
    the connection might have gone away!
  - when a connection dies, should we remove those messages from the queue?

NOTE TO SELF ...
  Threading issues with the reconnect logic, when we fail while receiving, we
  kill the thread before it can reconnect. Reconnecting should be done in
  one thread only!
