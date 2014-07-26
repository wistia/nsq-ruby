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
  - need a way to know so combine can throw 500s
  - unicode messages
  - assert valid topic and channel names

- feature
  - should we take messages out of the queue when a connection dies?

- code
  - make identify take data and call the thing that generates the data?

- api
  - should we have a nicer api instead of: consumer.messages.pop?
  - consumer.queue_size
  - consumer.next_message

- questions
  - is it possible to be in a state of complete brokeness without knowing it ...
    i.e. your connections are all dead and not coming back

- tune up README

# Best practices for the producer

The producer will automatically try to reconnect itself and send any messages
that were not transmitted. As such, it won't give you an error when you are
sending messages.

You'll likely want a load balancer in front of your collectors that are running
this code. Make a health check that checks for `Producer#connected?` and returns
a 500 if the producer is not connected. This way you can route traffic to your
healthy nsqds and minimize message loss.


