--load apis
local apis = {
  "tableUtils.lua",
  "peripheralUtils.lua",
  "itemUtils.lua",
	"UIUtils.lua",
  "wave.lua"
}

for _, api in ipairs(apis) do
	if not _G[api] then
		if not os.loadAPI("API/" .. api) then
			error("could not load API: "..api)
		end
	end
end

--Globals

chestName = "minecraft:barrel"
brewingstand = "minecraft:brewing_stand"
output = "botania:open_crate"
filling = "minecraft:dispenser"
redstoneP = "redstoneIntegrator"
monitorP = "monitor"

storage = {}
stands = {}

standMonitorSize = {29,19}
orderMonitorSize = {29,26}

standsMatchingMonitors = { }
standsMatchingMonitors["minecraft:brewing_stand_6"] = "monitor_6"
standsMatchingMonitors["minecraft:brewing_stand_7"] = "monitor_5"
standsMatchingMonitors["minecraft:brewing_stand_3"] = "monitor_4"

standMonitors = {}
orderMonitors = {}

outputPeripheral = nil
fillingPeripheral = nil
redstonePeripheral = nil

mainMonitor = nil

bottle = "minecraft:glass_bottle"
waterBottle = "minecraft:potion"

fuel = "minecraft:blaze_powder"
base = "minecraft:nether_wart"
extension = "minecraft:redstone"
empower = "minecraft:glowstone_dust"
splash = "minecraft:gunpowder"
linger = "minecraft:dragon_breath"

ingredients = {
  resistance = {"minecraft:shulker_shell"},
  strength = {"minecraft:blaze_powder"},
  fireResistance = {"minecraft:magma_cream"},
  regeneration = {"minecraft:ghast_tear"},
  healing = {"minecraft:glistering_melon_slice"},
  nightVision = {"minecraft:golden_carrot"},
  jumping = {"minecraft:rabbit_foot"},
  damage = {"minecraft:glistering_melon_slice", "minecraft:fermented_spider_eye"},
  speed = {"minecraft:sugar"},
  breathing = {"minecraft:pufferfish"},
  invisibility = {"minecraft:golden_carrot", "minecraft:fermented_spider_eye"}
}

fillingStationInUse = false

validPotionColors = {
  colors.red,
  colors.purple,
  colors.green,
  colors.lime,
  colors.magenta,
  colors.orange,
  colors.pink,
  colors.cyan
}

orderQueue = tableUtils.Queue.new()
brewingQueue = tableUtils.Queue.new()

waveInstance = wave.new()

musicTracks = {
  "rondo2.nbs",
  "highwayToHell.nbs",
  "bhc.nbs",
  "sandstorm.nbs",
  "tetris.nbs"
}

musicPlayerContext = waveInstance.createContext()

function getOrderMonitor (mon)
  for k,v in pairs(orderMonitors) do
    if peripheral.getName(v) == mon then
      return v
    end
  end
  return nil
end

