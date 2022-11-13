local rootPath, customTools = ...

-- Jordan4ibanez functions
local buildString          = customTools.buildString
local switch               = customTools.switch
local simpleSwitch         = customTools.simpleSwitch
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
local ternary              = customTools.ternary

-- Minetest functions
local registerNode         = minetest.register_node
local getNode              = minetest.get_node
local getMeta              = minetest.get_meta
local setNode              = minetest.set_node
local swapNode             = minetest.swap_node
local removeNode           = minetest.remove_node
local getTimer             = minetest.get_node_timer
local onLoaded             = minetest.register_on_mods_loaded
local addEntity            = minetest.add_entity
local addItem              = minetest.add_item
local registerEntity       = minetest.register_entity
local registerCraftItem    = minetest.register_craftitem
local registeredNodes      = minetest.registered_nodes
local registeredItems      = minetest.registered_items --? Why are these two different?
local registeredCraftItems = minetest.registered_craftitems
local getCraftResult       = minetest.get_craft_result
local digNode              = minetest.dig_node
local nodeDig              = minetest.node_dig
local newVec               = vector.new
local vecZero              = vector.zero
local vecMultiply          = vector.multiply
local vecAdd               = vector.add
local vecSubtract          = vector.subtract
local vecRound             = vector.round
local vecDirection         = vector.direction
local vecCopy              = vector.copy
local serialize            = minetest.serialize
local deserialize          = minetest.deserialize
local objectsInRadius      = minetest.get_objects_inside_radius
local isPlayer             = minetest.is_player
local playSound            = minetest.sound_play

local quarryFormspec = buildString(
    "size[8,9]",
    "list[context;main;0,0.3;8,4;]",
    "list[current_player;main;0,4.85;8,1;]" ,
    "list[current_player;main;0,6.08;8,3;8]" ,
    "listring[context;main]" ,
    "listring[current_player;main]"
)

for tier = 1,3 do

local quarryNodeString = buildString("tech:quarry_", tier)

local sideQuarryTexture = buildString("tech_quarry_front_", tier, ".png")
local quarryFacePlateTexture = "tech_quarry_faceplate.png"
local frontQuarryTexture = buildString(sideQuarryTexture, "^", quarryFacePlateTexture)
local capQuarryTexture  = buildString("tech_quarry_side_", tier, ".png")

-- Top is IO for smelting & smelting control
local quarry = {
    paramtype  = "light",
    drawtype   = "normal",
    paramtype2 = "facedir",
    description = buildString("Industrial Quarry Tier ", tier),
    tiles = {
        capQuarryTexture,
        capQuarryTexture,
        sideQuarryTexture,
        sideQuarryTexture,
        frontQuarryTexture,
        sideQuarryTexture
    },
    groups = {
        dig_immediate = 3
    },
}

function quarry:after_place_node(placer, _, pointedThing)
    local position = pointedThing.above

    -- Initial setup
    local lookDir = placer:get_look_dir()
    local fourDir = convertDir(dirToFourDir(lookDir))
    write(dirToFourDir(lookDir))
    setNode(position, {name = quarryNodeString, param2 = fourDir})

    -- Create inventories
    local metaTop = getMeta(position)
    local invTop = metaTop:get_inventory()
    invTop:set_size("main", 8*4)
    metaTop:set_string("formspec", quarryFormspec)

    -- Start this thing up
    getTimer(position):start(0)
end

registerNode(
    quarryNodeString,
    quarry
)



end