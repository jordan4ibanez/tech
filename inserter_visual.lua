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



local InserterVisual = {
    deleteMe = true
}

function InserterVisual:on_activate(staticdata, dtime_s)

end

function InserterVisual:setItem(item)

    local stack = ItemStack(item or self.itemstring)
    self.itemstring = stack:to_string()

    if self.itemstring == "" then
        -- item not yet known
        return
    end
    
    local itemname = stack:is_known() and stack:get_name() or "unknown"

    local size = 1
    local def = registeredItems[itemname]

    local glow = def and def.light_source and math.floor(def.light_source / 2 + 0.5)

    local c = {-size, -size, -size, size, size, size}

    self.object:set_properties({
        is_visible = true,
        visual = "wielditem",
        textures = {itemname},
        visual_size = {x = size + size_bias, y = size + size_bias},
        collisionbox = c,
        automatic_rotate = math.pi * 0.5 * 0.2 / size,
        wield_item = self.itemstring,
        glow = glow,
    })
end

registerEntity("tech:inserterVisual", InserterVisual)