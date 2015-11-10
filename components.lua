require("love_reactor/strict")

require("love_reactor/compose")
require("love_reactor/stream")
require("love_reactor/utils")

-- ###########
--  DRAWABLES
-- ###########

camera = {
  x = 0, y = 0,
  _following = nil,
  follow = function(self, target)
    self._following = target
  end
}

update_stream.map(function(e)
  if camera._following then
    camera.x = -camera._following.x + love.window.getWidth() / 2
    camera.y = -camera._following.y + love.window.getHeight() / 2
  end
end)

function draw_drawable(drawable)
  love.graphics.setColor(drawable.color)
  if drawable.quad then
    local spriteWidth = drawable.sprite:getWidth()
    local spriteHeight = drawable.sprite:getHeight()
    love.graphics.draw(drawable.sprite,
                       drawable.quad,
                       math.floor(drawable.x),
                       math.floor(drawable.y),
                       drawable.rotation,
                       drawable.scale.x,
                       drawable.scale.y,
                       math.floor(drawable.offset.x),
                       math.floor(drawable.offset.y)
                      )
  else
    local spriteWidth = drawable.sprite:getWidth()
    local spriteHeight = drawable.sprite:getHeight()
    love.graphics.draw(drawable.sprite,
                       math.floor(drawable.x),
                       math.floor(drawable.y),
                       drawable.rotation,
                       drawable.scale.x,
                       drawable.scale.y,
                       math.floor(drawable.offset.x),
                       math.floor(drawable.offset.y)
                      )
  end
  love.graphics.setColor(255, 255, 255, 255)
end

drawable = component(function(self)
  apply_schema({
    x = 0, y = 0,
    sprite = nil,
    color = {255, 255, 255, 255},
    quad = nil,
    rotation = 0,
    scale = {x = 1, y = 1},
    depth = 0,
    visible = true,
    draw = draw_drawable
  })(self)
  if self.sprite then
    if not self.offset then
      self.offset = {
        x = (self.width or self.sprite:getWidth()) / 2,
        y = (self.height or self.sprite:getHeight()) / 2
      }
    end

    if not self.origin then
      self.origin = {
        x = self.sprite:getWidth() / 2,
        y = self.sprite:getHeight() / 2
      }
    end

    if not self.width then
      self.width = self.sprite:getWidth()
    end

    if not self.height then
      self.height = self.sprite:getHeight()
    end
  end
end)

-- Draw drawables on "draw" event
draw_stream
  .map(function()
    local drawables = simple_clone(drawable.instances.values())
    table.sort(drawables, function(v1, v2) return v1.depth > v2.depth end)
    for _, v in pairs(drawables) do
        if v.visible then
          v:draw()
        end
    end
  end)

-- #########
--  MOVABLES
-- #########

movable = component(apply_schema({
  x = 0, y = 0,
  velocity = {x = 0, y = 0},
  acceleration = {x = 0, y = 0},
  drag = {x = 0, y = 0}
}))

function update_movable(movable)
  local position = {x = movable.x, y = movable.y}
  local new_position = vector.add(position, vector.mult(movable.velocity, love.timer.getDelta()))
  movable.x = new_position.x
  movable.y = new_position.y

  movable.velocity = vector.add(movable.velocity, vector.mult(movable.acceleration, love.timer.getDelta()))
  local dvx = movable.drag.x * love.timer.getDelta()
  if math.abs(movable.velocity.x) < dvx then
    movable.velocity.x = 0
  else
    movable.velocity.x = movable.velocity.x + dvx * (movable.velocity.x > 0 and -1 or 1)
  end

  local dvy = movable.drag.y * love.timer.getDelta()
  if math.abs(movable.velocity.y) < dvy then
    movable.velocity.y = 0
  else
    movable.velocity.y = movable.velocity.y + dvy * (movable.velocity.y > 0 and -1 or 1)
  end
end

update_stream.map(function(x)
  for _, movable in pairs(movable.instances.values()) do
    update_movable(movable)
  end
end)

-- #############
--  COLLIDABLES
-- #############

collidable = component(function(self)
  apply_schema({
    x = 0,
    y = 0,
    width = 0,
    height = 0,
    collision_stream = make_stream(),
    get_bounds = function(self)
      return {
        x = self.x - self.origin.x,
        y = self.y - self.origin.y,
        width = self.width,
        height = self.height
      }
    end
  })(self)
  if self.sprite and not self.origin then
    self.origin = {
      x = self.sprite:getWidth() / 2,
      y = self.sprite:getHeight() / 2
    }
  end

  if not self.origin then
    self.origin = {x = 0, y = 0}
  end
end)

