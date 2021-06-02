--variables

confFile  = "altar.conf" -- config file location. used to save info on the crafting mode and which recipe to craft
delay = 0.5 -- delay between crafts

--extra blood needed in altar to craft (lag may cause it to insert item too soon otherwise)
--set this to 0 if using max altar capacity and cannot add runes of capacity
threshold = 100

enableMonitor = true -- set to false if not using monitor
enableOutput = true -- set this to true if output should go into output chest

enableOrb = true -- set to true if bloodorb should be put in altar when no crafting available
enableOrbContainer = true -- set to true if orbs have their own container

--change this to storage container used for slates / materials - use peripheral.getType(side) for the correct name
outputContainerPeripheral = "minecraft:barrel"
containerPeripheral = "minecraft:barrel"
orbContainerPeripheral = "minecraft:barrel"

--list of available recipes, feel free to add recipes make sure to use exact item names
--edit to your packs needs
slates = {
    blankSlate = {
     amount = 1229,
     item = "botania:livingrock",
     result = "bloodmagic:blankslate"
    },

    reinforcedSlate = {
     amount =  2000,
     item = "bloodmagic:blankslate",
     result = "bloodmagic:reinforcedslate"
    },

    imbuedSlate = {
     amount = 5000,
     item = "bloodmagic:reinforcedslate",
     result = "bloodmagic:infusedslate"
     },

     demonicSlate = {
      amount = 15000,
      item = "bloodmagic:infusedslate",
      result = "bloodmagic:demonslate"
     },

     etherealSlate = {
      amount = 20000,
      item = "bloodmagic:demonslate",
      result = "bloodmagic:etherealslate"
    },

    steel =  {
      amount = 1000,
      item = "minecraft:iron_ingot",
      result = "emendatusenigmatica:steel_ingot"
    },

    chargedCertusQuartz = {
      amount = 2904,
      item = "appliedenergistics2:certus_quartz_crystal",
      result = "appliedenergistics2:charged_certus_quartz_crystal"
    },

    eliteCoil = {
      amount = 2000,
      item = "mekanism:alloy_reinforced",
      result = "ironjetpacks:elite_coil"
    },

    ultimateCoil = {
      amount = 3000,
      item = "botania:terrasteel_ingot",
      result = "ironjetpacks:ultimate_coil"
    },

    photovoltaicCell = {
      amount = 2000,
      item = "solarflux:photovoltaic_cell_2",
      result  = "solarflux:photovoltaic_cell_3"
    },

    basicCoil = {
      amount = 1000,
      item = "mekanism:enriched_iron",
      result = "ironjetpacks:basic_coil"
    },

    soulSnare = {
      amount = 500,
      item = "minecraft:string",
      result = "bloodmagic:soulsnare"
    }
}

--highest priority orb should be listed first
orbs = {
  "bloodmagic:masterbloodorb",
  "bloodmagic:magicianbloodorb",
  "bloodmagic:apprenticebloodorb",
  "bloodmagic:weakbloodorb"
}

-------------------------------------------------------------------------------

--- DO NOT EDIT BEYOND THIS POINT

--------------------------------------------------------------------------------

--default slate
currentSlate = "blankSlate"

craftingModes = {"Any", "Recursive", "Exact"}
currentCraftingMode = craftingModes[1]

altar = nil
monitor = nil
chest = nil
outputChest = nil
orbChest = nil

--lists of buttons on monitor
slateButtons = {}
craftButtons = {}

-- button API / object -- very messy needs a rewrite as im too dumb for OOP

Button = {
  text  = "",
  data  = "",
  pos = {
    x = 0,
    y = 0,
  },
  width = 10,
  height = 5,
  active = false,
  activeColor = colors.green,
  color = colors.red,
  textColor = colors.black
}

function Button:new (o)
  o = o or {}
  setmetatable(o,self)
  self.__index = self
  self.width = string.len(self.text) + 2
  self.height = 3
  self.color = colors.red
  self.activeColor = colors.green
  self.textColor = colors.black
  self.active = false
  self.data = ""
  self.text = ""
  self.pos = {
    x = 0,
    y = 0
  }
  return o
end

function Button:setActive (b)
  self.active = b
end

function Button:setPos(x,y)
 self.pos = {x = x, y = y}
end

function Button:setData(d)
  self.data = d
end

function Button:setWidth (w)
  self.width = w
end

function Button:setColors(c, ac, tc)
  self.color = c
  self.activeColor = ac
  self.textColor = tc
end

function Button:setHeight(h)
  self.height(h)
end

function Button:setText(t)
  self.text = t
  self.width = string.len(t) + 2
end

function Button:toggle ()
  self.active = not self.active
end

function Button:draw()
  color = self.color
  if self.active then
    color = self.activeColor
  end
  paintutils.drawFilledBox(self.pos.x, self.pos.y, self.pos.x + self.width, self.pos.y + self.height, color)
  term.setCursorPos(self.pos.x + math.floor(self.width / 2) - math.floor(string.len(self.text) / 2), self.pos.y + math.floor(self.height / 2))
  term.setTextColor(self.textColor)
  term.write(self.text)
