--TO DO

--[[
 CREATE an advanced mode that can handle crafting larger stack sizes (e.g 16 slates at once)

 Calculate LP drain per item
 Calculate LP gain in altar
 Calculate crafting speed
 calculate max stack size for requested item
]]

--variables

confFile  = "altar.conf" -- config file location. used to save info on the crafting mode and which recipe to craft
recipeFile = "slates.conf" -- file which holds all recipes

delay = 0.1 -- delay between crafts /  checks
enableAdvancedMode = true

-- your current altar setup -- currently only used in advanced mode except for the capacity runes which are used for the bloodbar
altarRunes = {
  Capacity = 4,
  AugmentedCapacity = 0,
  Sacrifice = 0,
  SelfSacrifice = 0,
  Speed = 0,
  Acceleration = 0,
  Charging = 0,
  Displacement = 0,
  Orb = 0
}

--extra blood needed in altar to craft (lag may cause it to insert item too soon otherwise)
--set this to 0 if using max altar capacity and cannot add runes of capacity
threshold = 100
altarBaseCapacity = 10000

enableMonitor = true -- set to false if not using monitor
enableOutput = true -- set this to true if output should go into output chest rather then back into the input chest
enableOrbContainer = true -- set to true if orbs have their own container

--change this to storage container used for slates / materials - use peripheral.getType(side) for the correct name
outputContainerPeripheral = "minecraft:barrel" -- altar output items
containerPeripheral = "minecraft:barrel" -- main input
orbContainerPeripheral = "minecraft:barrel" -- container for storing orbs

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

    lifeBucket = {
        amount = 1000,
        item = "minecraft:bucket",
        result = "bloodmagic:life_essence_bucket"
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

     Weakcrystal = {
         amount = 10000,
         item = "bloodmagic:lavacrystal",
         result = "bloodmagic:activationcrystalweak"
     },

     Water = {
         amount = 1000,
         item = "minecraft:lapis_block",
         result = "bloodmagic:waterscribetool"
     },

     Earth = {
         amount = 1000,
         item = "minecraft:obsidian",
         result = "bloodmagic:earthscribetool"
     },

     Air = {
         amount = 1000,
         item = "minecraft:ghast_tear",
         result = "bloodmagic:airscribetool"
     },

     Fire = {
         amount = 1000,
         item = "minecraft:magma_cream",
         result = "bloodmagic:firescribetool"
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

    chargedCertusQuartzAE2 = {
      amount = 2904,
      item = "appliedenergistics2:certus_quartz_crystal",
      result = "appliedenergistics2:charged_certus_quartz_crystal"
    },

    chargedCertusQuartzEnig = {
      amount = 2904,
      item = "emendatusenigmatica:certus_quartz_gem",
      result = "emendatusenigmatica:charged_certus_quartz_gem"
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
    },


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

os.loadAPI("API/UIUtils.lua")
os.loadAPI("API/itemUtils.lua")
os.loadAPI("API/peripheralUtils.lua")

--default slate
currentSlate = "blankSlate"

craftingModes = {"Any", "Recursive", "Exact"}
currentCraftingMode = craftingModes[1]

altarCapacity =  math.floor(((1 + 0.20 * altarRunes.Capacity) * math.pow(1.1, altarRunes.AugmentedCapacity * math.pow(0.99, math.abs(altarRunes.AugmentedCapacity - altarRunes.Capacity)))) * altarBaseCapacity)

altar = nil
monitor = nil
chest = nil
outputChest = nil
orbChest = nil

--lists of buttons on monitor
pageSize = 9

paused = false
enableOrb = true -- set to true if bloodorb should be put in altar when no crafting available


UI = UIUtils.UIClass.new()
CalibrateUI = UIUtils.UIClass.new()

altarLog = UIUtils.LogClass.new()
navBar = UIUtils.NavbarClass.new()
nextButton = UIUtils.ButtonClass.new()
previousButton = UIUtils.ButtonClass.new()

calibrationProgressBar = UIUtils.ProgressBarClass.new()
calibrationLabel = UIUtils.TextClass.new()
calibrationSelectButton = UIUtils.ButtonClass.new()

pauseButton = UIUtils.ButtonClass.new()
pauseText = UIUtils.TextClass.new()

orbButton = UIUtils.ButtonClass.new()

currentUI = UI

--sets the current slate to config
function writeToConfig ()
    file = io.open(confFile,"w")
    file:write ("currentSlate:" .. currentSlate .. "\n")
    file:write ("currentMode:" .. currentCraftingMode .. "\n")
    file:write ("paused:" .. tostring(paused) .. "\n")
    file:write ("orbMode:" .. tostring(enableOrb) .. "\n")
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
    paused = (config["paused"] == "true")
    enableOrb = (config["orbMode"] == "true")
    if not currentCraftingMode then currentCraftingMode = craftingModes[1] end
    if not currentSlate then currentSlate = "blankSlate" end
end

--changes the slate type and updates the config
function setSlate (slate)
  currentSlate = slate
  term.setTextColor(colors.blue)
  term.write("Setting recipe to: ")
  if enableMonitor then
    altarLog.addMessage("Set recipe: " .. slate, 4)
    navBar.options[2] = slate
  end
  term.setTextColor(colors.white)
  print(slate)
  writeToConfig()
end

function setCraftMode (mode)
  currentCraftingMode = mode
  term.setTextColor(colors.blue)
  term.write("setting craftingMode to: ")
  if enableMonitor then
    altarLog.addMessage("Set mode:  " .. mode, 4)
    navBar.options[1] = mode
  end
  term.setTextColor(colors.white)
  print(mode)
  writeToConfig()
end

function setupPeripherals()
  altar = peripheralUtils.wrapPeripheral("bloodmagic:altar", true)
  chest = peripheralUtils.wrapPeripheral(containerPeripheral, true)
  if enableMonitor then
    monitor = peripheralUtils.wrapPeripheral("monitor", true)
  end
  if enableOutput then
    outputChest = peripheralUtils.wrapPeripheral(outputContainerPeripheral, true)
  end
  if enableOrb and enableOrbContainer then
    orbChest = peripheralUtils.wrapPeripheral(orbContainerPeripheral, true)
  end
end

--checks if there are any orbs available
function findOrb(container)
  for k,v in pairs(orbs) do
    if itemUtils.findItem(container, v) then
      return v
    end
  end
end

function hasNoItemsToCraft ()
  if currentCraftingMode == craftingModes[1] then
    for k,v in pairs(slates) do
      if hasItemForCraft(v) then
        return false
      end
    end
    return true
  elseif currentCraftingMode == craftingModes[2] then
    if itemUtils.findItem(chest, slates[currentSlate]["item"]) then
      return false
    else
      r = findCraftRequirement(slates[currentSlate])
      while r do
        slot = itemUtils.findItem(chest, r["item"])
        if slot then
          return false
        else
          r = findCraftRequirement(r)
        end
      end
    end
  elseif currentCraftingMode == craftingModes[3] then
    if itemUtils.findItem(chest, slates[currentSlate]["item"]) then
      return false
    end
  else
    return true
  end
  return true
end

function pullOrbFromAltar ()
  local o = findOrb(altar)
  if o then
    if enableOrbContainer then
      itemUtils.pushItems(altar, orbChest, itemUtils.findItem(altar, o),1)
    else
      itemUtils.pushItems(altar, chest, itemUtils.findItem(altar, o),1)
    end
  end
end

function insertOrbInAltar ()
  if enableOrbContainer then
    if findOrb(orbChest) then
      itemUtils.pushItems(orbChest, altar,itemUtils.findItem(orbChest, findOrb(orbChest)),1)
    end
  else
    if findOrb(chest) then
      itemUtils.pushItems(chest, altar,itemUtils.findItem(chest, findOrb(chest)),1)
    end
  end
end

--inserts item into altar
function insertItemToAltar (item, amount)
  itemUtils.pushItems(chest, altar,  itemUtils.findItem(chest, item), amount)
end

--removes item from altar
function pullItemFromAltar (item, amount, isRecursive)
  if enableOutput and ((currentCraftingMode == craftingModes[1] or item == slates[currentSlate]["result"]) or not isRecursive) then
    itemUtils.pushItems(altar, outputChest, itemUtils.findItem(altar, item), amount)
  else
    itemUtils.pushItems(altar, chest, itemUtils.findItem(altar, item), amount)
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
  if itemUtils.findItem(chest, slate["item"]) and getBlood() >= (slate["amount"] + threshold) then
    return true
  else
    return false
  end
end

--checks if the item needed for recipe is available in chest
function hasItemForCraft (slate)
  if itemUtils.findItem(chest, slate["item"]) then
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
function craftRecursive (slate, isRecursive)
  if hasItemForCraft(slate) then
    craft(slate, isRecursive)
  else
    requirement = findCraftRequirement(slate)
    if requirement then
      craftRecursive(requirement, true)
    end
  end
end

--crafts a specific recipe
function craft(slate, isRecursive)
  if canCraft(slate) then
    --inserts the item

    insertItemToAltar(slate["item"],1)
    local startTime = os.time()
    --crafting
    term.setTextColor(colors.green)
    term.write("crafting: ")
    if enableMonitor then
      altarLog.addMessage("Crafting: " .. slate["result"],1)
    end
    term.setTextColor(colors.white)
    print(slate["result"])

    done = false
    local endTime = startTime
    while not done do
      if itemUtils.findItem(altar, slate["result"]) then
        done = true
        endTime = os.time()
      else
        os.sleep(delay)
      end
    end
    --extract result
    pullItemFromAltar(slate["result"],1, isRecursive)
    if enableMonitor then
      altarLog.addMessage("Finished crafting: " .. slate["result"], 3)
    end
    --print(endTime - startTime)
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

function handleCrafting ()
  while true do
    if not paused then
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
    else
      os.sleep(refreshRate)

    end

  end
end

function getTableSize (t)
  local s = 0
  for k,v in pairs(t) do
    s = s + 1
  end
  return s
end

function getMCTicks ()
  return (os.time() * 1000 + 18000)%24000
end

function calibrateBloodGain ()
  paused = true
  pauseButton.active = paused

  local startingBlood = getBlood()
  local prevTicks = getMCTicks()
  local ticksPassed = 0
  local calibrating = true
  local maxCalibrationDuration = 60 * 20

  calibrationProgressBar.visible = true
  calibrationLabel.visible = true

  while calibrating do
    local bloodAmount = getBlood()
    if bloodAmount >= altarCapacity or ticksPassed >= maxCalibrationDuration then
      calibrating = false
    end

    local altarFilled = bloodAmount / altarCapacity
    local timepassed =  ticksPassed / maxCalibrationDuration
    if timepassed > altarFilled then
      calibrationProgressBar.data = timepassed
    else
      calibrationProgressBar.data = altarFilled
    end

    local currentTicks = getMCTicks()
    local passed = currentTicks - prevTicks
    if currentTicks < prevTicks then
      passed = currentTicks + prevTicks - 24000
    end
    ticksPassed = ticksPassed + passed
    prevTicks = currentTicks
  end

  calibrationLabel.visible = false
  calibrationProgressBar.visible = false

  return (altarCapacity - startingBlood) / ticksPassed
end

function calibrateLPConsumption (slate)

end

function toggleOrbMode ()
  enableOrb = not enableOrb
  orbButton.active = enableOrb
  writeToConfig()
  altarLog.addMessage("Set orbmode to: " .. tostring(enableOrb), 4)
  if not enableOrb and findOrb(altar) then
    pullOrbFromAltar()
  end
end

function togglePause()
  paused = not paused
  pauseButton.active = paused
  writeToConfig()
  if paused then
    altarLog.addMessage("Paused Altar", 2)
  else
    altarLog.addMessage("Resumed Altar", 3)
  end
  if paused and findOrb(altar) then
    pullOrbFromAltar()
  end
end

function setupUI ()
  local monw, monh = monitor.getSize()
  local slateButtons = UIUtils.generateButtons(monitor, getTableSize(slates), 3, 3, (monw / 2 ) - 2, monh - 3, 3,3, colors.green, colors.red, colors.black, setSlate)

  local size = getTableSize(slates)
  local current = 1

  for k,v in pairs(slates) do
    slateButtons[current].text = k
    slateButtons[current].data = k
    slateButtons[current].isRadio  = true
    slateButtons[current].radioTag = "slate"
    if k == currentSlate then
      slateButtons[current].active = true
    end
    current = current + 1
  end

  current = 1
  local craftButtons = UIUtils.generateButtons(monitor, #craftingModes, 4, monh - 1, monw - 9, monh , #craftingModes, 1, colors.orange, colors.blue, colors.white, setCraftMode )
  local size = getTableSize(craftingModes)
  for k,v in pairs(craftingModes) do
    craftButtons[current].text = v
    craftButtons[current].data = v
    craftButtons[current].page = 0
    if v == currentCraftingMode then
      craftButtons[current].active = true
    end
    craftButtons[current].isRadio = true
    craftButtons[current].radioTag = "craft"
    current = current + 1
  end

  local bloodBar = UIUtils.ProgressBarClass.new()
  bloodBar.horizontal = false
  bloodBar.width = 5
  bloodBar.height = monh - 5
  bloodBar.setPos(monw - bloodBar.width - 1, 3)
  bloodBar.dataSource = function () return getBlood() / altarCapacity end

  local bloodBarLabel = UIUtils.TextClass.new()
  bloodBarLabel.dataSource = function () return getBlood() .. "MB" end
  bloodBarLabel.text = function () return getBlood() .. "MB" end
  bloodBarLabel.setPos(monw - (#tostring(altarCapacity) + 2), monh)
  bloodBarLabel.textColor = colors.white
  bloodBarLabel.primaryColor = colors.black

  navBar.setPos(1,1)
  navBar.primaryColor = colors.black
  navBar.textColor = colors.white
  navBar.width = monw

  navBar.options[1] = currentCraftingMode
  navBar.options[2] = currentSlate
  navBar.height = 1

  altarLog.setPos(monw / 2, 2)
  altarLog.primaryColor  = colors.black
  altarLog.textColor = colors.white
  altarLog.height = monh - 6
  altarLog.width = monw / 2 - 8

  nextButton.width = 1
  nextButton.height = 2
  nextButton.setPos(monw / 2 -1 ,(monh / 2) - (nextButton.height / 2))
  nextButton.text = ">>"
  nextButton.secondaryColor = colors.black
  nextButton.textColor= colors.white
  if getTableSize(slates) <= pageSize then
    nextButton.visible = false
  end
  nextButton.onClick = function ()  UI.page = UI.page + 1 if UI.page >= math.ceil(getTableSize(slates) / pageSize) then nextButton.visible=false end if UI.page ~= 1 then previousButton.visible = true end end

  previousButton.width = 1
  previousButton.height = 2
  previousButton.setPos(1 ,(monh / 2) - (previousButton.height / 2))
  previousButton.text = "<<"
  previousButton.secondaryColor = colors.black
  previousButton.textColor= colors.white
  if UI.page == 1 then
    previousButton.visible = false
  end
  previousButton.onClick = function () UI.page = UI.page - 1 if UI.page == 1 then previousButton.visible = false end if  UI.page < math.ceil(getTableSize(slates) / pageSize) then nextButton.visible=true end end

  orbButton.width = 5
  orbButton.active = enableOrb
  orbButton.height = 0
  orbButton.text = "orb"
  orbButton.primaryColor = colors.orange
  orbButton.secondaryColor = colors.blue
  orbButton.textColor = colors.white
  orbButton.setPos(monw - orbButton.width -1,1 )
  orbButton.visible = true
  orbButton.onClick = toggleOrbMode

  pauseButton.width = 6
  pauseButton.active = paused
  pauseButton.height = 0
  pauseButton.text = "pause"
  pauseButton.primaryColor = colors.orange
  pauseButton.secondaryColor = colors.blue
  pauseButton.textColor = colors.white
  pauseButton.setPos(monw - pauseButton.width - 8,1 )
  pauseButton.visible = true
  pauseButton.onClick = togglePause

  UI.addObject(navBar)
  UI.addObject(altarLog)
  UI.addObject(bloodBarLabel)
  UI.addObject(bloodBar)
  UI.addObjects(slateButtons)
  UI.addObjects(craftButtons)
  UI.addObject(previousButton)
  UI.addObject(nextButton)
  UI.addObject(orbButton)
  UI.addObject(pauseButton)
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
  print(peripheral.getName(chest))

  if enableOutput then
    term.setTextColor(colors.yellow)
    term.write("OutputChest side: ")
    term.setTextColor(colors.white)
    print(peripheral.getName(outputChest))
  end

  if enableOrbContainer then
    term.setTextColor(colors.yellow)
    term.write("orbchest side: ")
    term.setTextColor(colors.white)
    print(peripheral.getName(orbChest))
  end
end

function handleMonitor ()
  while true do
      event, side, x, y = os.pullEvent("monitor_touch")
      UI.handler(UI, event, side, x, y, UI.page)
  end
end

function redrawMonitor ()
  while true do
    UI.update()
    local prev = term.redirect(monitor)
    term.setBackgroundColor(colors.black)
    term.clear()
    UI.draw()
    term.redirect(prev)
    os.sleep(refreshRate)
  end
end

setup()

if enableMonitor then
  setupUI()
  UI.page = 1
  parallel.waitForAll(redrawMonitor, handleMonitor, handleCrafting)
else
  handleCrafting()
end
