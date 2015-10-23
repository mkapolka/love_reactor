-- Event streams return this when they are done.
-- Table value so it can act as a symbol
no_more = {}

function make_stream()
  local self = {}
  self.listeners = {}
  self.inputs = {}
  function self.send(value)
    for _, listener in pairs(self.listeners) do
      listener.receive(value)
    end
  end

  function self.receive(value)
    self.send(value)
  end

  function self.map(f)
    if f == nil then
      error("map received nil")
    end

    local output = make_stream()
    function output.receive(value)
      local send = f(value)
      if send == no_more then
        output.detach()
      else
        output.send(send)
      end
    end
    table.insert(self.listeners, output)
    table.insert(output.inputs, self)
    return output
  end

  function self.mapValue(value)
    return self.map(function(_)
      return value
    end)
  end

  function self.filter(f)
    local output = make_stream()
    function output.receive(value)
      if (f(value)) then
        output.send(value)
      end
    end
    table.insert(self.listeners, output)
    table.insert(output.inputs, self)
    return output
  end

  function self.attach(stream)
    table.insert(stream.inputs, self)
    table.insert(self.listeners, stream)
    return stream
  end

  function self.detach_from(stream)
    table.removeValue(stream.inputs, self)
    table.removeValue(self.listeners, self)
  end

  function self.replace(stream)
    for _, input in pairs(self.inputs) do
      input.attach(stream)
    end
    stream.listeners = self.listeners
    self._clear_inputs()
  end

  function self.detach()
    self._clear_inputs()
  end

  function self.preSplice(stream)
    for _, input in pairs(self.inputs) do
      input.attach(stream)
    end
    stream.attach(self)
    self._clear_inputs()
  end

  function self._clear_inputs(stream)
    for _, input in pairs(self.inputs) do
      input._remove_listener(self)
    end
  end

  function self._remove_listener(stream)
    for i, listener_stream in pairs(self.listeners) do
      if stream == listener_stream then
        table.remove(self.listeners, i)
      end
    end
  end

  function self.explode()
    local output = make_stream()
    function output.receive(values)
      for _, value in pairs(values) do
        output.send(value)
      end
    end
    self.attach(output)
    return output
  end

  function self.take_until(other)
    local output = self.map(function(v) return v end)
    other.map(function()
      output.detach()
      return no_more
    end)
    return output
  end

  function self.buffer_latest(flush)
    -- Makes a stream that stores values from input and sends them down when we get a signal from flush
    local cached = nil
    local buffer_stream = make_stream()
    self.attach(buffer_stream)

    flush.map(function() buffer_stream.flush() end)

    function buffer_stream.receive(value)
      buffer_stream.cached = value
    end

    function buffer_stream.flush()
      if buffer_stream.cached then
        buffer_stream.send(buffer_stream.cached)
      end
      buffer_stream.cached = nil
    end

    return buffer_stream
  end

  function self.buffer(flush_stream)
    -- Makes a stream that stores values from input and sends them down when we get a signal from flush
    local buffer_stream = make_stream()
    self.attach(buffer_stream)

    buffer_stream.cache = {}
    function buffer_stream.receive(value)
      table.insert(buffer_stream.cache, value)
    end

    function buffer_stream.flush()
      buffer_stream.send(buffer_stream.cache)
      buffer_stream.cache = {}
    end

    flush_stream.map(function()
      buffer_stream.flush()
    end)

    return buffer_stream
  end

  return self
end

function make_map_stream(f)
  local output = make_stream()
  function output.receive(value)
    output.send(f(value))
  end
  return output
end

function combineLatest(stream_table, initial_values)
  local output = make_stream()
  output.latest_values = initial_values
  output.cxns = {}
  function output.broadcast()
    output.send(output.latest_values)
  end

  function output.detach()
    for _, cxn in pairs(output.cxns) do
      cxn.input._remove_listener(cxn)
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

update_stream = make_stream()
draw_stream = make_stream()
click_stream = make_stream()
keypressed_stream = make_stream()
keyreleased_stream = make_stream()

keyheld_stream = make_stream()
keypressed_stream.map(function(k)
  update_stream.take_until(keyreleased_stream
                            .filter(function(v) return v == k end))
    .map(function(_) keyheld_stream.send(k) end)
end)

mouse_stream = update_stream.map(function(_)
  return {x = love.mouse.getX(), y = love.mouse.getY()}
end)


function love.update()
  update_stream.send("tick")
end

function love.draw()
  draw_stream.send("draw")
end

function love.mousepressed(x, y, button)
  click_stream.send({x = x, y = y, button = button, type = "down"})
end

function love.mousereleased(x, y, button)
  click_stream.send({x = x, y = y, button = button, type = "up"})
end

function love.keypressed(button, isrepeat)
  if not isrepeat then
    keypressed_stream.send(button)
  end
end

function love.keyreleased(button, isrepeat)
  if not isrepeat then
    keyreleased_stream.send(button)
  end
end
