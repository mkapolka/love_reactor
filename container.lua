require("love_reactor/stream")


__rxinstance_mt = {}
__rxinstance_mt.stream = function(self, name)
  local stream = self.__streams[name]
  if not stream then
    stream = newStream()
    self.__streams[name] = stream

    if self.__value then
      self.__value[name]:attach(stream)
    end
  end
  return stream
end

__rxinstance_mt.__detach_streams = function(self)
  for name, stream in pairs(self.__streams) do
    stream:detach_from(self.__value[name])
  end
end

__rxinstance_mt.__attach_streams = function(self)
  for name, stream in pairs(self.__streams) do
    self.__value[name]:attach(stream)
  end
end

__rxinstance_mt.set = function(self, value)
  if self.__value then
    self:_detach_streams()
  end
  self.__value = value
  self:__attach_streams()
end

__rxinstance_mt.get = function(self)
  return self.__value
end

function rxinstance(initial_value)
  local self = {}
  self.__streams = {}
  setmetatable(self, {
    __index = __rxinstance_mt
  })
  self:set(initial_value)
  return self
end

function rxcontainer()
  local self = {}
  self.contents = {}
  self.added = newStream()
  self.removed = newStream()
  self._values = {}
  self._aggregate_streams = {}

  function self.add(thing)
    local was_present = self.contents[thing]
    self.contents[thing] = true 
    if not was_present then
      self._attach_aggregates(thing)
      self.added:send(thing)
    end
    self._cache_values()
  end

  function self.remove(thing)
    local was_present = self.contents[thing]
    self.contents[thing] = nil
    if was_present then
      self.removed:send(thing)
    end
    self._cache_values()
  end

  function self.contains(thing)
    return self.contents[thing]
  end
  
  function self.empty()
    return #self.values() == 0
  end

  function self._cache_values()
    local output = {}
    local i = 1
    for k, _ in pairs(self.contents) do
      output[i] = k
      i = i + 1
    end
    self._values = output
  end

  function self.values()
    return self._values
  end

  function self.aggregate(field_name)
    local stream = self._aggregate_streams[field_name]
    if not stream then
      stream = newStream()
      self._aggregate_streams[field_name] = stream
      for v, _ in pairs(self.contents) do
        v[field_name]:takeUntil(self.removed:filter(function(e) return e == v end))
          :map(function(v)
            return {member = v, value = v}
          end):attach(stream)
        end
    end
    return stream
  end

  function self.call(fname, ...)
    for _, member in pairs(self.values()) do
      member[fname](...)
    end
  end

  function self.callBound(fname, ...)
    for _, member in pairs(self.values()) do
      member[fname](member, ...)
    end
  end

  function self.set(key, value)
    for _, member in pairs(self.values()) do
      member[key] = value
    end
  end

  function self.map(func)
    for _, member in pairs(self.values()) do
      func(member)
    end
  end

  function self.clear()
    for _, v in pairs(self.values()) do
      self.remove(v)
    end
  end

  function self.filter(func)
    local output = rxcontainer()
    output.values = function()
      return table.filter(self.values(), func)
    end
    output.contains = function(what)
      return self.contains(what) and func(what)
    end
    return output
  end

  function self._attach_aggregates(member)
    for field_name, stream in pairs(self._aggregate_streams) do
      if not member[field_name] then
        error("Member has no stream named '" .. field_name .. "'")
      end
      member[field_name]:takeUntil(self.removed:filter(function(e) return e == member end))
        :map(function(v)
            return {member = member, value = v}
        end):attach(stream)
    end
  end

  return self
end

function union(...)
  local output = rxcontainer()
  local containers = {...}
  for _, container in pairs(containers) do
    container.added
      :map(function(t) output.add(t) end)
    container.removed
      :map(function(t) output.remove(t) end)
    for k, _ in pairs(container.contents) do
      output.add(k)
    end
  end
  return output
end

function difference(rxc1, rxc2)
  local output = rxcontainer()
  output.contains = function(value)
    return rxc1.contains(value) and not rxc2.contains(value)
  end
  output.values = function(value)
    return table.filter(rxc1.values(), function(value) return not rxc2.contains(value) end)
  end
  return output
end

function intersection(rxc1, rxc2)
  local output = rxcontainer()
  output.contains = function(value)
    return rxc1.contains(value) and rxc2.contains(value) 
  end
  output.values = function()
    return table.filter(rxc1.values(), function(value) return rxc2.contains(value) end)
  end
  return output
end
