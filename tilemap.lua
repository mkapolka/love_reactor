Tilemap = class({
  sprite = nil,
  quads = nil,
  tiles = {{1}},
  width = 1,
  height = 1,
  tile_width = 0,
  tile_height = 0,
  init = function(self)
    self.width = #self.tiles[1] * self.tile_width
    self.height = #self.tiles * self.tile_height
    self.quads = split_tiles(self.sprite, self.tile_width, self.tile_height)
  end,
  getTile = function(self, x, y)
    return self.tiles[y][x]
  end,
  setTile = function(self, x, y, tile)
    self.tiles[y][x] = tile
  end,
  draw = function(self)
    love.graphics.push()
    camera:translate()
    local ox = math.floor(self.x)
    local oy = math.floor(self.y)
    local tw = math.floor(self.tile_width)
    local th = math.floor(self.tile_height)
    if self.tiles then
      for x=1,#self.tiles[1] do
        for y=1,#self.tiles do
          local tile = self:getTile(x, y)
          local px = math.floor(ox + (x - 1) * tw)
          local py = math.floor(oy + (y - 1) * th)
          love.graphics.draw(self.sprite, self.quads[tile], px, py) 
        end
      end
    end
    love.graphics.pop()
  end
}, {drawable})
