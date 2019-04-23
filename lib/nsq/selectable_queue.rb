# A queue that you can pass to IO.select.
#
# NOT THREAD SAFE: Only one thread should write; only one thread should read.
#
# Purpose:
#   Allow easy integration of data-producing threads into event loops. The
#   queue will be readable from select's perspective as long as there are
#   objects in the queue.
#
# Implementation:
#   The queue maintains a pipe. The pipe contains a number of bytes equal to
#   the queue size.
#
# Example use:
#   queue = SelectableQueue.new
#   readable, _, _ = IO.select([queue, $stdin])
#   print "got #{queue.pop}" if readable.contain?(queue)
#
class SelectableQueue
  def initialize(size = 0)
    if size == 0
      @queue = Queue.new
    else
      @queue = SizedQueue.new(size)
    end
    @read_io, @write_io = IO.pipe
  end

  def empty?
    @queue.empty?
  end

  def push(o)
    @queue.push(o)
    # It doesn't matter what we write into the pipe, as long as it's one byte.
    # It's not blocking until full, and has a default limit of 65536 (64KB)
    @write_io << '.'
    self
  end

  def pop(nonblock=false)
    o = @queue.pop(nonblock)
    @read_io.read(1)
    o
  end

  def to_io
    @read_io
  end
end

