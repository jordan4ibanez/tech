local rootPath, customTools = ...

-- Jordan4ibanez functions
local buildString          = customTools.buildString
local switch               = customTools.switch
local write                = customTools.write
local immutable            = customTools.immutable
local immutableIpairs      = customTools.immutableIpairs
local immutablePairs       = customTools.immutablePairs
local dirToFourDir         = customTools.dirToFourDir
local fourDirToDir         = customTools.fourDirToDir
local convertDir           = customTools.convertDir
local vec2                 = customTools.vec2
local entityFloor          = customTools.entityFloor
local extractName          = customTools.extractName
local extractDirection     = customTools.extractDirection
local debugParticle        = customTools.debugParticle

-- Minetest functions
local registerNode         = minetest.register_node
local getNode              = minetest.get_node
local getMeta              = minetest.get_meta
local setNode              = minetest.set_node
local onLoaded             = minetest.register_on_mods_loaded
local addEntity            = minetest.add_entity
local addItem              = minetest.add_item
local registerEntity       = minetest.register_entity
local registerCraftItem    = minetest.register_craftitem
local registeredNodes      = minetest.registered_nodes
local registeredItems      = minetest.registered_items --? Why are these two different?
local registeredCraftItems = minetest.registered_craftitems
local newVec               = vector.new
local zeroVec              = vector.zero
local vecMultiply          = vector.multiply
local vecAdd               = vector.add
local serialize            = minetest.serialize
local deserialize          = minetest.deserialize
local objectsInRadius      = minetest.get_objects_inside_radius

-- Lua functions
local floor                = math.floor
local ceil                 = math.ceil

-- Functions pulled out of thin air ~spooky~
local flatBelts            = grabFlatBelts()





--! Beginning of the inserter object

-- Specifically mutable so that items can be added in externally by mods

--[[ 
    This needs a few specifics to get past a hurtle:
    1. This needs to be able to be told what inventory it can take items out of for specific nodes
    2. This needs to be able to be told what items it puts into what inventory

    Containers are implicit on their input definition. This means you can shovel as many definitions you want into the list and it will automatically
    decypher what you are trying to say. Just do not duplicate elements. An example:
    
    "input", "default:chest", "main"

    You are telling the inserter on stage 2 of production that if it is trying to unload into a chest look for somewhere
    in the main inventory to drop the item off. If there is no room, the inserter will be stuck on this step!

    Another example:

    "output", "default:furnace", "output"

    You have told the furnace that when it is taking something out of the furnace, it needs to look in the output slot. If there's 
    nothing in there, the inserter will be stuck on this step. This is step 0 of production.

    Input and output gets kind of confusing. Just know that the inserter sees output as what the container is outputting (what it is trying to grab), and vice versa.

]]

local containers = {
    input  = {},
    output = {},
}

local function tableContains(table, element)
    for _,value in ipairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

local function createContainerItem(io, nodeName, inventory)
    -- Must build up the arrays
    if not containers[io][nodeName] then
        containers[io][nodeName] = {}
    end

    if not tableContains(containers[io][nodeName], inventory) then
        table.insert(containers[io][nodeName], inventory)
    else
        error(
            buildString(
                "\nThere has been a duplicate allocation in inserter containers. This errors out to not cause silent bugs. ",
                "Specific duplication info:\n\nIO = ", io, "\nNode Name = ", nodeName, "\nInventory = ", inventory, "\n"
            ),
            1
        )
    end
end

-- Global api element
function addInserterContainer(io, nodeName, inventory)
    createContainerItem(io, nodeName, inventory)
end

--! Set some container defaults for Minetest's default game. This is debug for now.
createContainerItem("output", "default:chest", "main")
createContainerItem("input",  "default:chest", "main")
createContainerItem("output", "default:chest_open", "main")
createContainerItem("input",  "default:chest_open", "main")

createContainerItem("output", "default:furnace"       , "fuel")
createContainerItem("output", "default:furnace_active", "fuel")
createContainerItem("output", "default:furnace"       , "src" )
createContainerItem("output", "default:furnace_active", "src" )

