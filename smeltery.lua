--TO DO

--[[
REWORK RECIPE SYSTEM
add options for custom cast amount (E.g molten clay to bricks)
add options for casting over an item
add option for castin in basin
add option for casting without cast

REWORK system that calculates and checks valid smeltables
currently assumes alot of values should be more flexible to adjust per item while retaining current adaptability

REWORK input calculation and overflow
Allow the system to store leftover metal in tanks if available
allow system to cast more then requested to make a rounded amount if possible and move extra to be moved into input chest for resmelting
rework calculation for what to insert

CREATE utilities for handling config files

FIX UI
add page support for cast / metal select
rework amount page (should also account for max amount possible in current smeltery size and amount of metal available for current selected)

ADD support for an auto-ingot mode (cast all raw materials into ingots without alloying them while smeltery is idle)

OPTIONAL
add support for continuing current crafting operation upon restart (chunk unload, server restart etc)
]]--

--APIs

os.loadAPI("API/peripheralUtils.lua")
os.loadAPI("API/itemUtils.lua")
os.loadAPI("API/fluidUtils.lua")
os.loadAPI("API/UIUtils.lua")

--variables

--all other calculations are based of these numbers so make sure they are accurate

nuggetPerOre = 18 --check the tinkers config file for the accurate number
ingot = 144 -- amount of molten metal per ingot
gem = 250 -- amount of fluid per gem
slimeball = 250 --amount of fluid for slimeball

--peripherals used by program
smelteryPeripherals = {
  smeltery = "tconstruct:smeltery",
  drain = "tconstruct:drain",
  fuelTanks = "tconstruct:tank",
  storageTanks = "tconstruct:tank",
  basins = "tconstruct:basin",
  tables = "tconstruct:table",
  inputChest = "minecraft:chest",
  outputChest = "minecraft:chest",
  monitor = "monitor"
}

refreshRate = 0.5 -- how fast the current UI redraws
endScreenDelay = 5 -- how long end screen should display after finished craft

smelteryFuel = "minecraft:lava" -- fuel type used by smeltery
smelteryCapacity = 648 * ingot -- smeltery size

emptyStorageTanks = false -- will leave 1MB of molten metal in tanks unless set to true
storageTankCapacity = 4000 -- amount of MB storage tanks can hold
fuelTankCapacity = 4000 --amount of MB each tank in the smeltery can hold

--list of items that can be melted but not cast
meltables = {
  ore = {
    tag = "forge:ores",
    amount = (ingot / 9) * nuggetPerOre -- amount of molten metal per ore
  },

  dust = {
    tag = "forge:dusts",
    amount = ingot
  },

  slimeball = {
    tag = "forge:slimeball",
    amount = slimeball
  },

  block = {
    tag = "forge:storage_blocks",
    amount = ingot * 9
  }
}

--items that can be melted but dont fit in regular item lists - tag should be the entire item name
specialMeltables = {
  clayball = {
    name = "minecraft:clay_ball",
    amount = ingot,
    metal = "clay"
  },

  grout = {
    name = "tconstruct:grout",
    amount = ingot * 2,
    metal = "searedstone"
  },

  searedstone_brick = {
    name = "tconstruct:seared_brick",
    amount = ingot,
    metal = "searedstone"
  }
}