--UI elements
function generateOrderUI (mon)
  local mainUI = UIUtils.UIClass.new()

  local monitorName = peripheral.getName(mon)

  local startOrderButton = UIUtils.ButtonClass.new()
  startOrderButton.pos.x = 7
  startOrderButton.pos.y = 23
  startOrderButton.text = "Request potion"
  startOrderButton.secondaryColor = colors.green
  startOrderButton.width = 16
  startOrderButton.height = 2
  startOrderButton.data = monitorName
  startOrderButton.onClick = function (data) resetOrderUI(data) local m = getOrderMonitor(data) m.currentUI = m.orderUI end

  local UIOrderQueue = UIUtils.QueueClass.new()
  UIOrderQueue.dataSource = orderQueue.getQueue
  UIOrderQueue.pos.x = 2
  UIOrderQueue.pos.y = 2
  UIOrderQueue.textColor = colors.purple
  UIOrderQueue.primaryColor = colors.gray
  UIOrderQueue.secondaryColor = colors.black
  UIOrderQueue.width = 27
  UIOrderQueue.height = 11

  local UIBrewingQueue = UIUtils.QueueClass.new()
  UIBrewingQueue.dataSource = brewingQueue.getQueue
  UIBrewingQueue.pos.x = 2
  UIBrewingQueue.pos.y = 15
  UIBrewingQueue.width = 27
  UIBrewingQueue.height = 5
  UIBrewingQueue.textColor = colors.orange
  UIBrewingQueue.primaryColor = colors.gray
  UIBrewingQueue.secondaryColor = colors.black

  local brewingQueueLabel = UIUtils.TextClass.new()
  brewingQueueLabel.text = "Brewing:"
  brewingQueueLabel.pos.x = 2
  brewingQueueLabel.pos.y = 14
  brewingQueueLabel.textColor = colors.white
  brewingQueueLabel.primaryColor = colors.black

  local orderQueueLabel = UIUtils.TextClass.new()
  orderQueueLabel.text = "In Queue:"
  orderQueueLabel.pos.x = 2
  orderQueueLabel.pos.y = 1
  orderQueueLabel.primaryColor = colors.black
  orderQueueLabel.textColor = colors.white

  mainUI.addObject(UIOrderQueue)
  mainUI.addObject(UIBrewingQueue)
  mainUI.addObject(startOrderButton)
  mainUI.addObject(orderQueueLabel)
  mainUI.addObject(brewingQueueLabel)

  local orderUI = UIUtils.UIClass.new()

  local cancelOrderButton = UIUtils.ButtonClass.new()
  cancelOrderButton.text = "cancel"
  cancelOrderButton.width = 11
  cancelOrderButton.height = 2
  cancelOrderButton.pos.x = 2
  cancelOrderButton.pos.y = 23
  cancelOrderButton.onClick = function (data) resetOrderUI(data) local m = getOrderMonitor(data) m.currentUI = m.mainUI end
  cancelOrderButton.data = monitorName

  local submitOrderButton = UIUtils.ButtonClass.new()
  submitOrderButton.text = "Confirm"
  submitOrderButton.width = 11
  submitOrderButton.height = 2
  submitOrderButton.pos.x = 16
  submitOrderButton.pos.y = 23
  submitOrderButton.secondaryColor = colors.green
  submitOrderButton.onClick = submitCurrentOrder
  submitOrderButton.data = monitorName

  local empowerPotionButton = UIUtils.ButtonClass.new()
  empowerPotionButton.text = "Empowered"
  empowerPotionButton.width = 11
  empowerPotionButton.height = 2
  empowerPotionButton.pos.x = 16
  empowerPotionButton.pos.y = 19
  empowerPotionButton.secondaryColor = colors.gray
  empowerPotionButton.primaryColor = colors.lightGray
  empowerPotionButton.isRadio = true
  empowerPotionButton.data = "empowered"
  empowerPotionButton.radioTag = "potionEmpowerType"
  empowerPotionButton.setTag("potionEmpowerType")

  local extendPotionButton = UIUtils.ButtonClass.new()
  extendPotionButton.text = "Extended"
  extendPotionButton.width = 11
  extendPotionButton.height = 2
  extendPotionButton.pos.x = 2
  extendPotionButton.pos.y = 19
  extendPotionButton.data = "extended"
  extendPotionButton.secondaryColor = colors.gray
  extendPotionButton.primaryColor = colors.lightGray
  extendPotionButton.isRadio = true
  extendPotionButton.radioTag = "potionEmpowerType"
  extendPotionButton.setTag("potionEmpowerType")

  local splashPotionButton = UIUtils.ButtonClass.new()
  splashPotionButton.text = "Splash"
  splashPotionButton.width = 11
  splashPotionButton.height = 2
  splashPotionButton.pos.x = 16
  splashPotionButton.pos.y = 15
  splashPotionButton.data = "splash"
  splashPotionButton.secondaryColor = colors.gray
  splashPotionButton.primaryColor = colors.lightGray
  splashPotionButton.isRadio = true
  splashPotionButton.radioTag = "potionThrowType"
  splashPotionButton.setTag("potionThrowType")

  local lingeringPotionButton = UIUtils.ButtonClass.new()
  lingeringPotionButton.text = "Lingering"
  lingeringPotionButton.width = 11
  lingeringPotionButton.height = 2
  lingeringPotionButton.pos.x = 2
  lingeringPotionButton.pos.y = 15
  lingeringPotionButton.data = "lingering"
  lingeringPotionButton.secondaryColor = colors.gray
  lingeringPotionButton.primaryColor = colors.lightGray
  lingeringPotionButton.isRadio = true
  lingeringPotionButton.radioTag = "potionThrowType"
  lingeringPotionButton.setTag("potionThrowType")

  local potionButtons = UIUtils.generateButtons(nil, tableUtils.getTableSize(ingredients), 2, 2, 28, 13, 3, 3, colors.orange, colors.purple, colors.black, nil)

  local index = 1
  for k,v in pairs(ingredients) do
    potionButtons[index].text = k
    potionButtons[index].data = v
    potionButtons[index].isRadio = true
    potionButtons[index].radioTag = "potionType"
    potionButtons[index].setTag("potionType")
    index = index + 1
  end

  local nextPageButton = UIUtils.ButtonClass.new()
  nextPageButton.text = ">"
  nextPageButton.pos.y = 6
  nextPageButton.pos.x = 28
  nextPageButton.height = 2
  nextPageButton.width = 1
  nextPageButton.secondaryColor = colors.black
  nextPageButton.textColor = colors.white
  nextPageButton.onClick = function () if orderUI.page < math.ceil(tableUtils.getTableSize(ingredients) / 9) then orderUI.page = orderUI.page + 1 end end

  local previousPageButton = UIUtils.ButtonClass.new()
  previousPageButton.text = "<"
  previousPageButton.pos.x = 1
  previousPageButton.pos.y = 6
  previousPageButton.height = 2
  previousPageButton.width = 0
  previousPageButton.secondaryColor = colors.black
  previousPageButton.textColor = colors.white
  previousPageButton.onClick = function () if orderUI.page > 1 then orderUI.page = orderUI.page - 1 end end

  orderUI.addObjects(potionButtons)
  orderUI.addObject(cancelOrderButton)
  orderUI.addObject(submitOrderButton)
  orderUI.addObject(empowerPotionButton)
  orderUI.addObject(extendPotionButton)
  orderUI.addObject(splashPotionButton)
  orderUI.addObject(lingeringPotionButton)
  orderUI.addObject(nextPageButton)
  orderUI.addObject(previousPageButton)

  return mainUI, orderUI