createContainerItem("input", "default:furnace"       , "dst")
createContainerItem("input", "default:furnace_active", "dst")




local unpackVec2          = immutable(vec2(1,20))
local selfTestVec2        = immutable(vec2(20,40))
local fullyInitializeVec2 = immutable(vec2(40,60))
local reachForwardVec2    = immutable(vec2(60,80))
local reachBackwardVec2   = immutable(vec2(80,100))

local inserterAnimations  = switch:new({
    unpack   = function()
        return unpackVec2, 20, 0, false
    end,
    selfTest = function()
        return selfTestVec2, 60, 0, false
    end,
    fullyInitialize = function()
        return fullyInitializeVec2, 30, 0, false
    end,
    reachForward = function()
        return reachForwardVec2, 30, 0, false
    end,
    reachBackward = function()
        return reachBackwardVec2, 30, 0, false
    end
})

local shortCutAnimations = {"reachBackward", "reachForward", "reachForward", "reachBackward"}
local function shortCutActivateAnimation(stage)
    return shortCutAnimations[stage + 1]
end

--! No idea how to fix the rotation in blender

local rotationFix = newVec(math.pi / 2, 0, 0)

local inserterSize = 0.7
local inserter = {
    initial_properties = {
        visual = "mesh",
        mesh = "inserter.b3d",
        textures = {
            "default_dirt.png"
        },
        visual_size = newVec(inserterSize, inserterSize, inserterSize),
    },
    position = zeroVec(),
    animationTimer = 0.0,
    boot = true,
    bootStage = 0,
    production = false,
    productionStage = 0,
    visual = nil,
    holding = ""
}

-- Animation mechanics
function inserter:setAnimation(animation)
    self.object:set_animation(inserterAnimations:match(animation))
end

function inserter:animationTick(delta)
    self.animationTimer = self.animationTimer + delta
    return self.animationTimer
end
function inserter:resetAnimationTimer()
    self.animationTimer = 0
end

-- Inserter boot procedure
local bootSwitch = switch:new({
    [0] = function(self)
        if self.animationTimer >= 1.5 then
            self:setAnimation("selfTest")
            self:resetAnimationTimer()
            self.bootStage = self.bootStage + 1;
        end
    end,
    [1] = function(self)
        if self.animationTimer >= 1.5 then
            self:setAnimation("fullyInitialize")
            self:resetAnimationTimer()
            self.bootStage = self.bootStage + 1;
        end
    end,
    [2] = function(self)
        if self.animationTimer >= 1.5 then
            -- Boot procedure complete
            self.bootStage = -1
            self.boot = false
            self.production = true
        end
    end
})

function inserter:bootProcedure()
    if not self.boot then return end
    bootSwitch:match(self.bootStage, self)
end


--[[
    Production Stages
    0 - arm is back, reaching for item
    1 - arm is swinging forward
    2 - arm is searching for place on belt to unload, or for a place to put things into the container
    *belt has found a place to unload*
    3 - arm is swinging back to stage 0

    The bone that the pseudo item needs to be attached to is called "grabber"
]]

-- Grab an inventory that is not empty
local function grabFirstNotEmptyInventory(possibleInventorySelections, inventory)

    for _,name in ipairs(possibleInventorySelections) do
        if not inventory:is_empty(name) then
            return name
        end
    end

    return false
end

-- Grab the first item out of the list

local function getFirstIndex(inventory, inventorySelection)
    local inventorySize = inventory:get_size(inventorySelection)
    local list = inventory:get_list(inventorySelection)

    for i = 1,inventorySize do
        if not list[i]:is_empty() then
            return i
        end
    end

    return false
end

local function examineInputInventories(nodeName)
    if containers.input[nodeName] then
        -- Return a list of elements
        return containers.input[nodeName]
    end
    return false
end

-- Don't bother with searching everything, player can clear the area
local function isAir(nodeName)
    return nodeName == "air"
end

