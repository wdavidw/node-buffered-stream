util = require 'util'
Stream = require 'stream'

###

Performances
------------

The results presented below are obtained by running `coffee samples/speed.coffee`.

Writting 100000 lines of 100 bytes (about 9.5 Mo)

```
0 b     : 2 s 146 ms 
64 b    : 2 s 172 ms 
128 b   : 2 s 155 ms 
256 b   : 1 s 256 ms 
512 b   : 749 ms 
1 Kb    : 565 ms 
1 Mb    : 333 ms 
4 Mb    : 341 ms 
16 Mb   : 342 ms 
64 Mb   : 350 ms 
128 Mb  : 351 ms
```

Writting 1000000 lines of 100 bytes (about 95 Mo)

```
0 b     : 20 s 636 ms 
64 b    : 20 s 217 ms 
128 b   : 21 s 749 ms 
256 b   : 12 s 769 ms 
512 b   : 7 s 520 ms 
1 Kb    : 5 s 452 ms 
1 Mb    : 3 s 193 ms 
4 Mb    : 3 s 218 ms 
16 Mb   : 3 s 326 ms 
64 Mb   : 3 s 415 ms 
128 Mb  : 3 s 368 ms
```

###
BufferStream = (size) ->
  Stream.call @
  @readable = true
  @writable = true
  @bufferSize = if size? then parseInt(size, 10) else 1024 * 1024
  @paused = false
  @buffers = []
  @stackSize = 1
util.inherits BufferStream, Stream

###
Emit "end" if the "end" function has been called and there is no more buffer to flush.
###
BufferStream.prototype.flush = () ->
  ended = not @writable
  return if not ended and @paused
  # Restart the pump if running and buffer back to 1
  # Note, used to be:
  # if (ended and not @buffers.length) or (not ended and @buffers.length <= 1)
  if not ended and @buffers.length <= 1
    return @emit 'drain'
  if (ended and @buffers.length) or @buffers.length > 1
    buffer = @buffers.shift();
    @emit 'data', buffer.slice 0, buffer.position
  if ended and not @buffers.length
    if @paused
      @on 'drain', ->
        @emit 'end'
    else
      @emit 'end'
    return
  @flush()


BufferStream.prototype.destroy = ->
  @destroySoon()

BufferStream.prototype.destroySoon = ->
  @end()
  @readable = false
  @writable = false

###
Write API
drain  Emitted after a write() method was called that returned false to indicate that it is safe to write again
error  Emitted on error with the exception exception
close  Emitted when the underlying file descriptor has been closed
pipe    Emitted when the stream is passed to a readable stream's pipe method
###
BufferStream.prototype.write = (data, opt_encoding) ->
  if data
    flush = false
    encoding = opt_encoding or 'utf8'
    data = new Buffer data, encoding unless Buffer.isBuffer data
    if data.length > @bufferSize
      @emit 'data', data
      return not @paused
    if data.length > @bufferSize
      throw new Error 'Data length greater than buffer'
    if not @buffers.length
      # Create a new buffer if none is present
      buffer = new Buffer @bufferSize
      buffer.position = 0
      @buffers.push buffer
    else
      # Get the last buffer
      buffer = @buffers[@buffers.length-1]
    # Check if the last buffer is not about to overflow
    if buffer.position + data.length > buffer.length
      # If so, create a new buffer
      buffer = new Buffer @bufferSize
      buffer.position = 0
      @buffers.push buffer
      flush = true
    # Now, write into our buffer
    # buffer.write data, encoding, buffer.position
    data.copy buffer, buffer.position
    buffer.position += data.length
    # Flush old buffer
    @flush() if flush
  # Pause stream if number of buffers greater than 1
  return @buffers.length <= @stackSize

BufferStream.prototype.end = (data, opt_encoding) ->
  @write data, opt_encoding if data
  @writable = false
  @flush()

###
Read API
data    The 'data' event emits either a Buffer (by default) or a string if setEncoding() was used.
end    Emitted when the stream has received an EOF (FIN in TCP terminology). Indicates that no more 'data' events will happen. If the stream is also writable, it may be possible to continue writing.
error  Emitted if there was an error receiving data.
close  Emitted when the underlying file descriptor has been closed. Not all streams will emit this. (For example, an incoming HTTP request will not emit 'close'.)
###
BufferStream.prototype.pause = ->
  @paused = true

BufferStream.prototype.resume = ->
  @paused = false
  @flush()

module.exports = BufferStream
