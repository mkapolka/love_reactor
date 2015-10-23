require("love_reactor/stream")

function rxcontainer()
  local self = {}
  self.contents = {}
  self.added = make_stream()
  self.removed = make_stream()
  self._values = {}
  self._aggregate_streams = {}

  function self.add(thing)
    was_present = self.contents[thing]
    self.contents[thing] = true 
    if not was_present then
      self._attach_aggregates(thing)
      self.added.send(thing)
    end
    self._cache_values()
  end

  function self.remove(thing)
    was_present = self.contents[thing]
    self.contents[thing] = nil
    if was_present then
      self._detach_aggregates(thing)
      self.removed.send(thing)
    end
    self._cache_values()
  end

  function self.contains(thing)
    return self.contents[thing]
  end

  function self._cache_values()
    local output = {}
    i = 1
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
      stream = make_stream()
      self._aggregate_streams[field_name] = stream
      for v, _ in pairs(self.contents) do
        v[field_name].attach(stream)
      end
    end
    return stream
  end

  function self._attach_aggregates(member)
    for field_name, stream in pairs(self._aggregate_streams) do
      member[field_name].attach(stream)
    end
  end

  function self._detach_aggregates(member)
    for field_name, stream in pairs(self._aggregate_streams) do
      member[field_name].detach_from(stream)
    end
  end

  return self
end

function union(rxc1, rxc2)
  local output = rxcontainer()
  containers = {rxc1, rxc2}
  for _, container in pairs(containers) do
    container.added
      .map(function(t) output.add(t) end)
    container.removed
      .map(function(t) output.remove(t) end)
    for k, _ in pairs(container.contents) do
      output.add(k)
    end
  end
  return output
end

function difference(rxc1, rxc2)
  local output = rxcontainer()
  container = {rxc1, rxc2}
  rxc1.added
    .map(function(v)
      if not rxc2.contents[v] then
        output.add(v)
      end
    end)

  rxc1.removed
    .map(function(v)
      output.remove(v)
    end)

  rxc2.added
    .map(function(v)
      output.remove(v)
    end)
  return output
end
