```Ruby
require 'nsq'
producer = Nsq::Producer.new(topic: 'some-topic')

# write a message to NSQ
producer.write('some-message')

# write a bunch of messages to NSQ
producer.write('one', 'two', 'three', 'four', 'five')
```

```Ruby
require 'nsq'
consumer = Nsq::Consumer.new(
  topic: 'some-topic',
  channel: 'some-channel'
)

# the number of messages in the local queue
consumer.size

# pop the next message in the queue
msg = consumer.pop
puts msg.body
msg.finish
```


# Requirements

NSQ v0.2.28 or later (due to IDENTITY metadata specification)


# TODO

- test
  - assert valid topic and channel names

- feature
  - should we take messages out of the queue when a connection dies?

- tune up README
  - configuration options for consumer + producer
  - how the code is structured
  - what's supported what's not
  - link to krakow
  - link to nsq-cluster


# Best practices for the producer

The producer will automatically try to reconnect itself and send any messages
that were not transmitted. As such, it won't give you an error when you are
sending messages.

You'll likely want a load balancer in front of your collectors that are running
this code. Make a health check that checks for `Producer#connected?` and returns
a 500 if the producer is not connected. This way you can route traffic to your
healthy nsqds and minimize message loss.