--list of metals and matching data -- ratios are in ingots
metals = {

  iron = {
    name = "iron",
    fluid = "tconstruct:molten_iron",
    casts = {"gear", "ingot", "nugget", "rod", "plate"}
  },

  gold = {
    name = "gold",
    fluid = "tconstruct:molten_gold",
    casts = {"gear", "ingot", "nugget", "rod", "plate"}
  },

  emerald = {
    name = "emerald",
    fluid = "tconstruct:molten_emerald",
    casts = {"gem"}
  },

  copper = {
    name = "copper",
    fluid = "tconstruct:molten_copper",
    casts = {"gear", "ingot", "nugget", "rod", "plate"}
  },

  tin = {
    name = "tin",
    fluid = "tconstruct:molten_tin",
    casts = {"gear", "ingot", "nugget", "rod", "plate"}
  },

  bronze = {
      name = "bronze",
      fluid = "tconstruct:molten_bronze",
      casts = {"gear", "ingot", "nugget", "rod", "plate"},
      alloy = {
        ratio = {
          tin = ingot,
          copper = ingot * 3
        },
        result = ingot * 4
      }
  },

  clay = {
    name = "clay",
    fluid = "tconstruct:molten_clay",
    casts = {"ingot"}
  },

  blood = {
    name = "blood",
    fluid = "tconstruct:blood",
  },

  searedstone = {
    name = "searedstone",
    fluid = "tconstruct:seared_stone",
    casts = {"ingot"}
  },

  skyslime = {
    name = "sky",
    fluid = "tconstruct:skyslime"
  },

  slimesteel = {
    name = "slimesteel",
    fluid = "tconstruct:molten_slimesteel",
    alloy = {
      ratio = {
        iron = ingot,
        skyslime = slimeball,
        searedstone = ingot
      },
      result = ingot * 2
    },
    casts = {"ingot", "nugget"}
  },

  pig_iron = {
    name = "pig_iron",
    fluid = "tconstruct:molten_pig_iron",
    alloy = {
      ratio = {
        blood = slimeball,
        clay = ingot,
        iron = ingot
      },
      result = ingot * 2
    },
    casts = {"ingot", "nugget"}
  }
}

--list of valid casts their result and required amount of molten metal
casts = {
  ingot = {
    item = "tconstruct:ingot_cast",
    tag = "forge:ingots",
    amount = ingot
  },

  plate = {
    item = "tconstruct:plate_cast",
    tag  = "forge:plates",
    amount = ingot
  },

  rod = {
    item = "tconstruct:rod_cast",
    tag = "forge:rods",
    amount = ingot / 2
  },

  gear = {
    item = "tconstruct:gear_cast",
    tag = "forge:gears",
    amount = ingot * 4
  },

  nugget = {
    item = "tconstruct:nugget_cast",
    tag = "forge:nuggets",
    amount = ingot / 9
  },

  gem = {
    item = "tconstruct:gem_cast",
    tag = "forge:gems",
    amount =  gem
  }

}

pageSize = 12 -- amount of buttons per page

--data used / generated by program do not touch
current = {
  cast = nil,
  metal = nil,
  amount = 1,
  done = 0,
  UI = nil,
  page = 1,
  breakdown = {
    alloy = 0,
    fluid = 0,
    melt = 0
  },
  previousUI = {}
}

--- UI elements
navBar = UIUtils.NavbarClass.new()
startButton = UIUtils.ButtonClass.new()
nextButton = UIUtils.ButtonClass.new()
previousButton = UIUtils.ButtonClass.new()
previousUIButton = UIUtils.ButtonClass.new()
fuelbar = UIUtils.ProgressBarClass.new()

programLog = UIUtils.LogClass.new()

craftingProgressbar = UIUtils.ProgressBarClass.new()
craftingProgressbarLabel = UIUtils.TextClass.new()
craftingTextLabel = UIUtils.TextClass.new()
liquidLabel = UIUtils.TextClass.new()
meltLabel = UIUtils.TextClass.new()
alloyLabel = UIUtils.TextClass.new()
breakdownLabel = UIUtils.TextClass.new()


--objects

--functions
function setupPeripherals ()
  for k,v in pairs(smelteryPeripherals) do
    if k == "tables" then
      smelteryPeripherals[k] = peripheralUtils.wrapMultiplePeripherals(v)
    elseif k == "basins" then
      smelteryPeripherals[k] = peripheralUtils.wrapMultiplePeripherals(v)
      --connect fuel tanks, copy list of storage tanks if same type
    elseif k == "fuelTanks" then
      if smelteryPeripherals.storageTanks then
        if smelteryPeripherals.storageTanks[1] and peripheral.getType(smelteryPeripherals.storageTanks[1]) == v then
          smelteryPeripherals[k] = smelteryPeripherals.storageTanks
        else
          smelteryPeripherals[k] = peripheralUtils.wrapMultiplePeripherals(v)
        end
      else
        smelteryPeripherals[k] = peripheralUtils.wrapMultiplePeripherals(v)
      end
    --connect storage tanks, copy list of fuel tanks if same type
    elseif k == "storageTanks" then
      if smelteryPeripherals.fuelTanks then
        if smelteryPeripherals.fuelTanks[1] and peripheral.getType(smelteryPeripherals.fuelTanks[1]) == v then
          smelteryPeripherals[k] = smelteryPeripherals.fuelTanks
        else
          smelteryPeripherals[k] = peripheralUtils.wrapMultiplePeripherals(v)
        end
      else
        smelteryPeripherals[k] = peripheralUtils.wrapMultiplePeripherals(v)
      end
    else
      smelteryPeripherals[k] = peripheralUtils.wrapPeripheral(v, true)
    end
  end
