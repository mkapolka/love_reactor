-- table.filter({"a", "b", "c", "d"}, function(o, k, i) return o >= "c" end)  --> {"c","d"}
--
-- @FGRibreau - Francois-Guillaume Ribreau
-- @Redsmin - A full-feature client for Redis http://redsmin.com
table.filter = function(t, filterIter)
  local out = {}

  local i = 1
  for k, v in pairs(t) do
    if filterIter(v, k, t) then 
      out[i] = v
      i = i + 1
    end
  end

  return out
end

function table.map(t, f)
  local out = {}
  for k, v in pairs(t) do
    out[k] = f(v)
  end
  return out
end

function table.any(t, f)
  for k, v in pairs(t) do
    if f(v) then
      return true
    end
  end
  return false
end

function table.all(t, f)
  return not table.any(t, function(v) return not f(v) end)
end

function table.replace(t, v1, v2)
  for k, v in pairs(t) do
    if t[k] == v1 then
      t[k] = v2
    end
  end
end

function table.removeValue(table, value)
  for k, v in pairs(table) do
    if v == value then
      table[k] = nil
      return
    end
  end
end

function table.chain(...)
  local output = {}
  for _, t in pairs({...}) do
    for _, v in pairs(t) do
      table.insert(output, v)
    end
  end
  return output
end

function table.clone(table)
  local output = {}
  for k, v in pairs(table) do
    output[k] = v
  end
  return output
end

function table.pick_random(t)
  local values = {}
  for _, v in pairs(t) do
    table.insert(values, v)
  end
  return values[math.random(1, #values)]
end

function table.reduce(t, f, initial)
  local mem = initial
  for _, v in pairs(t) do
    mem = f(mem, v)
  end
  return mem
end

-- f = "key" function, members of t will be compared against each other as f(v)
function table.min(t, f)
  if not f then
    f = function(a) return a end
  end

  local function min_cmp(a, b)
    if a == nil then return b end
    if f(a) < f(b) then
      return a
    else
      return b
    end
  end

  return table.reduce(t, min_cmp)
end

function table.max(t, f)
  if not f then
    f = function(a) return a end
  end

  local function max_cmp(a, b)
    if a == nil then return b end
    if f(a) > f(b) then
      return a
    else
      return b
    end
  end

  return table.reduce(t, max_cmp)
end

function table.empty(t)
  return #t > 0
end

function table.member_set(t)
  local output = {}
  for _, v in pairs(t) do
    output[v] = true
  end
  return output
end

function table.apply(t1, t2)
  for k, v in pairs(t2) do
    t1[k] = v
  end
end
