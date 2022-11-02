local rootPath = ...

local registerEntity = minetest.register_entity


local InserterVisual = {

}

function InserterVisual:set_item(self, item)
    local stack = ItemStack(item or self.itemstring)
    self.itemstring = stack:to_string()
    if self.itemstring == "" then
        -- item not yet known
        return
    end

    -- Backwards compatibility: old clients use the texture
    -- to get the type of the item
    local itemname = stack:is_known() and stack:get_name() or "unknown"

    local max_count = stack:get_stack_max()
    local count = math.min(stack:get_count(), max_count)
    local size = 0.2 + 0.1 * (count / max_count) ^ (1 / 3)
    local def = core.registered_items[itemname]
    local glow = def and def.light_source and
        math.floor(def.light_source / 2 + 0.5)

    local size_bias = 1e-3 * math.random() -- small random bias to counter Z-fighting
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

    -- cache for usage in on_step
    self._collisionbox = c
end,