end

function logPeripherals ()
  for k,v in pairs(smelteryPeripherals) do
    if k == "tables" or k == "fuelTanks" or k == "storageTanks" then
      for k1, v1 in pairs(v) do
          print(k1, peripheral.getName(v1))
        end
    else
      print(k, peripheral.getName(v))
    end
  end
end

--returns true if there is atleast 1 cast present
function hasCast (cast)
  for k,v in pairs(smelteryPeripherals.tables) do
    if itemUtils.findItem(v,cast.item) then
      return true
    end
  end
  return false
end

--returns all available casts
function getAvailableCasts ()
  local available = {}
  for k,v in pairs(casts) do
    if hasCast(v) then
      available[k] = v
    end
  end
  return available
end

--checks if the smeltery has enough molten metal available to make the cast
function hasFluidForCast (cast, fluid)
 return fluidUtils.hasFluidInAmount(smelteryPeripherals.drain, fluid, cast.amount)
end

--retuns a list of tables with the specific cast
function getTablesWithCast(cast)
  local tables = {}
  for k,v in pairs(smelteryPeripherals.tables) do
    local tItems = v.list()
    if tItems[1] and tItems[1].name == cast.item then
      table.insert(tables, v)
    end
  end
  return tables
end

function fillTable(table, metal, amount)
    if #table.tanks() < 1 and not table.list()[2] then
      fluidUtils.pushFluid(smelteryPeripherals.drain, table, metal.fluid, amount)
      return true
    end
    return false
end

function emptyTable (table, outputB)
  if table.list()[2] then
    if outputB then
      itemUtils.pushItems(table,smelteryPeripherals.outputChest,2,1)
    else
      itemUtils.pushItems(table,smelteryPeripherals.inputChest,2,1)
    end
    return true
  end
  return false
end

--calculates how many unit are available in the input chest for the given metal
function getAvailableMeltables (metal)
  local total = 0
  local melt = {}
  for i = 1,smelteryPeripherals.inputChest.size() do
    local item = smelteryPeripherals.inputChest.getItemDetail(i)
    if item then
      for k,v in pairs(combineTable(casts, meltables, specialMeltables)) do
        if (v.tag and itemUtils.hasTag(item, v.tag .. "/" .. metal.name))  or (v.name and v.name == item.name and v.metal == metal.name) then
          total = total + v.amount * item.count
          if melt[v.amount] then
            melt[v.amount].count = melt[v.amount].count + item.count
            melt[v.amount].slots[i] = item.count
          else
            melt[v.amount] = {
              count = item.count,
              amount = v.amount,
              slots = {}
            }
            melt[v.amount].slots[i] = item.count
          end
        end
      end
    end
  end
  melt = sortMeltables(melt, function (a, b) return a.amount > b.amount end)
  return total, melt
end

function createInputList (metal, amount)
  local t, m = getAvailableMeltables(metal)
  local input = {}
  if t >= amount then
    local remainder = amount
    for k,v in pairs(m) do
      local temp = remainder / v.amount

      if temp >= 1 then
        if temp%1 > 0 then
          temp = temp - (temp%1)
        end

        if temp <= v.count then
          input[v.amount] = temp
          remainder = remainder - temp * v.amount
        else
          input[v.amount] = v.count
          remainder = remainder - v.count * v.amount
        end
        if remainder == 0 then
          break
        end
      end
    end
    if remainder ~= 0 then
      if getAvailableStorageFor(metal) >= remainder then
        --move remainder to storage
      else
          print("not enough materals for exact cast... need: " .. remainder / ingot .. " ingots worth of: " .. metal.name)
      end
    else
      return input
    end
  else
    --not enough materials
    print("not enough materials for: " .. metal.name .. " amount: " .. amount)
  end