end

function drawButtons (mon)
  if mon then
    t = term.redirect(mon)
    term.setTextColor(colors.black)
    term.clear()
    term.setCursorPos(0,0)
    monw, monh = mon.getSize()
    paintutils.drawFilledBox(0,0,monw, monh, colors.black)

    for k,v in pairs(slateButtons) do
      v:draw()
    end

    for k,v in pairs(craftButtons) do
      v:draw()
    end

    term.redirect(t)
  end
end

--functions

--sets the current slate to config
function writeToConfig ()
    file = io.open(confFile,"w")
    file:write ("currentSlate:" .. currentSlate .. "\n")
    file:write ("currentMode:" .. currentCraftingMode .. "\n")
    file:close()
end

--reads the current slate form config
function readFromConfig ()
    file = fs.open(confFile, "r")
    config = {}

    --generate first time file
    if not file then
      writeToConfig()
      file = fs.open(confFile, "r")
    end

    for line in file.readLine do
        for k, v in string.gmatch(line, "(%w+):(%w+)") do
          config[k] = v
        end
    end
    file:close()
    currentSlate = config["currentSlate"]
    currentCraftingMode = config["currentMode"]
end

--changes the slate type and updates the config
function setSlate (slate)
  currentSlate = slate
  term.setTextColor(colors.blue)
  term.write("Setting recipe to: ")
  term.setTextColor(colors.white)
  print(slate)
  writeToConfig()
end

function setCraftMode (mode)
  currentCraftingMode = mode
  term.setTextColor(colors.blue)
  term.write("setting craftingMode to: ")
  term.setTextColor(colors.white)
  print(mode)
  writeToConfig()
end

--checks if peripheral is already in use
function isInUse (side)
  if (chest and side == peripheral.getName(chest)) or
     (outputChest and side == peripheral.getName(outputChest)) or
     (altar and side == peripheral.getName(altar)) or
     (monitor and side == peripheral.getName(monitor)) or
     (orbChest and side == peripheral.getName(orbChest)) then
    return true
  else
    return false
  end
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

    print("Cannot find periperheral: " .. name)
    return nil
end

--connects all needed peripherals - prioritizes non networked peripherals
function setupPeripherals ()
  altar = wrapPeripheral("bloodmagic:altar")
  chest = wrapPeripheral(containerPeripheral)

  if enableMonitor then
    monitor = wrapPeripheral("monitor")
  end

  if enableOutput then
    outputChest = wrapPeripheral(outputContainerPeripheral)
  end

  if enableOrb and enableOrbContainer then
    orbChest = wrapPeripheral(orbContainerPeripheral)
  end
end

--returns a peripheral handler
function wrapPeripheral (name)
  p = detectPeripheral(name)
  if p then
    return peripheral.wrap(p)
  else
    return nil
  end
end

--finds item in chest
function findItem(container, item)
  for k,v in pairs(container.list()) do
    if v["name"] == item then
      return k
    end
  end
end

--checks if there are any orbs available
function findOrb(container)
  for k,v in pairs(orbs) do
    if findItem(container, v) then
      return v
    end
  end
end

function hasNoItemsToCraft ()
  for k,v in pairs(slates) do
    if hasItemForCraft(v) then
      return false
    end
  end
  return true
end

function pullOrbFromAltar ()
  local o = findOrb(altar)
  if o then
    if enableOrbContainer then
      altar.pushItems(peripheral.getName(orbChest), findItem(altar, o), 1)
    else
      altar.pushItems(peripheral.getName(chest),findItem(altar, o),1)
    end
  end
end

function insertOrbInAltar ()
  if enableOrbContainer then
    if findOrb(orbChest) then
      orbChest.pushItems(peripheral.getName(altar), findItem(orbChest, findOrb(orbChest)),1)
    end
  else
    if findOrb(chest) then
      chest.pushItems(peripheral.getName(altar), findItem(chest, findOrb(chest)),1)
    end
  end
end

--inserts item into altar
function insertItemToAltar (item, amount)
  chest.pushItems(peripheral.getName(altar), findItem(chest, item), amount)
end

--removes item from altar
function pullItemFromAltar (item, amount)
  if enableOutput and (currentCraftingMode == craftingModes[1] or item == slates[currentSlate]["result"]) then
    altar.pushItems(peripheral.getName(outputChest), findItem(altar, item), amount)
  else
    altar.pushItems(peripheral.getName(chest),findItem(altar, item),amount)
  end
end

--returns the amount of blood in altar
function getBlood ()
  t = altar.tanks()
  if table.getn(t) > 0 then
    if t[1] then
      return t[1]["amount"]
    end
  end
  return 0;
end

--checks if item and blood to craft recipe
function canCraft(slate)
  if findItem(chest, slate["item"]) and getBlood() >= (slate["amount"] + threshold) then
    return true
  else
    return false
  end
end

