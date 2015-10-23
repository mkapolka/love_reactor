require("love_reactor/container")

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
  function self.new(partial, ...)
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

    print(schema.init)
    output:init(...)

    return output
  end
  return self
end
