local getModName           = minetest.get_current_modname
local getModPath           = minetest.get_modpath;
-- Jordan4ibanez functions
local customTools = dofile(getModPath(getModName()) .. "/custom_tools.lua")
local switch               = customTools.switch
local write                = customTools.write
local immutable            = customTools.immutable
local immutableIpairs      = customTools.immutableIpairs
local immutablePairs       = customTools.immutablePairs
local buildString          = customTools.buildString
local dirToFourDir         = customTools.dirToFourDir
local convertDir           = customTools.convertDir
-- Minetest functions
local registerNode         = minetest.register_node
local getNode              = minetest.get_node
local setNode              = minetest.set_node
local onLoaded             = minetest.register_on_mods_loaded
local registerEntity       = minetest.register_entity
local registeredNodes      = minetest.registered_nodes
local registeredItems      = minetest.registered_items --? Why are these two different?
local registeredCraftItems = minetest.registered_craftitems


--! No animation because that's not implemented into Minetest

local beltSpeeds = immutable({1,2,3})
local beltAngles = immutable({0,45})
local beltSwitch = {}

for _,beltSpeed in immutableIpairs(beltSpeeds) do
for _,beltAngle in immutableIpairs(beltAngles) do

    local nameString = buildString(
        "tech:belt_", beltAngle, "_", beltSpeed
    )

    -- Automate data extraction during runtime
    beltSwitch[nameString] = function()
        return beltSpeed, beltAngle
    end

    -- Todo: Make belts act like rails
    local definition = {
        paramtype  = "light",
        paramtype2 = "facedir",
        drawtype   = "mesh",
        mesh = buildString("belt_", beltAngle, ".b3d"),
        tiles = { buildString("belt_",beltSpeed,".png") },
        visual_scale = 0.5,
        after_place_node = function(_, placer, _, pointedThing)
            local lookDir = placer:get_look_dir()
            local fourDir = convertDir(dirToFourDir(lookDir))
            write(dirToFourDir(lookDir))
            setNode(pointedThing.above, {name = nameString, param2 = fourDir})
        end
    }
    registerNode(
        nameString,
        definition
    );
end
end

-- Finalize from table into switch
beltSwitch = switch:new(beltSwitch)


--! Must run after mods are loaded, entities are dynamic anyways
-- This is the entity that is "pushed" along the belt

local nodeList
local itemList
local craftItemList

onLoaded(
    function()
        -- These should absolutely never change
        nodeList      = immutable(registeredNodes)
        itemList      = immutable(registeredItems)
        craftItemList = immutable(registeredCraftItems)
    end
)

local beltItem = {
    flooredPosition = nil,
    oldPosition     = nil
}

-- Give the vector a correct-er position to floor
local adjustment = immutable(vector.new(0.5,0.5,0.5))
local function adjustFloor(inputVec)
    return vector.add(inputVec, adjustment)
end

-- 
function beltItem:pollPosition(object)
    local flooredPosition = vector.floor(adjustFloor(object:get_pos()))

    if not self.flooredPosition or not vector.equals(self.flooredPosition, flooredPosition) then
        self.flooredPosition = flooredPosition
    end

end

function beltItem:on_activate(staticdata, dtime_s)
    self:pollPosition(self.object)
    self:saveStepMemory()
end

function beltItem:saveStepMemory()
    if not self.oldPosition or not vector.equals(self.flooredPosition, self.oldPosition) then
        self.oldPosition = vector.copy(self.flooredPosition)
    end
end


local vec0 = immutable(vector.new( 0, 0,-1))
local vec1 = immutable(vector.new(-1, 0, 0))
local vec2 = immutable(vector.new( 0, 0, 1))
local vec3 = immutable(vector.new( 1, 0, 0))
local directionSwitch = switch:new({
    [0] = function(object)
        object:set_velocity(vec0)
    end,
    [1] = function(object)
        object:set_velocity(vec1)
    end,
    [2] = function(object)
        object:set_velocity(vec2)
    end,
    [3] = function(object)
        object:set_velocity(vec3)
    end,
})

local function extractName(nodeIdentity)
    return nodeIdentity.name
end
local function extractDirection(nodeIdentity)
    return nodeIdentity.param2
end

function beltItem:pollBelt(object)
    local position = self.flooredPosition
    local nodeIdentity = getNode(position)
    local beltName = extractName(nodeIdentity)
    local beltDir  = extractDirection(nodeIdentity)
    local beltSpeed, beltAngle = beltSwitch:match(beltName)

    if beltSpeed then
        write(beltSpeed, " ", beltAngle, " ", beltDir)
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