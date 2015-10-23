vector = {}
function vector.magnitude(v)
  return math.sqrt(v.x * v.x + v.y * v.y) 
end

function vector.normalize(v)
  local mag = vector.magnitude(v) 
  if mag == 0 then mag = 1 end
  return {
    x = v.x / mag,
    y = v.y / mag
  }
end

function vector.mult(v, f)
  return {
    x = v.x * f,
    y = v.y * f
  }
end

function vector.sub(v1, v2)
  return {
    x = v1.x - v2.x,
    y = v1.y - v2.y
  }
end

return vector