collision_stream = make_stream()

function check_collision(ca, cb, callback)
  local a_bounds = ca:get_bounds()
  local b_bounds = cb:get_bounds()
  local center_a = {x = a_bounds.x + a_bounds.width / 2, y = a_bounds.y + a_bounds.height / 2}
  local center_b = {x = b_bounds.x + b_bounds.width / 2, y = b_bounds.y + b_bounds.height / 2}
  if math.abs(center_a.x - center_b.x) < (a_bounds.width / 2 + b_bounds.width / 2) and
     math.abs(center_a.y - center_b.y) < (a_bounds.height / 2 + b_bounds.height / 2) then
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
  check_collisions(collidable.instances.values(), function(ca, cb)
    local collision_event = {
      a = ca,
      b = cb
    }
    collision_stream.send(collision_event)
    ca.collision_stream.send(collision_event)
    cb.collision_stream.send(collision_event)
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
  local ba = ca:get_bounds()
  local bb = cb:get_bounds()
  local center_a = {x = ba.x + ba.width / 2, y = ba.y + ba.height / 2}
  local center_b = {x = bb.x + bb.width / 2, y = bb.y + bb.height / 2}
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

clickable = component(function(thing)
  apply_schema({
    x = 0,
    y = 0,
    width = 0,
    height = 0,
    origin = {x=0, y=0},
    __moused_over = false
  })(thing)
  thing.click_stream = make_stream()
  thing.mouse_over = make_stream()
  thing.mouse_out = make_stream()
end)

clickable_stream = make_stream()

function is_mouse_over(clickable)
  local mx, my = love.mouse.getPosition()
  local rect = {
    x = clickable.x - clickable.origin.x,
    y = clickable.y - clickable.origin.y,
    width = clickable.width,
    height = clickable.height
  }
  if rect.x < mx and mx < rect.x + rect.width then
    if rect.y < my and my < rect.y + rect.height then
      return true
    end
  end
  return false
end

function check_clickable(clickable, callback, mx, my, mb, type)
  if is_mouse_over(clickable) then
    callback(clickable, mx, my, mb, type)
  end
end

function check_clickables(clickables, callback, mx, my, mb, type)
  for _, clickable in pairs(clickables) do
    check_clickable(clickable, callback, mx, my, mb)
  end
end

click_stream.map(function(event)
  check_clickables(clickable.instances.values(), function(clickable, mx, my, mb)
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

update_stream.map(function(mouse)
  for _, clickable in pairs(clickable.instances.values()) do 
    local moused_over = is_mouse_over(clickable)
    if clickable.__moused_over and not moused_over then
      clickable.mouse_out.send("out")
      clickable.__moused_over = false
    end

    if not clickable.__moused_over and moused_over then
      clickable.mouse_over.send("over")
      clickable.__moused_over = true
    end
  end
end)

-- #############
--  ANIMATABLES
-- #############
--
-- animations = {
--  frames = {1,2,3} -- indicies of self.frames
--  speed = 0 -- seconds per frame
-- }

animatable = component(function(thing)
  -- Should we slice the sprite for the user?
  local auto_slice = not thing.frames and thing.width and thing.height
  apply_schema({
    frames = {}, -- list of quads
    animations = {}, -- list of animations
    _current_animation = nil,
    _current_frame = 1,
    _frame_timer = 0,
    finished_animation = make_stream(),
    play = function(self, name, force)
      local target_animation = self.animations[name]
      if self._current_animation ~= target_animation or force then
        self._current_animation = target_animation
        self._frame_timer = self._current_animation.speed or 1
        self:set_frame(1)
      end
    end,
    set_frame = function(self, frame)
      self._current_frame = frame
      self.quad = self.frames[self._current_animation.frames[self._current_frame]]
    end
  })(thing)
  if auto_slice then
    thing.frames = split_tiles(thing.sprite, thing.width, thing.height)
  end

  if thing.start_animation then
    thing:play(thing.start_animation)
  end
end)

update_stream.map(function()
  for _, animatable in pairs(animatable.instances.values()) do
    if animatable._current_animation then
      animatable._frame_timer = animatable._frame_timer - love.timer.getDelta()
      if animatable._frame_timer < 0 then
        local frame = animatable._current_frame % #(animatable._current_animation.frames)
        if frame == 0 and animatable._current_animation.next then
          animatable:play(animatable._current_animation.next)
        else
          local frame = frame + 1
          animatable:set_frame(frame)
          animatable._frame_timer = animatable._current_animation.speed or 1
        end
      end
    end
  end
end)


-- #############
--  SINGLETONS
-- #############

singleton = component(function(thing)
  thing.class.instance = thing
end)