end

--objects

Recipe = {}
Recipe.new = function (ingredient, extended, empowered, splash, lingering)
  local self = {}

  self.ingredient = ingredient
  self.extended = extended or false
  self.empowered = empowered or false
  self.splash = splash or false
  self.lingering = lingering or false

	self.getStages = function ()
		--fillbottle
		--netherwart

		local stages = 2

    --base items
    stages = stages + #self.ingredient

		if self.extended then
			stages = stages + 1
		end

		if self.empowered then
			stages = stages + 1
		end

		if self.splash then
			stages = stages + 1
		end

		if self.lingering then
			stages = stages + 1
		end

		return stages
	end

  self.getPotionName = function ()
    local p = "potion of "
    for k,v in pairs(ingredients) do
      if v == self.ingredient then
        p =  p .. k
      end
    end

    if self.splash and not self.lingering then
      p = "Splash " .. p
    end

    if self.lingering then
      p = "Lingering " .. p
    end

    if self.extended then
      p = "Extended " .. p
    end

    if self.empowered then
      p = "Empowered " .. p
    end

    return p
  end

  return self
end

orderID = 1

Order = {}
Order.new = function (recipe)
  local self = {}
  self.ID = orderID
  orderID = orderID + 1

  self.recipe = recipe
  self.queueLabel = recipe.getPotionName()

  return self
end

