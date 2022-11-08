local rootPath = ...

-- Jordan4ibanez functions
local customTools          = dofile(rootPath .. "/custom_tools.lua")
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

-- Functions pulled out of thin air ~spooky~
local beltSwitch = grabBeltSwitch()

--! Beginning of belt item object

local beltItem = {
    flooredPosition = nil,
    oldPosition     = nil
}

-- Get the floored position
function beltItem:pollPosition(object)
    local flooredPosition = entityFloor(object)

    if not self.flooredPosition or not vector.equals(self.flooredPosition, flooredPosition) then
        self.flooredPosition = flooredPosition
    end
end

-- When the object comes into existence
function beltItem:on_activate(staticdata, dtime_s)
    self:pollPosition(self.object)
    self:saveStepMemory()
end

-- Save memory for the next server step
function beltItem:saveStepMemory()
    if not self.oldPosition or not vector.equals(self.flooredPosition, self.oldPosition) then
        self.oldPosition = vector.copy(self.flooredPosition)
    end
end

-- This is a hack to make the things move on the belts for now
local dirVec0 = immutable(vector.new( 0, 0,-1))
local dirVec1 = immutable(vector.new(-1, 0, 0))
local dirVec2 = immutable(vector.new( 0, 0, 1))
local dirVec3 = immutable(vector.new( 1, 0, 0))
local directionSwitch = switch:new({
    [0] = function(object)
        object:set_velocity(dirVec0)
    end,
    [1] = function(object)
        object:set_velocity(dirVec1)
    end,
    [2] = function(object)
        object:set_velocity(dirVec2)
    end,
    [3] = function(object)
        object:set_velocity(dirVec3)
    end,
})



function beltItem:pollBelt(object)
    local position = self.flooredPosition
    local nodeIdentity = getNode(position)
    local beltName = extractName(nodeIdentity)
    local beltDir  = extractDirection(nodeIdentity)
    local beltSpeed, beltAngle = beltSwitch:match(beltName)

    if beltSpeed then
        -- write(beltSpeed, " ", beltAngle, " ", beltDir)
        directionSwitch:match(beltDir, object)
    else
        write("I ain't on no belt")
    end
end

function beltItem:on_step(delta)
    local object = self.object
    
    self:pollPosition(object)

    self:pollBelt(object)
    
    self:saveStepMemory()
end

-- Todo: Make this do a thing!
registerEntity("tech:beltItem", beltItem)