require("love_reactor/strict")

require("love_reactor/compose")
require("love_reactor/stream")
require("love_reactor/utils")

-- ###########
--  DRAWABLES
-- ###########

camera = {
  x = 0, y = 0
}

function draw_drawable(drawable)
  love.graphics.setColor(drawable.color)
  if drawable.quad then
    love.graphics.draw(drawable.sprite,
                       drawable.quad,
                       drawable.x,
                       drawable.y,
                       drawable.rotation,
                       drawable.sx,
                       drawable.sy,
                       drawable.ox,
                       drawable.oy
                      )
  else
    love.graphics.draw(drawable.sprite,
                       drawable.x,
                       drawable.y,
                       drawable.rotation,
                       drawable.sx,
                       drawable.sy,
                       drawable.ox,
                       drawable.oy
                      )
  end
  love.graphics.setColor(255, 255, 255, 255)
end

drawable = component("drawable", "drawables",
  apply_schema({
    x = 0,
    y = 0,
    sprite = nil,
    color = {255, 255, 255, 255},
    quad = nil,
    rotation = 0,
    sx = 1,
    sy = 1,
    ox = 0,
    oy = 0,
    depth = 0,
    visible = true,
    draw = draw_drawable
  }))

function draw_drawables(drawables)
  local drawables = simple_clone(drawables.values())
  table.sort(drawables, function(v1, v2) return v1.depth > v2.depth end)
  for _, v in pairs(drawables) do
      if v.visible then
        v:draw()
      end
  end
end

-- Draw drawables on "draw" event
draw_stream.mapValue(drawables)
  .map(draw_drawables)

-- #########
--  MOVABLES
-- #########

movable = component("movable", "movables", apply_schema({
  x = 0,
  y = 0,
  vx = 0,
  vy = 0,
  ax = 0,
  ay = 0,
  drag_x = 0,
  drag_y = 0,
}))

function update_movable(movable)
  movable.x = movable.x + movable.vx * love.timer.getDelta()
  movable.y = movable.y + movable.vy * love.timer.getDelta()
  movable.vx = movable.vx + movable.ax * love.timer.getDelta()
  movable.vy = movable.vy + movable.ay * love.timer.getDelta()
  local dvx = movable.drag_x * love.timer.getDelta()
  if math.abs(movable.vx) < dvx then
    movable.vx = 0
  else
    movable.vx = movable.vx + dvx * (movable.vx > 0 and -1 or 1)
  end

  local dvy = movable.drag_y * love.timer.getDelta()
  if math.abs(movable.vy) < dvy then
    movable.vy = 0
  else
    movable.vy = movable.vy + dvy * (movable.vy > 0 and -1 or 1)
  end
end

update_stream.map(function(x)
  for _, movable in pairs(movables.values()) do
    update_movable(movable)
  end
end)

-- #############
--  COLLIDABLES
-- #############

collidable = component("collidable", "collidables", apply_schema({
  x = 0,
  y = 0,
  width = 0,
  height = 0,
}))

collision_stream = make_stream()

function check_collision(ca, cb, callback)
  local center_a = {x = ca.x + ca.width / 2, y = ca.y + ca.height / 2}
  local center_b = {x = cb.x + cb.width / 2, y = cb.y + cb.height / 2}
  if math.abs(center_a.x - center_b.x) < (ca.width / 2 + cb.width / 2) and
     math.abs(center_a.y - center_b.y) < (ca.height / 2 + cb.height / 2) then
    callback(ca, cb)
  end
end

function check_collisions(collidables, callback)
  for i=1,#collidables do
    for j=i+1,#collidables do
      local ca = collidables[i]
      local cb = collidables[j]
      check_collision(ca, cb, callback)
    end
  end
end

update_stream.map(function()
  check_collisions(collidables.values(), function(ca, cb)
    local collision_event = {
      a = ca,
      b = cb
    }
    collision_stream.send(collision_event)
  end)
end)

function collision_between(group_1, group_2)
  local function check(event)
    local a = event.a
    local b = event.b
    if group_1.contains(a) and group_2.contains(b) then
      return event
    elseif group_2.contains(a) and group_1.contains(b) then
      return {
        a = event.b,
        b = event.a
      }
    end
    return nil
  end
  return check
end

function dumb_collisions(ca, cb)
  local center_a = {x = ca.x + ca.width / 2, y = ca.y + ca.height / 2}
  local center_b = {x = cb.x + cb.width / 2, y = cb.y + cb.height / 2}
  local delta = {
    x = center_a.x - center_b.x,
    y = center_a.y - center_b.y
  }
  local magnitude = math.sqrt(delta.x * delta.x + delta.y * delta.y)
  local normalized
  if magnitude > 0 then
    normalized = {
      x = delta.x / magnitude,
      y = delta.y / magnitude
    }
  else
    normalized = {
      x = 1,
      y = 0
    }
  end
  local pushForce = math.max(0, 100 - magnitude)
  ca.x = ca.x + normalized.x * love.timer.getDelta() * pushForce * 10
  ca.y = ca.y + normalized.y * love.timer.getDelta() * pushForce * 10
  cb.x = cb.x - normalized.x * love.timer.getDelta() * pushForce * 10
  cb.y = cb.y - normalized.y * love.timer.getDelta() * pushForce * 10
end

-- #############
--  CLICKABLES
-- #############

clickable = component("clickable", "clickables", function(thing)
  apply_schema({
    x = 0,
    y = 0,
    width = 0,
    height = 0,
  })(thing)
  thing.click_stream = make_stream()
end)

clickable_stream = make_stream()

function check_clickable(clickable, callback, mx, my, mb, type)
  if clickable.x < mx and mx < clickable.x + clickable.width then
    if clickable.y < my and my < clickable.y + clickable.height then
      callback(clickable, mx, my, mb, type)
    end
  end
end

function check_clickables(clickables, callback, mx, my, mb, type)
  for _, clickable in pairs(clickables) do
    check_clickable(clickable, callback, mx, my, mb)
  end
end

click_stream.map(function(event)
  check_clickables(clickables.values(), function(clickable, mx, my, mb)
    local event = {
      target = clickable,
      mx = mx,
      my = my, 
      button = mb,
      type = event.type
    }
    clickable_stream.send(event)
    event.target.click_stream.send(event)
  end, event.x, event.y, event.button, event.type)
end)
