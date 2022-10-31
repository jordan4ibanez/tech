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
local beltConversions = {}

for _,beltSpeed in immutableIpairs(beltSpeeds) do
for _,beltAngle in immutableIpairs(beltAngles) do

    local nameString = buildString(
        "tech:belt_", beltAngle, "_", beltSpeed
    )

    -- Automate conversion table
    beltConversions[nameString] = {
        beltSpeed = beltSpeed,
        beltAngle = beltAngle
    }

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
            setNode(pointedThing.above, {name = nameString, param2 = fourDir})
        end
    }
    registerNode(
        nameString,
        definition
    );
end
end

-- Finalize
beltConversions = immutable(beltConversions)


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

function beltItem:pollPosition(object)
    local flooredPosition = vector.floor(object:get_pos())

    if not self.flooredPosition or not vector.equals(self.flooredPosition, flooredPosition) then
        self.flooredPosition = flooredPosition
    end

    self:saveStepMemory()
end

function beltItem:on_activate(staticdata, dtime_s)
    self:pollPosition(self.object)
end

function beltItem:saveStepMemory(object)
    if not self.oldPosition or not vector.equals(self.flooredPosition, self.oldPosition) then
        self.oldPosition = vector.copy(self.flooredPosition)
    end
end

local directionSwitch = switch:new({
    [0] = function()
        write("Go 0")
    end,
    [1] = function()
        write("Go 1")
    end,
    [2] = function()
        write("Go 2")
    end,
    [3] = function()
        write("Go 3")
    end,
})

local function extractName(nodeIdentity)
    return nodeIdentity.name
end

function beltItem:pollBelt(object)
    local position = self.flooredPosition
    local beltName = extractName(getNode(position))

    write(beltName)
end

function beltItem:on_step(delta)
    local object = self.object
    self:pollPosition(object)

    self:pollBelt(object)


    
    self:saveStepMemory(object)
end

-- Todo: Make this do a thing!
registerEntity("tech:beltItem", beltItem)