--checks if the item needed for recipe is available in chest
function hasItemForCraft (slate)
  if findItem(chest, slate["item"]) then
    return true
  else
    return false
  end
end

--checks the list of slates for available item
function findCraftRequirement (slate)
  for k,v in pairs(slates) do
    if v["result"] == slate["item"] then
      return v
    end
  end
  return nil
end

--attempts to craft a recipe, and if not possible attempts to craft needed items
function craftRecursive (slate)
  if hasItemForCraft(slate) then
    craft(slate)
  else
    requirement = findCraftRequirement(slate)
    if requirement then
      craftRecursive(requirement)
    end
  end
end

--crafts a specific recipe
function craft(slate)
  if canCraft(slate) then
    --inserts the item
    insertItemToAltar(slate["item"],1)
    --crafting
    term.setTextColor(colors.green)
    term.write("crafting: ")
    term.setTextColor(colors.white)
    print(slate["result"])

    done = false
    while not done do
      if findItem(altar, slate["result"]) then
        done = true
      else
        os.sleep(1)
      end
    end
    --extract result
    pullItemFromAltar(slate["result"],1)
    return true
  else
    return false
  end
end

--checks the list for any available crafts
function craftAny()
  for k,v in pairs (slates) do
    if canCraft(v) then
      craft(v)
      break
    end
  end
end

--setup function
function setup()
  readFromConfig()
  setupPeripherals()

  term.clear()
  term.setCursorPos(1,1)
  term.setTextColor(colors.red)
  print("--- Auto-altar V1.0 ---")
  term.setTextColor(colors.yellow)
  term.write("InputChest side: ")
  term.setTextColor(colors.white)
  term.write(peripheral.getName(chest) .. " ")
  if enableOutput then
    term.setTextColor(colors.yellow)
    term.write("OutputChest side: ")
    term.setTextColor(colors.white)
    print(peripheral.getName(outputChest))
  else
    print("")
  end

  if enableOrbContainer then
    term.setTextColor(colors.yellow)
    term.write("orbchest side: ")
    term.setTextColor(colors.white)
    print(peripheral.getName(orbChest))
  end

  -- only generate the buttons if the monitor is enabled
  if enableMonitor then
    generateSlateButtons()
    generateCraftingButtons()
    drawButtons(monitor)
  end
end

function generateSlateButtons ()
  monWidth, monHeight = monitor.getSize()
  x = 0
  y = 0

  for k,v in pairs(slates) do
    b = Button:new()
    b:setPos(x,y)
    b:setText(string.sub(k,1,5))
    x = x + b.width + 2

    if x > monWidth then
      y = y + b.height + 2
      x  = 0 + b.width + 2
      b:setPos(0,y)
    end

    if k == currentSlate then
      b:setActive(true)
    end

    b:setData(k)
    table.insert(slateButtons, b)
  end
end

function generateCraftingButtons ()
  monX, monY = monitor.getSize()

  x = 6
  y = monY - 1

  for k,v in pairs(craftingModes) do
    b = Button:new()
    b:setColors(colors.yellow, colors.blue, colors.black)
    b:setText(v)
    b:setPos(x,y)
    b:setData(v)
    b.height = 1
    x = x + b.width + 2

    if v == currentCraftingMode then
      b:setActive(true)
    end

    table.insert(craftButtons, b)
  end
end

function handleCrafting ()
  while true do
    if hasNoItemsToCraft() and enableOrb then
      if not findOrb(altar) then
        insertOrbInAltar()
      end
    else
      if enableOrb and findOrb(altar) then
        pullOrbFromAltar()
      end
      if currentCraftingMode == craftingModes[1] then
        craftAny()
      elseif currentCraftingMode == craftingModes[2] then
        craftRecursive(slates[currentSlate])
      elseif currentCraftingMode == craftingModes[3] then
        craft(slates[currentSlate])
      end
      os.sleep(delay)
    end
  end
end

function handleMonitor ()
  while true do
    event, side, x, y = os.pullEvent("monitor_touch")
    for k,v in pairs (slateButtons) do
      if x >= v.pos.x and x <= v.pos.x + v.width and y >= v.pos.y and y <= v.pos.y + v.height then
        setSlate(v.data)
        v:setActive(true)
        for k2,v2 in pairs(slateButtons) do
          if not (k2 == k) then
            v2:setActive(false)
          end
        end
        break
      end
    end

    for k,v in pairs (craftButtons) do
      if x >= v.pos.x and x <= v.pos.x + v.width and y >= v.pos.y and y <= v.pos.y + v.height then
        setCraftMode(v.data)
        v:setActive(true)
        for k2,v2 in pairs(craftButtons) do
          if not (k2 == k) then
            v2:setActive(false)
          end
        end
        break
      end
    end

    drawButtons(monitor)
  end
end

--code

--setup the program
setup()

if enableMonitor then
  --run the 2 main loops at the same time
  parallel.waitForAll(handleMonitor, handleCrafting)
else
  --do not run monitor loop if its not enabled
  handleCrafting()
end
