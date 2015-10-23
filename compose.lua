require("love_reactor/container")

components = {}
component_containers = {}

function construct(template)
  local output = {}
  -- for k, v in template do
    -- if not k == "components" and not k == membership then
      -- output[k] = v
    -- end
  -- end
-- 
  -- for _, name in ipairs(template.components) do
    -- schema = components[name]
    -- for k, v in schema do
      -- output[k] = output[k] or v
    -- end
  -- end

  for _, container in ipairs(template.membership) do
    container.add(template)
  end
  return template
end

function apply_schema(schema)
  return function(thing)
    for key, value in pairs(schema) do
      thing[key] = thing[key] or value
    end
  end
end

function apply_component(thing, component)
  component.callback(thing)  
  component_containers[component.name].add(thing)
end

function component(name, plural, callback)
  local self = {}
  self.name = name
  self.plural = plural
  self.callback = callback

  components[name] = self
  component_containers[name] = rxcontainer()
  _G[plural] = component_containers[name]

  return self
end

function class(schema, components, membership)
  local self = {}
  local membership = membership or {}
  self.instances = rxcontainer()
  table.insert(membership, self.instances)
  function self.new(partial)
    local output = {}
    apply_schema(partial)(output)
    apply_schema(schema)(output)

    for _, component in pairs(components) do
      apply_component(output, component)
    end
    for _, container in pairs(membership) do
      container.add(output)
    end

    function output.destroy()
      for _, component in pairs(components) do
        local component_container = component_containers[component.name]
        component_container.remove(output)
      end
      for _, container in pairs(membership) do
        container.remove(output)
      end
    end

    return output
  end
  return self
end

function make_drawable(thing)
  thing.x = thing.x or 0
  thing.y = thing.y or 0
  thing.sprite = thing.sprite or nil
end

function make_movable(thing)
  thing.x = thing.x or 0
  thing.y = thing.y or 0
  thing.vx = thing.vx or 0
  thing.vy = thing.vy or 0
  return thing
end

function make_bounded(thing)
  thing.x = thing.x or 0
  thing.y = thing.y or 0
  thing.width = thing.width or 0
  thing.height = thing.height or 0
end

function compose(partial, callbacks)
  local output = {}
  for key, value in pairs(partial) do
    output[key] = value
  end
  for _, callback in pairs(callbacks) do
    callback(output)
  end
  return output
end

function tick_movable(movable)
  movable.dx = movable.dx + (movable.ax or 0) * love.timer.getDelta()
  movable.dy = movable.dx + (movable.ay or 0) * love.timer.getDelta()

  movable.x = movable.x + movable.vx * love.timer.getDelta()
  movable.y = movable.y + movable.vy * love.timer.getDelta()
end

function vibrate(drawable)
  local clone = simple_clone(drawable)
  clone.x = clone.x + math.random(-1, 1) * 10
  clone.y = clone.y + math.random(-1, 1) * 10
  return clone
end

function translation(off_x, off_y)
  return function(drawable)
    local cloned = simple_clone(drawable)
    cloned.x = cloned.x + off_x
    cloned.y = cloned.y + off_y
    return cloned
  end
end
