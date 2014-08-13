# nsq-ruby

nsq-ruby is a simple NSQ client library written in Ruby.

- The code is straightforward.
- It has no dependencies.
- It's well tested.


## Quick start

### Publish messages

```Ruby
require 'nsq'
producer = Nsq::Producer.new(
  nsqd: '127.0.0.1:4150',
  topic: 'some-topic'
)

# Write a message to NSQ
producer.write('some-message')

# Write a bunch of messages to NSQ (uses mpub)
producer.write('one', 'two', 'three', 'four', 'five')

# Close the connection
producer.terminate
```

### Consume messages

```Ruby
require 'nsq'
consumer = Nsq::Consumer.new(
  nsqlookupd: '127.0.0.1:4161',
  topic: 'some-topic',
  channel: 'some-channel'
)

# Pop a message off the queue
msg = consumer.pop
puts msg.body
msg.finish

# Close the connections
consumer.terminate
```


## Producer

### Initialization

The Nsq::Producer constructor takes the following options:

| Option        | Description                            | Default            |
|---------------|----------------------------------------|--------------------|
| `topic`       | Topic to which to publish messages     |                    |
| `nsqd`        | Host and port of the nsqd instance     | '127.0.0.1:4150'   |

For example:

```Ruby
producer = Nsq::Producer.new(
  nsqd: '6.7.8.9:4150',
  topic: 'topic-of-great-esteem'
)
```

### `#write`

Publishes one or more message to nsqd. If you give it a single argument, it will
send it to nsqd via `PUB`. If you give it multiple arguments, it will send all
those messages to nsqd via `MPUB`. It will automatically call `to_s` on any
arguments you give it.

```Ruby
# Send a single message via PUB
producer.write(123)

# Send three messages via MPUB
producer.write(456, 'another-message', { key: 'value' }.to_json)
```

If it's connection to nsqd fails, it will automatically try to reconnect with
exponential backoff. Any messages that were sent to `#write` will be queued
and transmitted after reconnecting.

**Note** we don't wait for nsqd to acknowledge our writes. As a result, if the
connection to nsqd fails, you can lose messages. This is acceptable for our use
cases, mostly because we are sending messages to a local nsqd instance and
failure is very rare.

### `#connected?`

Returns true if it's currently connected to nsqd and false if not.

### `#terminate`

Closes the connection to nsqd and stops it from trying to automatically
reconnect.

This is automatically called `at_exit`, but it's good practice to close your
producers when you're done with them.


## Consumer

### Initialization

| Option               | Description                                   | Default            |
|----------------------|-----------------------------------------------|--------------------|
| `topic`              | Topic to consume messages from                |                    |
| `channel`            | Channel name for this consumer                |                    |
| `nsqlookupd`         | Use lookupd to automatically discover nsqds   |                    |
| `nsqd`               | Connect directly to a single nsqd instance    | '127.0.0.1:4150'   |
| `max_in_flight`      | Max number of messages for this consumer to have in flight at a time   | 1 |
| `discovery_interval` | Seconds between queue discovery via nsqlookupd    | 60.0   |
| `msg_timeout`        | Milliseconds before nsqd will timeout a message   | 60000  |


For example:

```Ruby
consumer = Nsq::Consumer.new(
  topic: 'the-topic',
  channel: 'my-channel',
  nsqlookupd: ['127.0.0.1:4161', '4.5.6.7:4161'],
  max_in_flight: 100,
  discovery_interval: 30,
  msq_timeout: 120_000
)
```

Notes:

- `nsqlookupd` can be a string or array of strings for each nsqlookupd service
  you'd like to use. The format is `"<host>:<http-port>"`. If you specify
  `nsqlookupd`, it ignores the `nsqd` option.
- `max_in_flight` is for the total max in flight across all the connections,
  but to make the implementation of `nsq-ruby` as simple as possible, the minimum
  `max_in_flight` _per_ connection is 1. So if you set `max_in_flight` to 1 and
  are connected to 3 nsqds, you may have up to 3 messages in flight at a time.


### `#pop`

`nsq-ruby` works by maintaining a local queue of in flight messages from NSQ.
To get at these messages, just call pop.

```Ruby
message = consumer.pop
```

If there are messages on the queue, `pop` will return one immediately. If there
are no messages on the queue, `pop` will block execution until one arrives.


### `#size`

`size` returns the size of the local message queue.


### `#terminate`

Gracefully closes all connections and stops the consumer. You should call this
when you're finished with a consumer object.


## Message

The `Message` object is what you get when you call `pop` on a consumer.
Once you have a message, you'll likely want to get its contents using the `#body`
method, and then call `#finish` once you're done with it.

### `body`

Returns the body of the message as a UTF-8 encoded string.

### `attempts`

Returns the number of times this message was attempted to be processed. For
most messages this should be 1 (since it will be your first attempt processing
them). If it's more than 1, that means that you requeued the message or it
timed out in flight.

### `#finish`

Notify NSQ that you've completed processing of this message.

### `#touch`

Tells NSQ to reset the message timeout for this message so you have more time
to process it.

### `#requeue(timeout = 0)`

Tells NSQ to requeue this message. Called with no arguments, this will requeue
the message and it will be available to be received immediately.

Optionally you can pass a number of milliseconds as an argument. This tells
NSQ to delay its requeueing by that number of milliseconds.


## Logging

By default, `nsq-ruby` doesn't log anything. To enable logging, use
`Nsq.logger=` and point it at a Ruby Logger instance. Like this:

```Ruby
Nsq.logger = Logger.new(STDOUT)
```


## Requirements

NSQ v0.2.29 or later due for IDENTITY metadata specification (0.2.28) and per-
connection timeout support (0.2.29).


### Supports

- Discovery via nsqlookupd
- Automatic reconnection to nsqd

### Does not support

- TLS
- Compression
- Backoff
- Authentication

If you need more advanced features, like these, you should check out
[Krakow](https://github.com/chrisroberts/krakow), a more fully featured NSQ
client for Ruby.


## Testing

Run the tests like this:

```
rake spec
```

Want a deluge of logging while running the specs to help determine what is
going on?

```
VERBOSE=true rake spec
```


## MIT License

Copyright (C) 2014 Wistia, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

