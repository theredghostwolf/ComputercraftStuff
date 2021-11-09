--load apis
local apis = {
  "tableUtils.lua",
  "peripheralUtils.lua",
  "itemUtils.lua",
}

for _, api in ipairs(apis) do
	if not _G[api] then
		if not os.loadAPI("API/" .. api) then
			error("could not load API: "..api)
		end
	end
end

bucketBarrel = "minecraft:barrel_1"
alchemyTable = "bloodmagic:alchemytable_1"
openCrate = "botania:open_crate_5"
storage = "minecraft:chest"
redstoneIntegrator = "redstoneIntegrator_2"
redstoneIntegrator2 = "redstoneIntegrator_3"
collectionEnableSide = "left"
blockReader = "blockReader_0"
output = "minecraft:barrel_2"

crucibleStirSide = "top"


Item = {}
Item.new = function (name, amount)
  local self = {}

  self.name = name or ""
  self.amount = amount or 1

  return self
end

RecipeStep = {}
RecipeStep.new = function (items, stirs)
  local self = {}

  self.items = items  or {}
  self.stirs = stirs or 0

  return self
end

Recipe = {}
Recipe.new  = function(output, steps)
  local self = {}

  self.output = output or ""
  self.steps = steps or {}

  self.materialsAvailable = function ()
    for key,step in pairs(self.steps) do
      for index, item in pairs(step.items) do
        if getAmountOfItemsInContainers(item.name, storage) < item.amount then
          return false
        end
      end
    end
    return true
  end

  return self
end

enchantedAshItem1 = Item.new("eidolon:enchanted_ash")
enchantedAshItem1 = Item.new("eidolon:enchanted_ash", 2)
goldenNuggetItem2 = Item.new("minecraft:gold_nugget", 2)
carrotItem = Item.new("minecraft:carrot")
appleItem = Item.new("minecraft:apple")
melonItem = Item.new("minecraft:melon_slice")
coalItem = Item.new("minecraft:coal")
goldIngotItem2 = Item.new("minecraft:gold_ingot", 2)
warpedFungusItem = Item.new("minecraft:warped_fungus")
calxItem = Item.new("eidolon:ender_calx")
netherwartItem = Item.new("minecraft:nether_wart")
brownMushroomItem = Item.new("minecraft:brown_mushroom")
bonemealItem = Item.new("minecraft:bone_meal")
seedsItem = Item.new("minecraft:wheat_seeds")

sulfurRecipe = Recipe.new("eidolon:sulfur", {
  RecipeStep.new({enchantedAshItem1, coalItem})
})

goldenCarrotRecipe = Recipe.new("minecraft:golden_carrot",{
  RecipeStep.new({goldenNuggetItem2}),
  RecipeStep.new({enchantedAshItem1}, 2),
  RecipeStep.new({carrotItem})
})

goldenAppleRecipe = Recipe.new("minecraft:golden_apple", {
  RecipeStep.new({goldIngotItem2}),
  RecipeStep.new({enchantedAshItem1}, 2),
  RecipeStep.new({appleItem})
})

glisteringMelonRecipe = Recipe.new("minecraft:glistering_melon_slice", {
  RecipeStep.new({goldenNuggetItem2}),
  RecipeStep.new({enchantedAshItem1}, 2),
  RecipeStep.new({melonItem})
})

warpedSproutRecipe = Recipe.new("eidolon:warped_sprouts", {
  RecipeStep.new({warpedFungusItem}),
  RecipeStep.new({calxItem}, 2),
  RecipeStep.new({netherwartItem})
})

sproutingFungusRecipe = Recipe.new("eidolon:fungus_sprouts", {
  RecipeStep.new({brownMushroomItem}),
  RecipeStep.new({bonemealItem}, 2),
  RecipeStep.new({seedsItem})
})

--items to be kept on hand
KeepInStock = {
  {goldenCarrotRecipe, 64},
  {goldenAppleRecipe, 64},
  {glisteringMelonRecipe, 64},
  {sproutingFungusRecipe, 64},
  {warpedSproutRecipe, 64},
  {sulfurRecipe, 64}
}

