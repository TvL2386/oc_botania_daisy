-- In the starting position the robot is now facing the item with inventory
-- I'm testing with an ME Interface containing:
-- 1) A full stack of minecraft:stone (Stone 1)
-- 2) A full stack of minecraft:log (Spruce Wood 17:1)
-- 3) Some Botania:livingrock (wants 64, has 20)
-- 4) Some Botania:livingwood (wants 64, has 21)
-- 5) A single minecraft:stone_pickaxe (Stone Pickaxe 274)
--
-- In the last two inventory slots (15 and 16) of the robot, should be a piece of
-- Botania livingrock and livingwood. These are used for comparison with
-- items to break below in the move loop
-- Don't put any other items in the inventory
--
-- Overview: https://www.dropbox.com/s/wr866w3sb2b0b3g/oc_botania_daisy_overview.png?dl=0
-- ME Interface contents: https://www.dropbox.com/s/8mft8h2jfxizy2v/oc_botania_daisy_me_interface.png?dl=0

robot = require("robot")
component = require("component")

ic_address = component.inventory_controller.address
ic = component.proxy(ic_address)

-- new pickaxes are stored here
-- they are pulled from the inventory
-- if pickaxe_slot is empty
local pickaxe_slot = 13

-- returns true if there are less than 64 pieces of livingwood or livingrock
-- in the inventory in front of the robot
-- also fetches resources to place around the daisy
function crafting_needed()
  -- determine how much stone and/or log we need to fetch
  local required_stone = 64
  local required_log = 64
  local places_in_inventory = 8

  local slot_count = ic.getInventorySize(3)
  for slot = 1,slot_count do
    local item = ic.getStackInSlot(3,slot)
    if item then
      if item.name == "Botania:livingrock" then
        required_stone = 64 - item.size
        print("I need "..required_stone.." stone")
      elseif item.name == "Botania:livingwood" then
        required_log = 64 - item.size
        print("I need "..required_log.." wood")
      end
    end
  end

  -- if nothing to be done, return false
  if required_stone == 0 and required_log == 0 then
    print("Crafting needed: false")
    return false
  end

  -- fetch logs and/or wood and/or pickaxe
  for slot = 1,slot_count do
    local item = ic.getStackInSlot(3,slot)
    if item then
      if item.name == "minecraft:log" and required_log > 0 then
        robot.select(1)

        if places_in_inventory > required_log then
          places_in_inventory = places_in_inventory - required_log
          print("Sucking in "..required_log.." wood")
          ic.suckFromSlot(3, slot, required_log)
        else
          print("Sucking in "..places_in_inventory.." wood")
          ic.suckFromSlot(3, slot, places_in_inventory)
          places_in_inventory = 0
        end
      elseif item.name == "minecraft:stone" and required_stone > 0 then
        robot.select(2)

        if places_in_inventory > required_stone then
          places_in_inventory = places_in_inventory - required_stone
          print("Sucking in "..required_stone.." stone")
          ic.suckFromSlot(3, slot, required_stone)
        else
          print("Sucking in "..places_in_inventory.." stone")
          ic.suckFromSlot(3, slot, places_in_inventory)
          places_in_inventory = 0
        end
      elseif string.match(item.name, "minecraft:.+pickaxe") then
        local item = ic.getStackInInternalSlot(pickaxe_slot)

        if not item then
          robot.select(pickaxe_slot)
          ic.suckFromSlot(3, slot, 1)
        end
      end
    end
  end

  if places_in_inventory ~= 8 then
    print("Crafting needed: true")
    return true
  else
    print("Crafting needed: false")
    return false
  end
end

-- This method walks the circle around the daisy
-- If the action is place_items it will place everything in slot 1 and 2
-- if the action is collect_items it will use the tool on every block
function walk(action)
  print("Walk and perform action: "..action)
  for count = 1,4 do
    robot.turnRight()
    execute_action(action)
    robot.forward()
    execute_action(action)
    robot.forward()
    execute_action(action)
  end
  print("Done walking")
end

function execute_action(action)
  if action == "collect_items" and block_of_interest() then
    new_pickaxe()
    robot.swingDown()
  elseif action == "place_items" then
    for i = 1,2 do
      local item = ic.getStackInInternalSlot(i)

      if item then
        robot.select(i)
        robot.placeDown()
        return true
      end
    end
  end
end

function new_pickaxe()
  local number = nil
  local message = nil
  number, message = robot.durability()

  if message == "no tool equipped" then
    print("equipping new tool")
    robot.select(pickaxe_slot)
    ic.equip()
  end
end

-- this method waits for the block below to become
-- Botania:livingwood or Botania:livingrock
function wait_for_transformation()
  print("Waiting for block below me to become interesting")
  while(not block_of_interest()) do
    --print("Zzzz")
    os.sleep(1)
  end

  -- waiting an additional 2 seconds to allow everything to turn nicely
  os.sleep(2)

  print("Interesting it has become!")
  return true
end

-- this method checks for livingwood or livingrock below
-- assuming a livingwood and livingrock piece live in
-- the robots slot 15 and 16
function block_of_interest()
  for slot = 15,16 do
    robot.select(slot)
    if robot.compareDown() then
      return true
    end
  end
  return false
end

-- livingwood and livingrock from slot 15 and 16 needs to be stored
-- gotta leave 1 of both for comparison during the walk
function drop_items()
  for slot = 15,16 do
    local item = ic.getStackInInternalSlot(slot)
    if item and item.size > 1 then
      local count = item.size-1
      print("dropping "..count.." "..item.name)
      robot.select(slot)
      robot.drop(count)
    end
  end
end

-- The event loop
while true do
  if crafting_needed() then
    walk("place_items")
    wait_for_transformation()
    walk("collect_items")
    drop_items()
  else
    os.sleep(10)
  end
end
