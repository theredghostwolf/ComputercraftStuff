--list of periperherals already in use
local usedPeripherals = {}
local error = true

--checks the list of used peripherals
local function isInUse (p)
  for k,v in pairs(usedPeripherals) do
    if v == p then
      return true
    end
  end
  return false
end

--detects and returns the side the peripheral is on
function detectPeripheral (name)
    for k,v in pairs(redstone.getSides()) do
        if not isInUse(v) and peripheral.getType(v) == name then
             return v
        end
    end

    for k,v in pairs (peripheral.getNames()) do
      if string.find(v, name) and not isInUse(v) then
        return v
      end
    end

    if error then
      print("Cannot find periperheral: " .. name)
    end

    return nil
end

--returns a peripheral handler
function wrapPeripheral (name, lock)
  local p = detectPeripheral(name)
  if p then
    if lock then
      table.insert(usedPeripherals, p)
    end
    return peripheral.wrap(p)
  else
    return nil
  end
end


function setError (b)
  error = b
end

--returns a list of peripheral objects of given type
function wrapMultiplePeripherals (type)
  peripheralUtils.setError(false)
  local p = {}
  local t = peripheralUtils.wrapPeripheral(type, true)
  while t do
    table.insert(p, t)
    t = peripheralUtils.wrapPeripheral(type, true)
  end
  peripheralUtils.setError(true)
  return p
end


--removes peripheral name from used peripherals
function unlock (p)
  for k,v in pairs (usedPeripherals) do
    if v == p then
      table.remove(k)
    end
  end
end
