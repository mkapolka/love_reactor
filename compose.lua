require("love_reactor/container")
require("love_reactor/strict")

components = {}
component_containers = {}

function apply_schema(schema)
  return function(thing)
    for key, value in pairs(schema) do
      thing[key] = thing[key] or value
    end
  end
end

function apply_component(thing, component)
  component.callback(thing)  
  thing.components[component] = true
  component.instances.add(thing)
end

function remove_component(thing, component)
  component.instances.remove(thing)
  thing.components[component] = nil
end

function has_component(thing, component)
  return thing.components[component]
end

function component(callback, requirements)
  local self = {}

  if requirements then
    local pre_callback = callback
    callback = function(thing)
      for _, requirement in pairs(requirements) do
        if not has_component(thing, requirement) then
          apply_component(thing, requirement)
        end
      end
      pre_callback(thing)
    end
  end

  self.callback = callback
  self.instances = rxcontainer()

  return self
end

__rxo_mt = {}
__rxo_mt.__index = function(self, key)
  if key == "position" then
    return {x = self.x, y = self.y}
  else
    return nil
  end
end

__rxo_mt.__newindex = function(self, key, value)
  if key == "position" then
    rawset(self, "x", value.x)
    rawset(self, "y", value.y)
  else
    rawset(self, key, value)
  end
end

function class(schema, components, membership)
  local self = {}
  local components = components or {}
  local membership = membership or {}
  self.instances = rxcontainer()
  table.insert(membership, self.instances)
  function self.new(partial, ...)
    local output = {
      components = {},
      class = self
    }
    setmetatable(output, __rxo_mt)
    if partial then
      apply_schema(partial)(output)
    end
    apply_schema(schema)(output)

    output.on_destroy = make_stream()

    for _, component in pairs(components) do
      apply_component(output, component)
    end
    for _, container in pairs(membership) do
      container.add(output)
    end

    function output.destroy()
      output.on_destroy.send("destroyed")
      for _, component in pairs(components) do
        remove_component(output, component)
      end
      for _, container in pairs(membership) do
        container.remove(output)
      end
    end

    output.init = output.init or function() end
    output:init(...)

    return output
  end
  return self
end
