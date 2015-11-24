function simple_clone(table)
  -- Shallow clone
  local output = {}
  for key, value in pairs(table) do
    output[key] = value
  end
  return output
end

shallow_clone = simple_clone

function repl(tabl)
  local output = {}
  for key, value in pairs(tabl) do
    table.insert(output, tostring(key) .. ": " .. tostring(value))
  end
  return "{" .. table.concat(output, ", ") .. "}"
end

function split_tiles(sprite, width, height)
  local output = {}
  local w, h = sprite:getDimensions()
  for y=0,(h / height)-1 do
    for x=0,(w / width)-1 do
      table.insert(output,
        love.graphics.newQuad(x * width, y * height, width, height, sprite:getDimensions())
      )
    end
  end
  return output
end

function math.frandom(min, max)
  local r = math.random()
  return min + r * (max - min)
end

function math.clamp(value, min, max)
  if value < min then
    return min
  elseif value > max then
    return max
  end
  return value
end

start_time = love.timer.getTime()
function love.timer.getRuntime()
  return love.timer.getTime() - start_time
end

-- delim here needs to be a single character
function split(s, delim)
  local output = {}
  for match in string.gmatch(s, "[^" .. delim .. "]+") do
    table.insert(output, match)
  end
  return output
end

function getTextHeight(string, font)
  local lines = #split(string, "\n")
  return font:getHeight() * lines
end

function random_point_within(rect_like)
  return {
    x = math.random(rect_like.x, rect_like.x + rect_like.width / 2),
    y = math.random(rect_like.y, rect_like.y + rect_like.height/ 2)
  }
end

function identity(...)
  return ...
end
