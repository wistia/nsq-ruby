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



# TODO

- lookupd discovery
- connections dropping and exploding in weird ways
- actually issue CLS to connections in a nice way
- If you req, touch, or fin a message that's already timed out -- it should explode? maybe raise an error.
- identify and feature negotiation
- rip out celluloid???