function setup()
    term.clear()
    term.setCursorPos(1,1)
    print("AutoCrucible V1")

    bucketBarrel = peripheral.wrap(bucketBarrel)
    alchemyTable = peripheral.wrap(alchemyTable)
    openCrate = peripheral.wrap(openCrate)
    redstoneIntegrator = peripheral.wrap(redstoneIntegrator)
    blockReader = peripheral.wrap(blockReader)
    storage = peripheralUtils.wrapMultiplePeripherals(storage)
    redstoneIntegrator2 = peripheral.wrap(redstoneIntegrator2)
    output = {peripheral.wrap(output)}
end

function getCrucibleData ()
  return blockReader.getBlockData()
end

function fillCrucible ()
  if getCrucibleData().hasWater == 0 then
    local slot = itemUtils.findItem(bucketBarrel, "minecraft:bucket")
    itemUtils.pullItems(alchemyTable, bucketBarrel, slot, 1)
    while getCrucibleData().hasWater < 1 do
      os.sleep(0.05)
    end
  end
end

function waitForCrucibleToBoil ()
  while getCrucibleData().boiling < 1 do
    os.sleep(0.05)
  end
end

function stirCrucible (amount)
  amount = amount or 1
  for i = 1, amount do
    while getCrucibleData().stirTicks > 0 do
      os.sleep(0.05)
    end
    redstoneIntegrator.setOutput(crucibleStirSide, true)
    os.sleep(0.1)
    redstoneIntegrator.setOutput(crucibleStirSide, false)
  end
end

function findItemInstorage (item)
  for k,v in pairs(storage) do
    local i = itemUtils.findItem(v, item)
    if i then return v, i end
  end
end

function insertItems (items, stir, step, isLast)
  while getCrucibleData().stirs < stir do
    stirCrucible()
  end
  for k,v in pairs (items) do
    v.amount = v.amount or 1
    for i = 1,v.amount do
      container, slot = findItemInstorage(v.name)
      itemUtils.pushItems(container, openCrate, slot, 1)
    end
  end

  if isLast then
    waitForCrucibleToEmpty()
  else
    waitForItemsToDissolve(items, step)
  end
end

function getItemsInContent(content)
  local total = {}
  for k,v in pairs(content) do
    if total[v.id] then
      total[v.id] = total[v.id] + v.Count
    else
      total[v.id] = v.Count
    end
  end
  return total
end

function waitForItemsToDissolve (items, step)
  local dissolved  = false
  while not dissolved do
    local crucible = getCrucibleData()
    if crucible.steps[step - 1] then
      local contents = getItemsInContent(crucible.steps[step - 1].contents)
      local done = true
      for k,v in pairs(items) do
        for key, value in pairs(contents) do
          if not (v.name == key and v.amount == value) then
            done = false
          end
        end
      end
      dissolved = done
    end
    if not dissolved then
      os.sleep(0.05)
    end
  end
end

function waitForCrucibleToEmpty ()
  while getCrucibleData().hasWater > 0 do
    os.sleep(0.05)
  end
end

function brewRecipe (recipe, amount)
  print("Brewing: " .. recipe.output)
  amount = amount or 1
  for i = 1,amount do
    fillCrucible()
    waitForCrucibleToBoil()
    for k,v in pairs(recipe.steps) do
      local isLast = false
      if k == #recipe.steps then
        isLast = true
      end
      insertItems(v.items, v.stirs, k, isLast)
    end
  end
end

function getAmountOfItemsInContainers (requestedItem, containers)
  local total = 0
  for k,v in pairs(containers) do
    for slot, item in pairs(v.list()) do
      if item.name == requestedItem then
        total = total + item.count
      end
    end
  end
  return total
end

--checks if there is stuff that needs to be brewed
--then checks if the stuff that has to be brewed can be brewed
--brews the stuff that has to be brewed and can be brewed
function handleBrewing ()
  while true do
    for k,v in pairs (KeepInStock) do
      if getAmountOfItemsInContainers(v[1].output, output) < v[2] then
        if v[1].materialsAvailable() then
          brewRecipe(v[1])
        end
      end
    end
  end
end

function handleCollection ()
  while true do
    redstoneIntegrator2.setOutput(collectionEnableSide, (getCrucibleData().boiling > 0))
    os.sleep(0.1)
  end
end

setup()
parallel.waitForAll(handleBrewing, handleCollection)