-- Grab the first thing it sees
local function grabInputFromPosition(position, radius)
    
    local gottenObject = objectsInRadius(position, radius)
    
    if not gottenObject then return false end
    
    if #gottenObject <= 0 then return false end
    
    gottenObject = gottenObject[1]
    
    local gottenEntity = gottenObject:get_luaentity()

    if not gottenEntity.name or gottenEntity.name ~= "__builtin:item" then return false end
    
    local itemString = gottenEntity.itemstring

    local stack = ItemStack(itemString)

    itemString = stack:get_name()
    
    local count = stack:get_count()

    count = count - 1

    if count <= 0 then
        gottenObject:remove()
    else
        stack:set_count(count)
        gottenEntity:set_item(stack)
    end

    return itemString
end

-- Can only place on flat conveyer belts, otherwise it looks even worse

local function searchInput(self)

    if not self.input then return false end

    local inputPosition = self.input
    
    local nodeIdentity = getNode(inputPosition)
    local nodeName     = extractName(nodeIdentity)

    --! if it's a belt, do another function to search the belt position then return here
    if isAir(nodeName) then

        local gottenItemString = grabInputFromPosition(self.input, 0.5)

        if not gottenItemString then return false end

        self.holding = gottenItemString
        self:updateVisual(self.holding)
        self:setAnimation("reachForward")

        return true
    elseif flatBelts:match(nodeName) then
        write("Yeah, that's a flat belt")

        debugParticle(self.input)

        --! This needs to be adjusted: Tune radius, tune position
        grabInputFromPosition(self.input, 0.5)

        return false
    end

    local possibleInventorySelections = examineInputInventories(nodeName)

    if not possibleInventorySelections then return false end

    local meta = getMeta(inputPosition)
    local inventory = meta:get_inventory()
    local inventorySelection = grabFirstNotEmptyInventory(possibleInventorySelections, inventory)

    if not inventorySelection then return false end

    local selectedIndex = getFirstIndex(inventory, inventorySelection)
    
    if not selectedIndex then return false end
        
    local stack = inventory:get_stack(inventorySelection, selectedIndex):take_item(1)

    inventory:remove_item(inventorySelection, stack)

    self.holding = stack:get_name()
    self:updateVisual(self.holding)
    self:setAnimation("reachForward")

    return true
end


-- Grab an that has room for it
local function grabFirstRoomyInventory(possibleInventorySelections, inventory, itemString)

    for _,name in ipairs(possibleInventorySelections) do
        if inventory:room_for_item(name, itemString) then
            return name
        end
    end

    return false
end

local function examineOutputInventories(nodeName)
    if containers.output[nodeName] then
        -- Return a list of elements
        return containers.output[nodeName]
    end
    return false
end

local function searchOutput(self)
    if not self.output then return false end

    local outputPosition = self.output
    
    local nodeIdentity = getNode(outputPosition)
    local nodeName     = extractName(nodeIdentity)

    --! if it's a belt, do another function to search the belt position then return here

    if isAir(nodeName) then
        
        addItem(outputPosition, self.holding)

        self.holding = ""

        self:updateVisual(self.holding)
        self:setAnimation("reachBackward")
        return true
    end

    local possibleInventorySelections  = examineOutputInventories(nodeName)

    if not possibleInventorySelections then return false end

    local meta = getMeta(outputPosition)
    local inventory = meta:get_inventory()
    local inventorySelection = grabFirstRoomyInventory(possibleInventorySelections, inventory, self.holding)


    if not inventorySelection then return false end
        
    inventory:add_item(inventorySelection, self.holding)

    self.holding = ""

    self:updateVisual(self.holding)
    self:setAnimation("reachBackward")
    
    return true
    
end

