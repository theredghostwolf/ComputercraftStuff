function sendData (id, message, data)
  if type(data) == "table" then
    data = textutils.serialize(data)
  end
  rednet.send(id, message .. ":" .. data)
end

function receiveData (id, message)
  local m, data = message:match("([^:]+):([^:]+)")
  if data then
    if string.sub(data, 1, 1) == "{" then
      data = textutils.unserialize(data)
    end
  end
  return m, data
end