end

function combineTable(...)
  local resultTable = {}

  for k,v in ipairs(arg) do
    for k2, v2 in pairs(v) do
      resultTable[k2] = v2
    end
  end

  return resultTable
end

function getTableSize (t)
  local s = 0
  for k,v in pairs(t) do
    s = s + 1
  end
  return s
end

function sortMeltables (t, comp)
  local temp = {}
  for k,v in pairs(t) do
    table.insert(temp, v)
  end
  table.sort(temp, comp)
  return temp
end

function insertInputList (list, metal)
  local t,m = getAvailableMeltables(metal)

  for k,v in pairs(list) do
    for k1,v1 in pairs(m) do
      if v > 0 then
        if v1.amount == k then
          for slot, itemCount in pairs(v1.slots) do
            if itemCount <= v then
              itemUtils.pushItems(smelteryPeripherals.inputChest, smelteryPeripherals.smeltery, slot, itemCount)
              v = v - itemCount
            else
              itemUtils.pushItems(smelteryPeripherals.inputChest, smelteryPeripherals.smeltery, slot, v)
              v = 0
            end
            if v == 0 then
              break
            end
          end
        end
      else
        break
      end
    end
  end
end

--calculates the amount of fluid needed of each metal to create alloy
function calculateRatio (metal, amount)
  local result = {}
  if metal.alloy then
    for k,v in pairs(metal.alloy.ratio) do
      result[k] = v / metal.alloy.result * amount
    end
  end
  return result
end

--waits till smeltery has melted / alloyed metals
function meltMetals(metal, amount)
  while not fluidUtils.hasFluidInAmount(smelteryPeripherals.drain, metal.fluid, amount) do
    os.sleep(0.5)
  end
end

--will mix metals inside smeltry to create alloy
function alloy(metal, amount)
  if metal.alloy then
    local l = calculateRatio(metal, amount)
    local inputs = {}
    for k,v in pairs(l) do
      local m = getAvailableMoltenMetal(metals[k])
      if m >= v then
        m = v
        v = 0
      else
        v = v - (math.floor(m / metal.alloy.ratio[k]) * metal.alloy.ratio[k])
      end
      inputs[k] = {}
      inputs[k]["fluid"] = m
      if v > 0 then
        inputs[k]["items"] = createInputList(metals[k], v)
      end


      if m > 0 then
        insertMoltenMetal(metals[k], m)
      end
      if inputs[k]["items"] then
        insertInputList(inputs[k]["items"], metals[k])
      end
    end
  end
end

--returns the max amount of alloy available
function getAvailableAlloy (metal)
  if metal.alloy then
    local available = {}
    for k,v in pairs(metal.alloy.ratio) do
      local a = getAvailableMeltables(metals[k]) + getAvailableMoltenMetal(metals[k])
      available[k] = {
        amount = a,
        proportion = math.floor(a / v)
      }
    end
    local m = sortMeltables(available, function (a,b) return a.proportion < b.proportion end)
    return m[1].proportion * metal.alloy.result
  end
end

--returns the available premolten metals in tanks
function getAvailableMoltenMetal (metal)
  local available = 0
  for k,v in pairs (smelteryPeripherals.storageTanks) do
    local b, s = fluidUtils.hasFluid(v, metal.fluid)
    if b then
      available = available + v.tanks()[s].amount
      if not emptyStorageTanks then
        available = available - 1
      end
    end
  end
  return available
end

--inserts the metal from the storage tanks into the smeltery
function insertMoltenMetal (metal, amount)
  if getAvailableMoltenMetal(metal) >= amount then
    for k,v in pairs(smelteryPeripherals.storageTanks) do
      local b, s = fluidUtils.hasFluid(v, metal.fluid)
      if b then
        local a = fluidUtils.getFluidAmount(v, metal.fluid)

        if not emptyStorageTanks then
          a = a - 1
        end

        if a >= amount then
          fluidUtils.pushFluid(v, smelteryPeripherals.drain, metal.fluid, amount)
          amount = 0
        else
          fluidUtils.pushFluid(v, smelteryPeripherals.drain, metal.fluid, a)
          amount = amount - a
        end

        if amount == 0 then
          break
        end
      end
    end
  end
