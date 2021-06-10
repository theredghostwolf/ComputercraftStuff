local delay = 0.5

--finds item in chest and returns the slot
function findItem(container, item)
  for k,v in pairs(container.list()) do
    if v["name"] == item then
      return k
    end
  end
end

--generic push item function
function pushItems(container1, container2, slot, amount)
  while amount > 0 do
    amount = amount - container1.pushItems(peripheral.getName(container2), slot, amount)
    if amount > 0 then
      os.sleep(delay)
    end
  end
end

--generic pull item function
function pullItems(container1, container2, slot, amount)
  while amount > 0 do
    amount = amount - container1.pullItems(peripheral.getName(container2), slot, amount)
    if amount > 0 then
      os.sleep(delay)
    end
  end
end

function hasTag (item, tag)
  if item.tags[tag] then
    return true
  else
    return false
  end
end
