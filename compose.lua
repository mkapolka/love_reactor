require("love_reactor/container")
require("love_reactor/strict")

components = {}
component_containers = {}

function apply_schema(schema, thing)
  for key, value in pairs(schema) do
    thing[key] = thing[key] or value
  end
end

function apply_component(thing, component)
  for _, requirement in pairs(component.requirements) do
    if not has_component(thing, requirement) then
      apply_component(thing, requirement)
    end
  end
  component.callback(thing)  
  thing.components[component] = true
  component.instances.add(thing)
end

function remove_component(thing, component)
  component.instances.remove(thing)
  for _, requirement in pairs(component.requirements) do
    remove_component(thing, requirement)
  end
  thing.components[component] = nil
end

function has_component(thing, component)
  return thing.components[component]
end

function component(callback, requirements)
  local self = {}

  self.callback = callback
  self.requirements = requirements or {}
  self.instances = rxcontainer()

  return self
end

__rxo_mt = {}
__rxo_mt.__index = function(self, key)
  if key == "position" then
    return {x = self.x, y = self.y}
  else
    return ({
      destroy = function(self)
        self.on_destroy:send("destroyed")
        for _, component in pairs(self.class.components) do
          remove_component(self, component)
        end
        for _, container in pairs(self.class.membership) do
          container.remove(self)
        end
      end
    })[key]
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
  self.membership = membership
  self.components = components
  table.insert(membership, self.instances)
  function self.new(values, ...)
    local output = {
      components = {},
      class = self
    }
    setmetatable(output, __rxo_mt)
    if values then
      apply_schema(values, output)
      if values.position then
        output.position = values.position
      end
    end
    apply_schema(schema, output)

    output.on_destroy = newStream()

    for _, component in pairs(components) do
      apply_component(output, component, false)
    end

    output.init = output.init or function() end
    output:init(...)

    for _, container in pairs(membership) do
      container.add(output)
    end

    return output
  end
  return self
end