end

function hasStorageTankFor (metal)
  for k,v in pairs(smelteryPeripherals.storageTanks) do
    if fluidUtils.hasFluid(v, metal.fluid) then
      return true
    end
  end
  return false
end

function getStorageCapacityFor (metal)
  local capacity = 0
  local filled = 0

  for k,v in pairs(smelteryPeripherals.storageTanks) do
    if fluidUtils.hasFluid(v, metal.fluid) then
      capacity = capacity + storageTankCapacity
      filled = filled + fluidUtils.getFluidAmount(v, metal.fluid)
    end
  end

  return capacity, filled
end

function getAvailableStorageFor (metal)
  local c,f = getStorageCapacityFor(metal)
  return c - f
end

function getTotalMetalAvailable (metal)
  local res = {
    molten = getAvailableMoltenMetal(metal),
    meltables = getAvailableMeltables(metal),
    alloy = 0
  }

  if metal.alloy then
    res.alloy = getAvailableAlloy(metal)
  end

  return res.molten + res.meltables + res.alloy, res
end

function craft(cast, metal, amount)
  programLog.addMessage("Calculating avaiable metals...", 1)
  local totalMoltenMetal = cast.amount * amount
  local totalAvailable, breakdown = getTotalMetalAvailable(metal)
  local availableStorage = getAvailableStorageFor (metal)

  --programLog.addMessage(breakdown.molten, 4)

  programLog.addMessage("Finished Calculating availableMetals",3)
  --print("total alloy avail: " .. breakdown.alloy)
  programLog.addMessage("Calculating insertion ratio...",1)
  if totalAvailable >= totalMoltenMetal then
    local remainder = amount

    local moltenToInsert = math.floor(breakdown.molten / cast.amount)
    if moltenToInsert >= remainder then
      moltenToInsert = remainder
    end
    remainder = remainder - moltenToInsert
    --print("molten to insert:" .. moltenToInsert * cast.amount)
    current.breakdown.fluid = moltenToInsert * cast.amount
    --liquidLabel.text = "Fluid: " .. tostring(moltenToInsert * cast.amount)
    programLog.addMessage("Inserting " .. tostring(moltenToInsert * cast.amount) .. "MB fluid",1)
    local meltablesToInsert = math.floor(breakdown.meltables / cast.amount)
    if meltablesToInsert >= remainder then
      meltablesToInsert = remainder
    end
    remainder = remainder - meltablesToInsert
    --print("items to insert: " .. meltablesToInsert * cast.amount)
    current.breakdown.melt = meltablesToInsert * cast.amount
    --meltLabel.text = "Items: " .. tostring(meltablesToInsert * cast.amount)
    programLog.addMessage("Inserting: " .. tostring(meltablesToInsert * cast.amount) .. "MB in Items",1)

    local alloyToInsert = math.floor(breakdown.alloy / cast.amount)
    if alloyToInsert >= remainder then
      alloyToInsert = remainder
    end
    remainder = remainder - alloyToInsert
    --print("to alloy: " .. alloyToInsert * cast.amount)
    current.breakdown.alloy = alloyToInsert * cast.amount
    --alloyLabel.text = "Alloy: " .. tostring(alloyToInsert * cast.amount)
    programLog.addMessage("Alloying: " .. tostring(alloyToInsert * cast.amount) .. "MB",1)

    if remainder > 0 then
      programLog.addMessage("Missing materials!", 2)
    else
      programLog.addMessage("Inserting items...",1)
      if moltenToInsert > 0 then
        insertMoltenMetal(metal, moltenToInsert * cast.amount)
      end

      if meltablesToInsert > 0 then
        local l = createInputList(metal, meltablesToInsert * cast.amount)
        insertInputList(l, metal)
      end

      if alloyToInsert > 0 then
        alloy(metal, alloyToInsert * cast.amount)
      end

      programLog.addMessage("Finished inserting items",3)
      programLog.addMessage("Waiting for items to melt",1)

      meltMetals(metal, totalMoltenMetal)

      programLog.addMessage("Finished melting items..",3)

      local c = amount
      local d = amount
      programLog.addMessage("Casting items...",1)

      while c > 0 or d > 0 do
        for k,v in pairs(getTablesWithCast(cast)) do

          if c > 0 then
            if fillTable(v, metal, cast.amount) then
              c = c - 1
            end
          end

          if d > 0 then
            if emptyTable(v, true) then
              current.done = current.done + 1
              drawCurrentUI()
              d = d - 1
            end
          end

        end
      end
    end

  else
    programLog.addMessage("Missing materials!", 2)
  end
  programLog.addMessage("Done!",3)

  os.sleep(endScreenDelay)
  programLog.clear()
  current.metal = nil
  current.amount = 1
  current.cast = nil
  current.done = 0
  current.breakdown = {
    fluid = 0,
    melt = 0,
    alloy = 0
  }
  navBar.options = {}
  setUI(startUI)
