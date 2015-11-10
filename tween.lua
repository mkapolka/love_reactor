tablify_interp = function(interp)
  return function(min, max, v)
    local output = {}
    for key, _ in pairs(min) do
      output[key] = interp(min[key], max[key], v, interp)
    end
    return output
  end
end

optionally_tablify = function(interp)
  return function(min, max, v)
    if type(min) == "table" then
      return tablify_interp(interp)(min, max, v)
    else
      return interp(min, max, v)
    end
  end
end

linear_interp = optionally_tablify(function(min, max, v)
  return min + (max - min) * v
end)

sin_interp = optionally_tablify(function(min, max, v)
  local v = (math.cos(v * math.pi) * -1/2) + .5
  return linear_interp(min, max, v)
end)

text_grow_interp = function(min, max, v)
  local width = (#max - #min)
  return min .. string.sub(max, #min+1, #min+1 + math.floor(v * width))
end

text_decrypt_interp = function(min, max, v)
  local letters = math.floor(v * #max)
  local gibberish = ""
  for i=1,#max - letters do
    gibberish = gibberish .. string.char(math.random(48, 122))
  end
  return string.sub(max, 1, letters) .. gibberish
end

Tweener = class({
  target = nil,
  field = nil,
  min = 0,
  max = 0,
  time = 0,
  interpolate = linear_interp,
  callback = function()end,
  init = function(self)
    self.__start_time = love.timer.getTime()
    for _, t in pairs(Tweener.instances.values()) do
      if t.target == self.target and t.field == self.field and t ~= self then
        t.destroy()
      end
    end
  end,
  value_at = function(self, time)
    local n = math.min((time - self.__start_time) / self.time, 1)
    return self.interpolate(self.min, self.max, n)
  end,
  is_done = function(self, time)
    return time > self.__start_time + self.time
  end
})

update_stream.map(function()
  for _, t in pairs(Tweener.instances.values()) do
    t.target[t.field] = t:value_at(love.timer.getTime())
    if t:is_done(love.timer.getTime()) then
      t.callback()
      t.destroy()
    end
  end
end)

function tween(object, field, min, max, time, interpolation, callback)
  interpolation = interpolation or linear_interp
  return Tweener.new({
    target = object,
    field = field,
    min = min,
    max = max,
    time = time,
    callback = callback,
    interpolate = interpolation
  })
end
