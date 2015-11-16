function sequence(values)
  local output = {}
  output._values = values
  output._pointer = 1
  output.next = function(self)
    self._pointer = (self._pointer % #self._values) + 1
    return self._values[self._pointer]
  end
  output.previous = function(self)
    self._pointer = self._pointer - 1
    if self._pointer < 1 then
      self._pointer = #self._values
    end
    return self._values[self._pointer]
  end
  output.current = function(self)
    return self._values[self._pointer]
  end
  return output
end