--? Leads to jumpy animation on restart, but who really cares?
local productionSwitch = switch:new({
    -- Searching container to load up
    [0] = function(self)
        write("stage 0")
        if searchInput(self) then
            self.animationTimer = 0
            self.productionStage = 1
        end
    end,
    -- Swinging forward, animation stage
    [1] = function(self)
        write("stage 1")
        if self.animationTimer >= 0.75 then
            self.animationTimer = 0
            self.productionStage = 2
        end
    end,
    -- Searching for a place to unload
    [2] = function(self)
        write("stage 2")
        if searchOutput(self) then
            self.animationTimer = 0
            self.productionStage = 3
        end
    end,
    -- Swinging backward, animation stage
    [3] = function(self)
        write("stage 3")
        if self.animationTimer >= 0.75 then
            self.animationTimer = 0
            self.productionStage = 0
        end
    end
})

function inserter:productionProcedure()
    if self.boot then return end
    productionSwitch:match(self.productionStage, self)
end

function inserter:updateVisual(newItem)
    if self.visual then
        local visualEntity = self.visual:get_luaentity()
        if not newItem or newItem == "" then
            visualEntity:removeItem()
        else
            visualEntity:setItem(newItem)
        end
    end
end


--! Minetest internal functions for entity object

local function gotStaticData(self, dataTable)
    for key, value in pairs(dataTable) do
        self[key] = value
    end

    local itemEntityVisual = addEntity(self.position, "tech:inserterVisual", "new")
    if itemEntityVisual then

        itemEntityVisual:set_attach(self.object, "grabber", newVec(0,4,0), zeroVec(), false)

        self.visual = itemEntityVisual

        if self.holding ~= "" then
            self:updateVisual(self.holding)
        end
    end

    if self.production then
        self:setAnimation(shortCutActivateAnimation(self.productionStage))
    end
end

local function noStaticData(self)
    self:setAnimation("unpack")
    self.position = self.object:get_pos()

    local itemEntityVisual = addEntity(self.position, "tech:inserterVisual", "new")
    if itemEntityVisual then
        itemEntityVisual:set_attach(self.object, "grabber", newVec(0,4,0), zeroVec(), false)
        self.visual = itemEntityVisual
    end
end

function inserter:on_activate(staticData)

    local dataTable = deserialize(staticData)

    if dataTable then
        gotStaticData(self, dataTable)
    else
        noStaticData(self)
    end
end

-- Automate static data serialization
function inserter:get_staticdata()
    local tempTable = {}

    for key,value in pairs(self) do
        if key ~= "object" and key ~= "visual" then
            tempTable[key] = value
        end
    end

    return serialize(tempTable)
end


function inserter:on_step(delta)
    local animationTimer = self:animationTick(delta)
    self:bootProcedure()
    self:productionProcedure()
end

function inserter:on_punch()
    addItem(self.position, "tech:inserter")
    if self.holding then
        addItem(self.position, self.holding)
    end
    if self.visual and self.visual:get_luaentity() then
        self.visual:remove()
    end
    self.object:remove()
end


registerEntity("tech:inserter", inserter)











--! Beginning of the inserter item

local inserterItem = {
    description     = "inserter",
    inventory_image = "inserter.png"
}

local function adjustPlacement(inputPosition)
    inputPosition.y = inputPosition.y - 0.25
    return inputPosition
end

local function convertFourDirToYaw(inputDirection)
    return (math.pi / 2.0) * -(inputDirection + 1)
end


function inserterItem:on_place(placer, pointedThing)
    local lookDir = placer:get_look_dir()
    local fourDir = dirToFourDir(lookDir)
    local yaw     = convertFourDirToYaw(fourDir)
    local above   = pointedThing.above

    local inserterObject = addEntity(adjustPlacement(above), "tech:inserter")

    if inserterObject then
        inserterObject:set_rotation(
            newVec(
                math.pi / 2,
                yaw,
                0
            )
        )
        local frontDirection = fourDirToDir(fourDir)

        above.y = ceil(above.y)

        local front = vecAdd(frontDirection, above)
        local back  = vecAdd(vecMultiply(frontDirection, -1), above)

        local entity = inserterObject:get_luaentity()
        entity.input  = back
        entity.output = front
    end
end

registerCraftItem("tech:inserter", inserterItem)