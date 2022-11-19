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
local removeNode           = minetest.remove_node
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
local dirToYaw             = minetest.dir_to_yaw
local yawToDir             = minetest.yaw_to_dir
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

local switchBeltTextureString = buildString("belt_",beltSpeed,"_turn.png",  "^[transformFY")

for _,side in ipairs({"left", "right"}) do

local switchNameString = buildString(
    "tech:belt_switch_", beltSpeed, "_", side
)

beltSwitch[switchNameString] = function()
    return beltSpeed
end

switchBelts[switchNameString] = true

local laneSwitchFormSpec = buildString(
    "formspec_version[6]",
    "size[10.5,16]",
    "checkbox[2.1,2.6;filterItems;Item Filter;false]",
    "list[context;filter;5.5,1.6;3,2;0]",
    "label[3.4,0.9;Belt Switch Configuration]",
    "checkbox[2.1,5;filterCookable;Filter All Cookable;false]",
    "checkbox[2.1,7.2;filterFuel;Filter All Fuel;false]",
    "list[current_player;main;0.4,9.25;8,1;]",
    "list[current_player;main;0.4,10.5;8,3;8]",
    "button[7.8,4.1;2.2,0.8;clear;Clear]"
)


local definition = {
    paramtype  = "light",
    paramtype2 = "facedir",
    drawtype   = "mesh",
    description = buildString("Belt Tier ", beltSpeed, " Switch"),
    mesh = buildString("switch_belt_", side, ".b3d"),
    tiles = {
        switchBeltTextureString
    },
    visual_scale = 0.5,
    groups = {
        dig_immediate = 3
    }
}
if side == "left" then

    local rightnameString = buildString(
        "tech:belt_switch_", beltSpeed, "_right"
    )

    function definition:after_place_node(placer, _, pointedThing)
        local lookDir = placer:get_look_dir()
        local fourDir = convertDir(dirToFourDir(lookDir))
        write(dirToFourDir(lookDir))

        -- Left is where you're placing, it always places second node to the right
        local left = pointedThing.above
        
        -- Turn it to the right
        local dir = fourDirToDir(fourDir)
        local yaw = dirToYaw(dir)
        yaw = yaw + (math.pi / 2)
        dir = yawToDir(yaw)
        local right = vecAdd(left, dir)

        if getNode(left).name ~= switchNameString or getNode(right).name ~= "air" then
            removeNode(left)
            addItem(left, switchNameString)
            return
        end

        setNode(left, {name = switchNameString, param2 = fourDir})
        setNode(right, {name = rightnameString, param2 = fourDir})

        -- Left node controls the data
        local meta = getMeta(left)
        local inv = meta:get_inventory()
        inv:set_size("filter", 6)
        meta:set_int("filterItems", 0)
        meta:set_int("filterCookable", 0)
        meta:set_int("filterFuel", 0)
        meta:set_string("formspec", laneSwitchFormSpec)
    end

    function definition:on_receive_fields(_, fields)
        local meta = getMeta(self)
        if fields.clear then
            local inv = meta:get_inventory()
            for i = 1,6 do
                inv:set_stack("filter", i, "")
            end
            return
        end
        for key,value in pairs(fields) do
            meta:set_int(key, ternary(value == "true", 1, 0))
        end

    end

    function definition:allow_metadata_inventory_move()
        return 0
    end

    function definition:allow_metadata_inventory_put(listname, index, stack)
        local inv = getMeta(self):get_inventory()
        inv:set_stack(listname, index, stack:get_name())
        return 0

    end

    function definition:allow_metadata_inventory_take(listname, index)
        local inv = getMeta(self):get_inventory()
        inv:set_stack(listname, index, "")
        return 0
    end
else
    
end

registerNode(
    switchNameString,
    definition
);
end



--* The rest of the belts

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