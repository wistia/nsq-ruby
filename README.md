# nsq-ruby

nsq-ruby is a simple NSQ client library written in Ruby.

- The code is straightforward.
- It has no dependencies.
- It's well tested.
- It's being used in production and has processed billions of messages.

[![Build Status](https://travis-ci.org/wistia/nsq-ruby.svg?branch=master)](https://travis-ci.org/wistia/nsq-ruby)


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

# Write a deferred message to NSQ (uses dpub)

# Message deferred of 10s
producer.deferred_write(10, 'one')

# Message deferred of 1250ms
producer.deferred_write(1.25, 'one')

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
| `nsqlookupd`  | Use lookupd to auto discover nsqds     |                    |
| `tls_v1`      | Flag for tls v1 connections            | false              |
| `tls_options` | Optional keys+certs for TLS connections|                    |

For example, if you'd like to publish messages to a single nsqd.

```Ruby
producer = Nsq::Producer.new(
  nsqd: '6.7.8.9:4150',
  topic: 'topic-of-great-esteem'
)
```

Alternatively, you can use nsqlookupd to find all nsqd nodes in the cluster.
When you instantiate Nsq::Producer in this way, it will automatically maintain
connections to all nsqd instances. When you publish a message, it will be sent
to a random nsqd instance.

```Ruby
producer = Nsq::Producer.new(
  nsqlookupd: ['1.2.3.4:4161', '6.7.8.9:4161'],
  topic: 'topic-of-great-esteem'
)
```

If you need to connect using SSL/TLS Authentication via `tls_options`

```Ruby
producer = Nsq::Producer.new(
  nsqlookupd: ['1.2.3.4:4161', '6.7.8.9:4161'],
  topic: 'topic-of-great-esteem',
  tls_v1: true,
  tls_options: {
    key: '/path/to/ssl/key.pem',
    certificate: '/path/to/ssl/certificate.pem',
    ca_certificate: '/path/to/ssl/ca_certificate.pem',
    verify_mode: OpenSSL::SSL::VERIFY_PEER
  }
)
```

If you need to connect using simple `tls_v1`

```Ruby
producer = Nsq::Producer.new(
  nsqlookupd: ['1.2.3.4:4161', '6.7.8.9:4161'],
  topic: 'topic-of-great-esteem',
  tls_v1: true
)
```

### `#write`

Publishes one or more messages to nsqd. If you give it a single argument, it will
send it to nsqd via `PUB`. If you give it multiple arguments, it will send all
those messages to nsqd via `MPUB`. It will automatically call `to_s` on any
arguments you give it.

```Ruby
# Send a single message via PUB
producer.write(123)

# Send three messages via MPUB
producer.write(456, 'another-message', { key: 'value' }.to_json)
```

If its connection to nsqd fails, it will automatically try to reconnect with
exponential backoff. Any messages that were sent to `#write` will be queued
and transmitted after reconnecting.

**Note:** Internally, we use a `SizedQueue` that can hold 10,000 messages. If you're
producing messages faster than we're able to send them to nsqd or nsqd is
offline for an extended period and you accumulate 10,000 messages in the queue,
calls to `#write` will block until there's room in the queue.

**Note:** We don't wait for nsqd to acknowledge our writes. As a result, if the
connection to nsqd fails, you can lose messages. This is acceptable for our use
cases, mostly because we are sending messages to a local nsqd instance and
failure is very rare.


### `#write_to_topic`

Publishes one or more messages to nsqd. Like `#write`, but allows you to specify
the topic. Use this method if you want a single producer instance to write to
multiple topics.

```Ruby
# Send a single message via PUB to the topic 'rutabega'
producer.write_to_topic('rutabega', 123)

# Send multiple messages via MPUB to the topic 'kohlrabi'
producer.write_to_topic('kohlrabi', 'a', 'b', 'c')
```


### `#connected?`

Returns true if it's currently connected to nsqd and false if not.

### `#terminate`

Closes the connection to nsqd and stops it from trying to automatically
reconnect.

This is automatically called `at_exit`, but it's good practice to close your
producers when you're done with them.

**Note:** This terminates the connection to NSQ immediately. If you're writing
messages faster than they can be sent to NSQ, you may have messages in the
producer's internal queue. Calling `#terminate` before they're sent will cause
these messages to be lost. After you write your last message, consider sleeping
for a second before you call `#terminate`.




## Consumer

### Initialization

| Option               | Description                                   | Default            |
|----------------------|-----------------------------------------------|--------------------|
| `topic`              | Topic to consume messages from                |                    |
| `channel`            | Channel name for this consumer                |                    |
| `nsqlookupd`         | Use lookupd to automatically discover nsqds   |                    |
| `nsqd`               | Connect directly to a single nsqd instance    | '127.0.0.1:4150'   |
| `max_in_flight`      | Max number of messages for this consumer to have in flight at a time   | 1 |
| `discovery_interval` | Seconds between queue discovery via nsqlookupd    | 60.0           |
| `msg_timeout`        | Milliseconds before nsqd will timeout a message   | 60000          |
| `max_attempts`       | Number of times a message will be attempted before being finished |  |
| `tls_v1`             | Flag for tls v1 connections                   | false              |
| `tls_options`        | Optional keys and certificates for TLS connections |               |


For example:

```Ruby
consumer = Nsq::Consumer.new(
  topic: 'the-topic',
  channel: 'my-channel',
  nsqlookupd: ['127.0.0.1:4161', '4.5.6.7:4161'],
  max_in_flight: 100,
  discovery_interval: 30,
  msg_timeout: 120_000,
  max_attempts: 10,
  tls_v1: true,
  tls_options: {
    key: '/path/to/ssl/key.pem',
    certificate: '/path/to/ssl/certificate.pem',
    ca_certificate: '/path/to/ssl/ca_certificate.pem',
    verify_mode: OpenSSL::SSL::VERIFY_PEER
  }
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
- `max_attempts` is optional and if not set messages will be attempted until they
  are explicitly finshed.

### `#pop`

`nsq-ruby` works by maintaining a local queue of in flight messages from NSQ.
To get at these messages, just call pop.

```Ruby
message = consumer.pop
```

If there are messages on the queue, `pop` will return one immediately. If there
are no messages on the queue, `pop` will block execution until one arrives.

Be aware, while `#pop` is blocking, your process will be unresponsive.  This
can be a problem in certain cases, like if you're trying to gracefully restart
a worker process by sending it a `TERM` signal. See `#pop_without_blocking` for
information on how to mitigate this issue.


### `#pop_without_blocking`

This is just like `#pop` except it doesn't block. It always returns immediately.
If there are no messages in the queue, it will return `nil`.

If you're consuming from a low-volume topic and don't want to get stuck in a
blocking state, you can use this method to consume messages like so:

```Ruby
loop do
  if msg = @messages.pop_without_blocking
    # do something
    msg.finish
  else
    # wait for a bit before checking for new messages
    sleep 0.01
  end
end
```


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

### `timestamp`

Returns the time this message was originally sent to NSQ as a `Time` object.

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

NSQ v0.2.29 or later for IDENTIFY metadata specification (0.2.28) and per-
connection timeout support (0.2.29).


### Supports

- Discovery via nsqlookupd
- Automatic reconnection to nsqd
- Producing to all nsqd instances automatically via nsqlookupd
- TLS


### Does not support

- Compression
- Backoff

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


## Is this production ready?

Yes! It's used in several critical parts of our infrastructure at
[Wistia](http://wistia.com) and currently produces and consumes hundreds of
millions of messages a day.


## Authors & Contributors

- Robby Grossman ([@freerobby](https://github.com/freerobby))
- Brendan Schwartz ([@bschwartz](https://github.com/bschwartz))
- Marshall Moutenot ([@mmoutenot](https://github.com/mmoutenot))
- Danielle Sucher ([@DanielleSucher](https://github.com/DanielleSucher))
- Anders Chen ([@chen-anders](https://github.com/chen-anders))
- Thomas O'Neil ([@alieander](https://github.com/alieander))
- Unbekandt Léo ([@soulou](https://github.com/Soulou))
- Matthias Schneider ([@mschneider82](https://github.com/mschneider82))
- Lukas Eklund ([@leklund](https://github.com/leklund))
- Paco Guzmán ([@pacoguzman](https://github.com/pacoguzman))


## MIT License

Copyright (C) 2018 Wistia, Inc.

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

