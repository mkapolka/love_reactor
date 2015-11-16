--[[
world = {
  width = 1024, OR tile_width
  height = 768, OR tile_height
  data = {
    "####",
    "#@_#",
    "##d#",
  },
  extra = {
    {class = CloudManager},
    background = love.graphics.newImage("sprites/background.png")
  },
  legend = {
    ["#"] = {
      class=Wall,
    },
    d = {
      class=Portal,
      target_state = "outside",
      sprite = love.graphics.newImage("sprites/door.png"),
    }
  }
}]]--

function parse_map(data)
  local output = {}
  output.tiles = {}

  local width = 1
  local height = 1
  local offset_x = 0
  local offset_y = 0
  if data.tile_width then
    width = #data.data[1] * data.tile_width
    offset_x = data.tile_width / 2
  else
    width = output.width or love.window.getWidth()
  end

  if data.tile_height then
    height = #data.data * data.tile_height
    offset_y = data.tile_height / 2
  else
    height = output.height or love.window.getHeight()
  end

  output.width = width
  output.height = height

  for y=1,#data.data do
    output.tiles[y] = {}
    local line = data.data[y]
    for x=1,#line do
      local c = line:sub(x,x)
      local schema = data.legend[c]
      if schema then
        local thing = shallow_clone(schema)
        thing.x = ((x-1) / #line) * width + offset_x
        thing.y = ((y-1) / #data.data) * height + offset_y
        table.insert(output, thing)
      end

      if data.tiles then
        local tile = data.tiles[c] or data.tiles["default"]
        if tile then
          output.tiles[y][x] = tile
        end
      end
    end
  end

  for k, value in pairs(data.extra or {}) do
    if type(k) == "number" then
      table.insert(output, value)
    else
      output[k] = value
    end
  end

  return output
end

-- Pass this a parsed map to instantiate the objects automatically
-- Only works for items with a 'class' attribute, passes itself as a partial.
-- You're on your own for differently typed extras
function simple_instantiate(map)
  local new_things = {}
  for i=1,#map do
    local data = map[i] 
    if data.class then
      table.insert(new_things, data.class.new(data))
    end
  end
  return new_things
end
