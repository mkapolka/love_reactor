require("love_reactor/utils")

-- Event streams return NO_MORE when they are done.
-- Table value so it can act as a symbol
NO_MORE = {}

__stream_index = {
  send = function(self, value)
    local clone = shallow_clone(self.listeners)
    for _, listener in pairs(clone) do
      listener:receive(value)
    end
  end,

  receive = function(self, value)
    self:send(value)
  end,

  map = function(self, f)
    if f == nil then
      error("map received nil")
    end

    local output = newStream()
    function output:receive(value)
      local send = f(value)
      if send == NO_MORE then
        output:finish()
      else
        output:send(send)
      end
    end
    table.insert(self.listeners, output)
    table.insert(output.inputs, self)
    return output
  end,

  mapFilter = function(self, f)
    return self.map(f).filter(identity)
  end,

  mapValue = function(self, value)
    return self:map(function(_)
      return value
    end)
  end,

  filter = function(self, f)
    local output = newStream()
    function output:receive(value)
      if (f(value)) then
        output:send(value)
      end
    end
    table.insert(self.listeners, output)
    table.insert(output.inputs, self)
    return output
  end,

  attach = function(self, stream)
    table.insert(stream.inputs, self)
    table.insert(self.listeners, stream)
    return stream
  end,

  detachFrom = function(self, stream)
    table.removeValue(stream.inputs, self)
    table.removeValue(self.listeners, stream)
  end,

  replace = function(self, stream)
    for _, input in pairs(self.inputs) do
      input:attach(stream)
    end
    stream.listeners = self.listeners
    self:_clear_inputs()
  end,

  finish = function(self)
    self:_clear_inputs()
    self:_clear_outputs()
  end,

  preSplice = function(self, stream)
    for _, input in pairs(self.inputs) do
      input:attach(stream)
    end
    stream:attach(self)
    self:_clear_inputs()
  end,

  _clear_inputs = function(self)
    for _, input in pairs(self.inputs) do
      input:_remove_listener(self)
    end
  end,

  _clear_outputs = function(self)
    for _, listener in pairs(self.listeners) do
      listener:_remove_input(self)
    end
  end,

  _remove_listener = function(self, stream)
    table.removeValue(self.listeners, stream)
  end,

  _remove_input = function(self, which)
    table.removeValue(self.inputs, which)
  end,

  explode = function(self)
    local output = newStream()
    function output:receive(values)
      for _, value in pairs(values) do
        output:send(value)
      end
    end
    self:attach(output)
    return output
  end,

  takeUntil = function(self, other)
    local output = self:map(function(v) return v end)
    other:map(function()
      output:finish()
      return NO_MORE
    end)
    return output
  end,

  combine = function(self, other)
    local output = newStream()
    self:attach(output)
    other:attach(output)
    return output
  end,

  takeOne = function(self)
    local output = newStream()
    self:map(function(value)
      output:send(value)
      return NO_MORE
    end)
    return output
  end,

  bufferLatest = function(self, flush)
    -- Makes a stream that stores values from input and sends them down when we get a signal from flush
    local cached = nil
    local bufferStream = newStream()
    self:attach(bufferStream)

    flush:map(function() bufferStream:flush() end)

    function bufferStream.receive(self, value)
      bufferStream.cached = value
    end

    function bufferStream.flush(self)
      if bufferStream.cached then
        bufferStream:send(bufferStream.cached)
      end
      bufferStream.cached = nil
    end

    return bufferStream
  end,

  buffer = function(self, flush_stream)
    -- Makes a stream that stores values from input and sends them down when we get a signal from flush
    local bufferStream = newStream()
    self:attach(bufferStream)

    bufferStream.cache = {}
    function bufferStream.receive(self, value)
      table.insert(bufferStream.cache, value)
    end

    function bufferStream.flush(self)
      bufferStream:send(bufferStream.cache)
      bufferStream.cache = {}
    end

    flush_stream:map(function()
      bufferStream:flush()
    end)

    return bufferStream
  end,

  delay = function(self, time)
    local output = newStream()
    output.receive = function(self, value)
      local time_left = time
      update_stream
        :map(function()
          time_left = time_left - love.timer.getDelta()
          if time_left < 0 then
            output:send(value)
            return NO_MORE
          end
        end)
    end
    self:attach(output)
    return output
  end,

  throttle = function(self, time_between, delay_initial)
    local output = newStream()
    output.last_message = (delay_initial and love.timer.getTime()) or 0
    output.receive = function(self, value)
      if (love.timer.getTime() - output.last_message) > time_between then
        output:send(value)
        output.last_message = love.timer.getTime()
      end
    end
    self:attach(output)
    return output
  end,
  
  print = function(self, prepend)
    prepend = prepend or ""
    return self:map(function(x)
      print(prepend .. tostring(x))
      return x
    end)
  end,

  repl = function(self, prepend)
    return self:map(repl):print(prepend)
  end
}

function newStream()
  local output = {listeners = {}, inputs = {}}
  return setmetatable(output, {__index = __stream_index})
end

function combineLatest(stream_table, initial_values)
  local output = newStream()
  output.latest_values = initial_values
  output.cxns = {}
  function output.broadcast()
    output:send(output.latest_values)
  end

  function output.finish()
    for _, cxn in pairs(output.cxns) do
      cxn.finish()
    end
  end

  for key, stream in pairs(stream_table) do
    local cxn = {}
    cxn.inputs = {}
    function cxn.receive(value)
      output.latest_values[key] = value
      output.broadcast()
    end
    stream.attach(cxn)
    cxn.input = stream
    table.insert(output.cxns, cxn)
  end
  return output
end

-- Love hooks

updateStream = newStream()
drawStream = newStream()
clickStream = newStream()
keyPressedStream = newStream()
keyReleasedStream = newStream()

keyHeldStream = newStream()
keyHeldStream:map(function(k)
  updateStream:takeUntil(keyreleasedStream
                            :filter(function(v) return v == k end))
    :map(function(_) keyheldStream:send(k) end)
end)

mouseStream = updateStream:map(function(_)
  return {x = love.mouse.getX(), y = love.mouse.getY()}
end)


function love.update()
  updateStream:send("tick")
end

function love.draw()
  drawStream:send("draw")
end

function love.mousepressed(x, y, button)
  clickStream:send({x = x, y = y, button = button, type = "down"})
end

function love.mousereleased(x, y, button)
  clickStream:send({x = x, y = y, button = button, type = "up"})
end

function love.keypressed(button, isrepeat)
  if not isrepeat then
    keyPressedStream:send(button)
  end
end

function love.keyreleased(button, isrepeat)
  if not isrepeat then
    keyReleasedStream:send(button)
  end
end
