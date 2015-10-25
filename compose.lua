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
  component.instances.add(thing)
end

function remove_component(thing, component)
  component.instances.remove(thing)
end

function component(callback)
  local self = {}
  self.callback = callback
  self.instances = rxcontainer()

  return self
end

function class(schema, components, membership)
  local self = {}
  local components = components or {}
  local membership = membership or {}
  self.instances = rxcontainer()
  table.insert(membership, self.instances)
  function self.new(partial, ...)
    local output = {}
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
      for _, component in pairs(components) do
        remove_component(output, component)
      end
      for _, container in pairs(membership) do
        container.remove(output)
      end
      output.on_destroy.send("destroyed")
    end

    output.init = output.init or function() end
    output:init(...)

    return output
  end
  return self
end
