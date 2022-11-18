local rootPath, customTools = ...

-- Jordan4ibanez functions
local buildString          = customTools.buildString
local switch               = customTools.switch
local simpleSwitch         = customTools.simpleSwitch
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
local ternary              = customTools.ternary

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
local vecZero              = vector.zero
local vecMultiply          = vector.multiply
local vecAdd               = vector.add


--! No animation because that's not implemented into Minetest

local beltSpeeds = immutable({ 1, 2, 3})
local beltAngles = immutable({-45, 0, 45})

local beltSwitch = {}

local flatBelts = {}
local turnBelts = {}

local switchBelts = {}

for _,beltSpeed in immutableIpairs(beltSpeeds) do


--* Turn belts
local turnNameString = buildString(
    "tech:belt_turn_", beltSpeed
)

beltSwitch[turnNameString] = function()
    return beltSpeed
end

turnBelts[turnNameString] = true


local definition = {
    paramtype  = "light",
    paramtype2 = "facedir",
    drawtype   = "mesh",
    description = buildString("Belt Tier ", beltSpeed, " Turn"),
    mesh = "belt_0.b3d",
    tiles = {
        buildString("belt_",beltSpeed,"_turn.png")
    },
    visual_scale = 0.5,
    groups = {
        dig_immediate = 3
    },
    after_place_node = function(_, placer, _, pointedThing)
        local lookDir = placer:get_look_dir()
        local fourDir = convertDir(dirToFourDir(lookDir))
        write(dirToFourDir(lookDir))
        setNode(pointedThing.above, {name = turnNameString, param2 = fourDir})
    end
}

registerNode(
    turnNameString,
    definition
);


--* Switcher belts
local switchNameString = buildString(
    "tech:belt_switch_", beltSpeed
)

beltSwitch[switchNameString] = function()
    return beltSpeed
end

switchBelts[switchNameString] = true


local definition = {
    paramtype  = "light",
    paramtype2 = "facedir",
    drawtype   = "mesh",
    description = buildString("Belt Tier ", beltSpeed, " Switch"),
    mesh = "belt_0.b3d",
    tiles = {
        buildString("belt_",beltSpeed,"_turn.png")
    },
    visual_scale = 0.5,
    groups = {
        dig_immediate = 3
    },
    after_place_node = function(_, placer, _, pointedThing)
        local lookDir = placer:get_look_dir()
        local fourDir = convertDir(dirToFourDir(lookDir))
        write(dirToFourDir(lookDir))
        setNode(pointedThing.above, {name = turnNameString, param2 = fourDir})

        write("Then add the right side")
    end
}

registerNode(
    switchNameString,
    definition
);





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

    local angleSwitch = simpleSwitch:new({
        [0]   = "Flat",
        [45]  = "Upward",
        [-45] = "Downward"
    })

    -- Todo: Make belts act like rails
    local definition = {
        paramtype  = "light",
        paramtype2 = "facedir",
        drawtype   = "mesh",
        description = buildString("Belt Tier ", beltSpeed, " ", angleSwitch:match(beltAngle)),
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

turnBelts = boolSwitch:new(turnBelts)

switchBelts = boolSwitch:new(switchBelts)

-- Globalize it into global scope

function grabFlatBelts()
    return flatBelts
end

function grabBeltSwitch()
    return beltSwitch
end

function grabTurnBeltSwitch()
    return turnBelts
end

function grabSwitchBeltsSwitch()
    return switchBelts
end