end

function getFuelLevel ()
  local capacity = 0
  local filled = 0

  for k,v in pairs(smelteryPeripherals.fuelTanks) do
    if fluidUtils.hasFluid(v, smelteryFuel) then
      capacity = capacity + fuelTankCapacity
      filled = filled + fluidUtils.getFluidAmount(v, smelteryFuel)
    end
  end

  return filled, capacity
end

function getFuelPercent ()
  local f, c = getFuelLevel()
  return (f / c)
end

function selectMetal(m)
  current.metal = m
  navBar.options[2] = m

  setUI(amountUI)
end

function selectCast (c)
  current.cast = c
  navBar.options[1] = c
  setUI(generateMetalUI(1))
end

function setUI (UI)
  table.insert(current.previousUI, current.UI)
  current.UI = UI
  drawCurrentUI()
end

function setCastUI (page)
  setUI(generateCastUI(page))
end

function previousUI ()
  current.UI = table.remove(current.previousUI, #current.previousUI)
  if not current.UI then
    current.UI = startUI
  end
  drawCurrentUI()
end

function tableContains (table, val)
  for k,v in pairs(table) do
    if v == val then
      return true
    end
  end
  return false
end

function getValidMetals (cast)
  local valid = {}
  for k,v in pairs(metals) do
    if v.casts and tableContains(v.casts, cast) then
      valid[k] = v
    end
  end
  return valid
end

function generateMetalUI (page)
  local monw, monh = smelteryPeripherals.monitor.getSize()
  local UI = UIUtils.UIClass.new ()
  local validMetals = getValidMetals(current.cast)
  local validMetalCount = getTableSize(validMetals)

  local pages = math.ceil(validMetalCount / pageSize)
  if page > 1 then
    UI.addObject(previousButton)
  end
  if page < pages then
    UI.addObject(nextButton)
  end

  --add navbar
  UI.addObject(navBar)
  UI.addObject(previousUIButton)

  local ba = validMetalCount -- amount of buttons
  if ba > pageSize then
    ba = pageSize
  end
  local buttons = UIUtils.generateButtons (smelteryPeripherals.monitor, ba, 2,3,monw - 1, monh -1,4,3, colors.yellow,colors.blue, colors.white, selectMetal)

  local currentKey = 1
  for k,v in pairs(validMetals) do

    buttons[currentKey].text = v.name
    buttons[currentKey].data = v.name

    currentKey = currentKey + 1
  end

  UI.addObjects(buttons)
  return UI
end

function generateCastUI (page)
  local monw, monh = smelteryPeripherals.monitor.getSize()
  local UI = UIUtils.UIClass.new ()
  local availableCasts = getAvailableCasts()
  local castAmount = getTableSize(availableCasts)

  local pages = math.ceil(castAmount / pageSize)
  if page > 1 then
    UI.addObject(previousButton)
  end
  if page < pages then
    UI.addObject(nextButton)
  end

  --add navbar
  UI.addObject(navBar)
  UI.addObject(previousUIButton)

  local ba = castAmount -- amount of buttons
  if ba > pageSize then
    ba = pageSize
  end
  local buttons = UIUtils.generateButtons (smelteryPeripherals.monitor ,ba, 2,3,monw - 1, monh - 1 , 4,3,colors.yellow,colors.blue, colors.white, selectCast)

  local currentKey = 1
  for k,v in pairs(availableCasts) do

    buttons[currentKey].text = k
    buttons[currentKey].data = k

    currentKey = currentKey + 1
  end

  UI.addObjects(buttons)
  return UI
end

function maxAmountOfcasts (cast)
  return math.floor(smelteryCapacity / cast.amount)
end

function setCurrentAmount (amount)
  current.amount = amount
  navBar.options[3] = amount
  monw, monh = smelteryPeripherals.monitor.getSize()
  craftingProgressbarLabel.pos.x = ((monw / 2) - ((3 + (2 * #tostring(current.amount))) / 2))
  setUI(craftingUI)
  craft(casts[current.cast], metals[current.metal], current.amount)
end

function generateAmountUI ()
  local monw, monh = smelteryPeripherals.monitor.getSize()
  local UI = UIUtils.UIClass.new()

  UI.addObject(navBar)
  UI.addObject(previousUIButton)

  local label = UIUtils.TextClass.new()
  label.text = "select amount:"
  label.pos.y = 3
  label.pos.x = (monw / 2) - (#label.text / 2)
  label.textColor = colors.white
  label.primaryColor = colors.black

  UI.addObject(label)

  --1,4,8,16,32,64
  local buttons = UIUtils.generateButtons(smelteryPeripherals.monitor, 6,7,5,monw - 7, monh - 2, 2,3, colors.yellow, colors.blue, colors.white, setCurrentAmount)


  buttons[1].data = 1
  buttons[1].text = 1

  buttons[2].data = 4
  buttons[2].text = 4

  buttons[3].data = 8
  buttons[3].text = 8

  buttons[4].data = 16
  buttons[4].text = 16

  buttons[5].data = 32
  buttons[5].text = 32

  buttons[6].data = 64
  buttons[6].text = 64

  UI.addObjects(buttons)
  return UI
end

function drawCurrentUI ()
  if current.UI then
    if term.current ~= smelteryPeripherals.monitor then
      local prev = term.redirect(smelteryPeripherals.monitor)
    end

    local monw, monh = smelteryPeripherals.monitor.getSize()
    current.UI.update()

    paintutils.drawFilledBox(0,0,monw, monh, colors.black)
    term.clear()
    term.setCursorPos(1,1)
    current.UI.draw()

    if prev then
      term.redirect(prev)
    end
  end
end

function getCraftingProgress ()
  return current.done / current.amount
end

function getCraftingProgressText ()
  return current.done .. " / " .. current.amount
end

function setupUIObjects ()


  local monw, monh = smelteryPeripherals.monitor.getSize()


  navBar.primaryColor = colors.black
  navBar.textColor = colors.white
  navBar.pos.x = 1
  navBar.pos.y = 1
  navBar.height = 0
  navBar.width = monw

  nextButton.text = ">"
  nextButton.secondaryColor = colors.lightBlue
  nextButton.textColor = colors.white
  nextButton.width = 0
  nextButton.height = 2
  nextButton.pos.x = monw
  nextButton.pos.y = (monh / 2) - (nextButton.height / 2)

  previousButton.text = "<"
  previousButton.width = 0
  previousButton.height = 2
  previousButton.pos.x = 1
  previousButton.pos.y = (monh / 2) - (previousButton.height / 2)
  previousButton.textColor = colors.white
  previousButton.secondaryColor = colors.lightBlue


  previousUIButton.text = "Back"
  previousUIButton.width = 6
  previousUIButton.height = 0
  previousUIButton.pos.x = monw - previousUIButton.width - 1
  previousUIButton.pos.y = 1
  previousUIButton.onClick = previousUI

  fuelbar.data = getFuelPercent()
  fuelbar.width = 5
  fuelbar.height = monh - 3
  fuelbar.horizontal = false
  fuelbar.pos.x = monw - (fuelbar.width + 1)
  fuelbar.pos.y  = 2
  fuelbar.dataSource = getFuelPercent

  fuelbarLabel = UIUtils.TextClass.new()
  fuelbarLabel.text = "Fuel"
  fuelbarLabel.pos.x = fuelbar.pos.x + 1
  fuelbarLabel.pos.y = fuelbar.pos.y + fuelbar.height + 1
  fuelbarLabel.textColor = colors.white
  fuelbarLabel.primaryColor = colors.black

  startButton.width = 20
  startButton.height = 5
  startButton.secondaryColor = colors.blue
  startButton.textColor = colors.white
  startButton.primaryColor = colors.yellow
  startButton.pos.x = ((monw - (fuelbar.width + 3)) / 2) - (startButton.width / 2)
  startButton.pos.y = monh / 2 - startButton.height / 2
  startButton.text = "Start"
  startButton.onClick = setCastUI
  startButton.data = 1

  craftingProgressbar.width = monw - 3
  craftingProgressbar.pos.x = 2
  craftingProgressbar.pos.y = monh - 4
  craftingProgressbar.height = 2
  craftingProgressbar.dataSource = getCraftingProgress

  craftingTextLabel.text = "Crafting Progress"
  craftingTextLabel.primaryColor = colors.black
  craftingTextLabel.textColor = colors.white
  craftingTextLabel.pos.x = (monw / 2) - (#craftingTextLabel.text / 2)
  craftingTextLabel.pos.y = monh - 5

  craftingProgressbarLabel.text = getCraftingProgressText()
  craftingProgressbarLabel.dataSource = getCraftingProgressText
  craftingProgressbarLabel.primaryColor = colors.black
  craftingProgressbarLabel.textColor = colors.white
  craftingProgressbarLabel.pos.y = monh

  breakdownLabel.text = "Breakdown:"
  breakdownLabel.pos.x = 2
  breakdownLabel.pos.y = 3
  breakdownLabel.primaryColor = colors.black
  breakdownLabel.textColor = colors.white

  liquidLabel.text = "Fluid: calculating..."
  liquidLabel.setPos(3,4)
  liquidLabel.primaryColor = colors.black
  liquidLabel.textColor = colors.white
  liquidLabel.dataSource = function () return "Fluid: " .. current.breakdown.fluid .. "MB" end

  meltLabel.text = "Items: calculating..."
  meltLabel.setPos(3,5)
  meltLabel.primaryColor = colors.black
  meltLabel.textColor = colors.white
  meltLabel.dataSource = function () return "Items: " .. current.breakdown.melt .. "MB" end

  alloyLabel.text = "Alloy: calculating..."
  alloyLabel.setPos(3,6)
  alloyLabel.primaryColor = colors.black
  alloyLabel.textColor = colors.white
  alloyLabel.dataSource = function () return "Alloy: " .. current.breakdown.alloy .. "MB" end

  programLog.primaryColor = colors.black
  programLog.textColor = colors.white
  programLog.height = monh - 11
  programLog.width = 25
  programLog.setPos(monw - programLog.width - 1, 3)
end

--code
setupPeripherals() -- function that connects the periperals
setupUIObjects()
term.clear()
term.setCursorPos(1,1)
print("Auto-Forge V1.0")

startUI = UIUtils.UIClass.new()
startUI.addObject(startButton)
startUI.addObject(fuelbar)
startUI.addObject(fuelbarLabel)

amountUI = generateAmountUI()

craftingUI = UIUtils.UIClass.new()
craftingUI.addObject(navBar)
craftingUI.addObject(craftingProgressbar)
craftingUI.addObject(craftingTextLabel)
craftingUI.addObjects({breakdownLabel, liquidLabel, meltLabel, alloyLabel})
craftingUI.addObject(programLog)
craftingUI.addObject(craftingProgressbarLabel)

current.UI = startUI

function redrawMonitor ()
  while true do
    drawCurrentUI()
    os.sleep(refreshRate)
  end
end

function handleMonitor ()
  while true do
      event, side, x, y = os.pullEvent("monitor_touch")
      current.UI.handler(current.UI, event, side, x, y)
  end
end

--craft(casts.ingot, metals.pigiron, 4)

parallel.waitForAll(redrawMonitor, handleMonitor)
