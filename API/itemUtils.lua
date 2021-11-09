local delay = 0.5

--finds item in chest and returns the slot
function findItem(container, item)
  for k,v in pairs(container.list()) do
    if v["name"] == item then
      return k, v
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

--pushes an item from multiple slots
function pushMultipleItems (container1, container2, item, amount)
  while amount > 0 do
    for k,v in pairs(container1.list()) do
      if v.name == item then
        if v.count >= amount then
          pushItems(container1, container2, k, amount)
          amount = 0
        else
          pushItems(container1, container2, k, v.count)
          amount = amount - v.count
        end
      end
      if amount <= 0 then
        break;
      end
    end
  end
end

--generic pull item function
function pullItems(container1, container2, slot, amount, slot2)
  while amount > 0 do
    amount = amount - container1.pullItems(peripheral.getName(container2), slot, amount, slot2)
    if amount > 0 then
      os.sleep(delay)
    end
  end
end

--pulls an item from multiple slots
function pullMultipleItems (container1, container2, item, amount)
  while amount > 0 do
    for k,v in pairs(container1.list()) do
      if v.name == item then
        if v.count >= amount then
          pullItems(container1, container2, k, amount)
          amount = 0
        else
          pullItems(container1, container2, k, v.count)
          amount = amount - v.count
        end
      end
      if amount <= 0 then
        break;
      end
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

--returns the total amount of a certain item in the inventory
function getTotalItemCount (container, item)
  local slots = {}
  local amount = 0
  for k,v in pairs(container.list()) do
    if v.name == item then
      amount = amount + v.count
      table.insert(slots, {slot = k, amount = v.count})
    end
  end
  return amount, slots
end
