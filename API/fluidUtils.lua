local delay = 0.5

--checks if a tank has fluid
function hasFluid(container, fluid)
  for k,v in pairs(container.tanks()) do
    if  v["name"] == fluid then
      return true, k
    end
  end
  return false
end

function findFluid (container, fluid)
  local has, slot = hasFluid(container, fluid)
  return slot
end

function hasFluidInAmount (container, fluid, amount)
 local b,s = hasFluid(container, fluid)
 if b and s then
   t = container.tanks()
   if t[s].amount >= amount then
     return true
   end
 end
 return false
end

function pullFluid (container1, container2, fluid, amount)
  while amount > 0 do
    amount = amount - container1.pullFluid(peripheral.getName(container2), amount, fluid)
    if amount > 0 then
      os.sleep(delay)
    end
  end
end

function pushFluid (container1, container2, fluid, amount)
  while amount > 0 do
    amount = amount - container1.pushFluid(peripheral.getName(container2), amount, fluid)
    if amount > 0 then
      os.sleep(delay)
    end
  end
end

function getFluidAmount (container, fluid)
  local total = 0
  for k,v in pairs(container.tanks()) do
    if v.name == fluid then
      total = total + v.amount
    end
  end
  return total
end
