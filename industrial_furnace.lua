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
local newVec               = vector.new
local vecZero              = vector.zero
local vecMultiply          = vector.multiply
local vecAdd               = vector.add
local vecSubtract          = vector.subtract
local vecRound             = vector.round
local vecDirection         = vector.direction
local vecCopy             = vector.copy
local serialize            = minetest.serialize
local deserialize          = minetest.deserialize
local objectsInRadius      = minetest.get_objects_inside_radius
local isPlayer             = minetest.is_player
local playSound            = minetest.sound_play


local bottomFormSpec = buildString(
	"size[8,8.5]",
    "list[context;fuel;2.75,0.5;1,1;]",
    "list[current_player;main;0,4.25;8,1;]",
    "list[current_player;main;0,5.5;8,3;8]",
    "listring[context;fuel]",
    "listring[current_player;main]"
)


local topFormSpec = buildString(
    "size[8,8.5]",
    "list[context;stock;2.75,0.5;1,1;]",
    "list[context;output;4.75,0.96;2,2;]",
    "list[current_player;main;0,4.25;8,1;]",
    "list[current_player;main;0,5.5;8,3;8]",
    "listring[context;output]",
    "listring[current_player;main]",
    "listring[context;stock]",
    "listring[current_player;main]"
)


for tier = 1,3 do

local capTextureString = buildString(
    "industrial_furnace_cap_", tier, ".png"
)
local sideTopTextureString = buildString(
    "industrial_furnace_top_", tier, ".png"
)
local topNodeNameString = buildString("tech:industrial_furnace_top_", tier)

-- Top is IO for smelting & smelting control
local topDefinition = {
    paramtype  = "light",
    drawtype   = "normal",
    description = buildString("Industrial Furnace Tier ", tier),
    tiles = {
        capTextureString,
        capTextureString,
        sideTopTextureString,
        sideTopTextureString,
        sideTopTextureString,
        sideTopTextureString
    },
    groups = {
        dig_immediate = 3
    },
}

local function roomForPlacement(position)
    local pos = vecCopy(position)
    if getNode(pos).name ~= "air" then return false end
    pos.y = pos.y + 1
    if getNode(pos).name ~= "air" then return false end
    return true
end

function topDefinition:on_place(placer, pointedThing)
    local bottom = pointedThing.above
    if not roomForPlacement(bottom) then return self end
    local top    = newVec(bottom.x, bottom.y + 1, bottom.z)
    
    -- Initial setup
    setNode(top, {name = topNodeNameString})
    setNode(bottom, {name = buildString("tech:industrial_furnace_bottom_", tier, "_0"), })

    -- Create inventories
    local metaTop = getMeta(top)
    local invTop = metaTop:get_inventory()
    invTop:set_size("stock", 1)
    invTop:set_size("output", 4)
    metaTop:set_string("formspec", topFormSpec)
    getTimer(top):start(0)

    local metaBottom = getMeta(bottom)
    local invBottom = metaBottom:get_inventory()
    invBottom:set_size("fuel", 1)
    metaBottom:set_string("formspec", bottomFormSpec)
    getTimer(bottom):start(0)

    self:take_item(1)
    return self
end

local burnerGoalString = buildString("tech:industrial_furnace_bottom_", tier, "_3")

local function checkBurner(position)
    local pos = vecCopy(position)
    pos.y = pos.y - 1
    if getNode(pos).name == burnerGoalString then return true end
    return false
end

function topDefinition:on_timer()
    -- Try not to trash the game with 5 second intervals
    local refreshTime = 5
    if not checkBurner(self) then getTimer(self):start(refreshTime) return end

    local node = getNode(self)
    local meta = getMeta(self)
    local inv  = meta:get_inventory()
    local list = inv:get_list("source")
    minetest.get_craft_result({method = "cooking", width = 1, items = list})

end

registerNode(
    topNodeNameString,
    topDefinition
)


-- Bottom furnace is the heat control, must be leveled
for level = 0,3 do

local sideBottomTextureString = buildString(
    "industrial_furnace_bottom_", tier, ".png",
    "^industrial_furnace_indicator_", level, ".png"
)

local bottomDefinition = {
    paramtype  = "light",
    drawtype   = "normal",
    description = buildString("Industrial Furnace Tier ", tier, ". Also, you shouldn't have this"),
    tiles = {
        capTextureString,
        capTextureString,
        sideBottomTextureString,
        sideBottomTextureString,
        sideBottomTextureString,
        sideBottomTextureString
    },
    groups = {
        dig_immediate = 3
    },
}

local function takeFuel(stack, inv)
    stack:take_item(1)
    inv:set_stack("fuel", 1, stack)
end

local function checkFuel(stack, inv)
    local fuelTime = getCraftResult({method="fuel", width=1, items={stack}}).time
    if fuelTime == 0 then return false end
    takeFuel(stack, inv)
    return fuelTime
end

function bottomDefinition:on_timer()

    -- Try not to trash the game with 5 second intervals
    local refreshTime = 5
    local node = getNode(self)
    local meta = getMeta(self)
    local inv  = meta:get_inventory()
    local stack = inv:get_stack("fuel", 1)
    local fuelTime = checkFuel(stack, inv)

    --* Furnace burner is at max level and has fuel
    if level == 3 and fuelTime then
        refreshTime = 10 * tier
    --* Furnace burner is reaching higher level with fuel
    elseif level < 3 and fuelTime then
        refreshTime = 0.1--10 / tier
        node.name = buildString("tech:industrial_furnace_bottom_", tier, "_", level + 1)
        swapNode(self, node)
    --* Furnace burner has no fuel and starts to level down
    elseif level > 0 and not fuelTime then
        refreshTime = 0.1--10 / tier
        node.name = buildString("tech:industrial_furnace_bottom_", tier, "_", level - 1)
        swapNode(self, node)
    end

    getTimer(self):start(refreshTime)
end


registerNode(
    buildString("tech:industrial_furnace_bottom_", tier, "_", level),
    bottomDefinition
)

end
end