Brewingstand = {}
Brewingstand.new = function (stand, monitor, UI)
  local self = {}

  self.brewingStand = stand
  self.isAvailable = true

	self.status = "Available"

	self.monitor = monitor
	self.UI = UI
	self.maxStages = 5
	self.stage = 0

	self.getProgress = function ()
		return self.stage / self.maxStages
	end

	self.getStatus = function ()
		return self.status
	end

	self.insertBottles = function ()
		for i = 1,3 do
			local c,s = findItem(waterBottle)
			itemUtils.pullItems(self.brewingStand, c, s, 1, i)
		end
	end

	self.extractBottles = function (output)
		for i = 1,3 do
			itemUtils.pushItems(self.brewingStand, output, i, 1)
		end
	end

  self.addIngredient = function (item)
    local c, s  = findItem(item)
    --(inv to pullfrom, slot to pullfrom, amount, inputslot)
		itemUtils.pullItems(self.brewingStand, c, s, 1, 4)
		self.waitForBrew()
  end

  self.addFuel = function (amount)
    amount = amount or 1
    local c, s = findItem(fuel)
		itemUtils.pullItems(self.brewingStand, c, s, 1, 5)
  end

  self.hasFuel = function ()
    return self.brewingStand.getItemDetail(5)
  end

	self.waitForBrew = function()
		--wait for brew to finish
		while self.brewingStand.getItemDetail(4) do
			os.sleep(0.1)
		end
	end

	self.setStatus = function (status)
		self.status = status

		local labels = self.UI.findObjectsWithTag("brewingLabel")
		local label = labels[1]

		local monW, monH = self.monitor.getSize()
		label.pos.x = (monW / 2) - (#self.status / 2) + 1
	end

  self.brew = function (recipe, ID)

    self.isAvailable = false
		self.stage = 0
		self.maxStages = recipe.getStages()

		--check recipe
		if checkIngredients(recipe) then

			local pani = self.UI.findObjectsWithTag("potionAnimation")
			local potionAnimation = pani[1]

			local sani = self.UI.findObjectsWithTag("sparkleAnimation")
			local sparkleAnimation = sani[1]

			local potionColor = validPotionColors[math.random(1,#validPotionColors)]

			local progressBars = self.UI.findObjectsWithTag("progressBar")
			local bar = progressBars[1]

			sparkleAnimation.visible = false
			potionAnimation.unpause()
			bar.visible = true

    --checkFuel
    	if not self.hasFuel() then
      	self.addFuel()
    	end

    	--fill water bottles
			self.setStatus("filling bottles...")
			potionAnimation.changeColor(colors.red, colors.lightBlue)
			for i = 1,3 do
				fillBottle()
			end

			self.stage = self.stage + 1

			--insert bottles
			self.insertBottles()

    	--brew base
			self.setStatus("Brewing potion base...")
			self.addIngredient(base)
			potionAnimation.changeColor(colors.lightBlue, colors.blue)
			self.stage = self.stage + 1

    	--brew potion
			self.setStatus("Brewing potion...")
      for k,v in pairs(recipe.ingredient) do
			     self.addIngredient(v)
           potionAnimation.changeColor(colors.blue, potionColor)
           self.stage = self.stage + 1
      end

			if recipe.extended or recipe.empowered or recipe.splash or recipe.lingering then
			  potionAnimation.pauseOnLastFrame = true
				sparkleAnimation.visible = true
        sparkleAnimation.unpause()
			end

			--add extras
			if recipe.extended then
				self.setStatus("Increasing potion duration...")
				self.addIngredient(extension)
				self.stage = self.stage + 1
			end

			if recipe.empowered then
				self.setStatus("Empowering potion...")
				self.addIngredient(empower)
				self.stage = self.stage + 1
			end

			if recipe.splash then
				self.setStatus("Adding explosive component...")
				self.addIngredient(splash)
				self.stage = self.stage + 1
			end

			if recipe.lingering then
				self.setStatus("Making potion effects last...")
				self.addIngredient(linger)
				self.stage = self.stage + 1
			end

    	--dispence item
			self.extractBottles(outputPeripheral)

			self.setStatus("Available")

			potionAnimation.setToOriginal()
			potionAnimation.currentFrame = 1
      potionAnimation.pause()
			sparkleAnimation.visible = false
			bar.visible = false
      sparkleAnimation.pause()

    	self.isAvailable = true
		end

    for k,v in pairs(brewingQueue.getQueue()) do
      if v.ID == ID then
        brewingQueue.list[k] = nil
      end
    end

  end

  return self
end

--functions

function generateBrewingstandUI (stand)
	local UI = UIUtils.UIClass.new()

	local potionFrames = {
	  UIUtils.ImageClass.new("empty.nfp"),
	  UIUtils.ImageClass.new("potionfilling0.nfp"),
	  UIUtils.ImageClass.new("potionfilling1.nfp"),
	  UIUtils.ImageClass.new("potionfilling2.nfp"),
	  UIUtils.ImageClass.new("potionfilling3.nfp"),
	  UIUtils.ImageClass.new("potionfilling4.nfp"),
	  UIUtils.ImageClass.new("potionfilling5.nfp"),
	  UIUtils.ImageClass.new("potionfilling6.nfp"),
	  UIUtils.ImageClass.new("potionfilling7.nfp")
	}

	local sparkleFrames = {
	  UIUtils.ImageClass.new("sparkle0.nfp"),
	  UIUtils.ImageClass.new("sparkle1.nfp"),
	  UIUtils.ImageClass.new("sparkle2.nfp"),
	  UIUtils.ImageClass.new("sparkle3.nfp"),
	  UIUtils.ImageClass.new("sparkle4.nfp"),
	}

 	local bottleImg = UIUtils.ImageClass.new("bottle.nfp")
	bottleImg.pos.x = 9
	bottleImg.pos.y = 2

	local potionAnimation = UIUtils.AnimationClass.new()
	potionAnimation.frames = potionFrames
	potionAnimation.pos.x = 9
	potionAnimation.pos.y = 2
  potionAnimation.speed = 5
	potionAnimation.setTag("potionAnimation")
  potionAnimation.pause()

	local sparkleAnimation = UIUtils.AnimationClass.new()
	sparkleAnimation.frames = sparkleFrames
	sparkleAnimation.pos.x = 9
	sparkleAnimation.pos.y = 2
  sparkleAnimation.speed = 4
  sparkleAnimation.visible = false
  sparkleAnimation.pause()
	sparkleAnimation.setTag("sparkleAnimation")

	local label = UIUtils.TextClass.new()
	label.text = "Available"
	label.primaryColor = colors.black
	label.textColor = colors.white
	label.dataSource = stand.getStatus
	label.pos.y = 17
	label.pos.x = 11
	label.setTag("brewingLabel")

	local bar = UIUtils.ProgressBarClass.new()
	bar.dataSource = stand.getProgress
	bar.pos.y = 18
	bar.pos.x = 2
	bar.width = 26
	bar.visible = false
	bar.setTag("progressBar")

	UI.addObject(bottleImg)
	UI.addObject(potionAnimation)
	UI.addObject(sparkleAnimation)
	UI.addObject(label)
	UI.addObject(bar)

	return UI
end

--checks if all ingredients are available
function checkIngredients (recipe)
	local hasIngredients = true
	if not findItem(fuel) then
		hasIngredients = false
	end

	if not findItem(base) then
		hasIngredients = false
	end

  for k,v in pairs(recipe.ingredient) do
	   if not findItem(v) then
		     hasIngredients = false
	   end
  end

	if recipe.extended then
		if not findItem(extension) then
			hasIngredients = false
		end
	end

	if recipe.empowered then
		if not findItem(empower) then
			hasIngredients = false
		end
	end

	if recipe.splash then
		if not findItem(splash) then
			hasIngredients = false
		end
	end

	if recipe.lingering then
		if not findItem(linger) then
			hasIngredients = false
		end
	end

	return hasIngredients
end

--finds an item in the storage
function findItem (item)
  for k,v in pairs(storage) do
    for s, i in pairs(v.list()) do
      if i.name == item then
        return v, s
      end
    end
  end
  return nil
end

--fills a bottle with water
function fillBottle ()
	while fillingStationInUse do
		os.sleep(0.1)
	end
	fillingStationInUse = true

	local c,s = findItem(bottle)
	itemUtils.pullItems(fillingPeripheral,c, s, 1)
	redstonePeripheral.setOutput("down", true)
	os.sleep(0.1)
	redstonePeripheral.setOutput("down", false)
	itemUtils.pushItems(fillingPeripheral, c, 1, 1)
	fillingStationInUse = false
end

--adds the order from the UI to the Queue
function submitCurrentOrder (mon)
  local R = getCurrentOrderRecipe(mon)
  if R then
    local m  = getOrderMonitor(mon)
    orderQueue.pushRight(Order.new(R))
    m.currentUI = m.mainUI
  end
end


--runs the setup
function setup()
  storage = peripheralUtils.wrapMultiplePeripherals(chestName)
  local s = peripheralUtils.wrapMultiplePeripherals(brewingstand)

  for k,v in pairs(s) do
    local b = Brewingstand.new(v)
		local ui = generateBrewingstandUI(b)
		b.UI = ui
    table.insert(stands, b)
  end

	outputPeripheral = peripheralUtils.wrapPeripheral(output)
	fillingPeripheral = peripheralUtils.wrapPeripheral(filling)
	redstonePeripheral = peripheralUtils.wrapPeripheral(redstoneP)

	local monitors = peripheralUtils.wrapMultiplePeripherals(monitorP)

	for k,v in pairs(monitors) do
		local x,y =  v.getSize()
	     if x == orderMonitorSize[1] and y == orderMonitorSize[2] then
         table.insert(orderMonitors, v)
       elseif x == standMonitorSize[1] and y == standMonitorSize[2] then
         table.insert(standMonitors, v)
       end
	  end

  for k,v in pairs(standMonitors) do
    for k2, v2 in pairs (stands) do
       if standsMatchingMonitors[peripheral.getName(v2.brewingStand)] == peripheral.getName(v) then
         v2.monitor = v
       end
    end
  end

  for k,v in pairs(orderMonitors) do
    local mainUI, orderUI = generateOrderUI(v)

    v.mainUI = mainUI
    v.orderUI = orderUI
    v.currentUI = mainUI

  end

  musicPlayerContext:addOutputs(waveInstance.scanOutputs())

  for k,v in pairs (musicTracks) do
    musicTracks[k] = waveInstance.loadTrack(v)
    musicPlayerContext:addInstance(musicTracks[k],1, false, false)
  end

end

function runUI ()
	while true do
    for k,v in pairs(stands) do
      v.UI.update()
    end

    for k,v in pairs(orderMonitors) do
      v.currentUI.update()
    end

    for k,v in pairs(orderMonitors) do
      local prev = term.redirect(v)
      term.setBackgroundColor(colors.black)
			term.clear()
			v.currentUI.draw()
			term.redirect(prev)
    end

		for k,v in pairs(stands) do
      local prev = term.redirect(v.monitor)
			term.setBackgroundColor(colors.black)
			term.clear()
			v.UI.draw()
			term.redirect(prev)
		end

		os.sleep(0.1)
	end
end

function handleMainUI ()
  while true do
    event, side, x, y = os.pullEvent("monitor_touch")
    for k,v in pairs(orderMonitors) do
      if side == peripheral.getName(v) then
        v.currentUI.handler(v.currentUI, event, side, x, y, v.currentUI.page)
      end
    end
  end
end

function findAvailableStand ()
  for k,v in pairs(stands) do
    if v.status == "Available" then
      return v
    end
  end
  return nil
end

function handleMusicPlayer ()
  while true do
    musicPlayerContext:update()
    os.sleep(0.05)
  end
end

function handleMusicInstances ()
  while true do
    if not musicPlayerContext:isPlaying() and tableUtils.getTableSize(brewingQueue.getQueue()) > 0 then
      musicPlayerContext.instances[math.random(1, #musicPlayerContext.instances)].playing = true
    end
    os.sleep(0.05)
  end
end

function handleOrderQueue ()
  while true do
    local s = findAvailableStand()
    if s then
      local o = orderQueue.popLeft()
      if o then
        brewingQueue.pushLeft(o)
        s.brew(o.recipe, o.ID)
      end
    end
    os.sleep(0.1)
  end
end


function resetOrderUI (monitor)
  for k,v in pairs(orderMonitors) do
    if peripheral.getName(v) == monitor then
      local orderUI = v.orderUI

      local potionTypeButtons = orderUI.findObjectsWithTag("potionType")
      local potionEmpowerTypeButtons = orderUI.findObjectsWithTag("potionEmpowerType")
      local potionThrowTypeButtons = orderUI.findObjectsWithTag("potionThrowType")

      for k,v in pairs(potionTypeButtons) do
        v.active = false
      end

      for k,v in pairs(potionEmpowerTypeButtons) do
        v.active = false
      end

      for k,v in pairs(potionThrowTypeButtons) do
        v.active = false
      end

      orderUI.page = 1
    end
  end
end

function getCurrentOrderRecipe (mon)
  local m = getOrderMonitor(mon)
  local orderUI = m.orderUI

  local potionTypeButtons = orderUI.findObjectsWithTag("potionType")
  local potionEmpowerTypeButtons = orderUI.findObjectsWithTag("potionEmpowerType")
  local potionThrowTypeButtons = orderUI.findObjectsWithTag("potionThrowType")

  local ing = nil
  local spls = false
  local ext = false
  local emp = false
  local ling = false

  for k,v in pairs(potionTypeButtons) do
    if v.active then
      ing = v.data
    end
  end

  for k,v in pairs(potionEmpowerTypeButtons) do
    if v.active and v.data == "empowered" then
      emp = true
    elseif v.active and v.data == "extended" then
      ext = true
    end
  end

  for k,v in pairs(potionThrowTypeButtons) do
    if v.active and v.data == "splash" then
      spls = true
    elseif v.active and v.data == "lingering" then
      spls = true
      ling = true
    end
  end

  if ing then
    return Recipe.new(ing, ext, emp, spls, ling)
  else
    return nil
  end
end

--code
setup()
parallel.waitForAll(runUI, handleMainUI, handleOrderQueue, handleOrderQueue, handleOrderQueue, handleMusicPlayer, handleMusicInstances)
