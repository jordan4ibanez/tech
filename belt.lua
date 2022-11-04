local rootPath, customTools = ...

-- Jordan4ibanez functions
local buildString          = customTools.buildString
local switch               = customTools.switch
local boolSwitch           = customTools.boolSwitch
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


--! No animation because that's not implemented into Minetest

local beltSpeeds = immutable({ 1, 2, 3})
local beltAngles = immutable({-45, 0, 45})
local beltSwitch = {}
local flatBelts = {}

for _,beltSpeed in immutableIpairs(beltSpeeds) do
for _,beltAngle in immutableIpairs(beltAngles) do

    local angleConversion = tostring(beltAngle):gsub("-", "negative_")

    local nameString = buildString(
        "tech:belt_", angleConversion, "_", beltSpeed
    )
    -- Automate ability to match things
    if beltAngle == 0 then
        flatBelts[nameString] = true
    end

    -- Automate data extraction during runtime
    beltSwitch[nameString] = function()
        return beltSpeed, beltAngle
    end

    -- Todo: Make belts act like rails
    local definition = {
        paramtype  = "light",
        paramtype2 = "facedir",
        drawtype   = "mesh",
        mesh = buildString("belt_", angleConversion, ".b3d"),
        tiles = {
            buildString("belt_",beltSpeed,".png")
        },
        visual_scale = 0.5,
        groups = {
            dig_immediate = 3
        },
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

flatBelts = boolSwitch:new(flatBelts)

-- Globalize it into global scope

function grabFlatBelts()
    return flatBelts
end
