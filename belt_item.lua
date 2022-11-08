local rootPath = ...

-- Jordan4ibanez functions
local customTools          = dofile(rootPath .. "/custom_tools.lua")
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
local debugParticle        = customTools.debugParticle
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
local zeroVec              = vector.zero
local vecMultiply          = vector.multiply
local vecAdd               = vector.add
local vecFloor             = vector.floor
local vecRound             = vector.round
local vecDirection         = vector.direction
local serialize            = minetest.serialize
local deserialize          = minetest.deserialize
local objectsInRadius      = minetest.get_objects_inside_radius
local isPlayer             = minetest.is_player

-- Lua functions
local floor = math.floor

-- Functions pulled out of thin air ~spooky~
local beltSwitch = grabBeltSwitch()

--! Beginning of belt item object

local beltItem = {
    initial_properties = {
        physical = false,
        collide_with_objects = false,
        collisionbox = { 0, 0, 0, 0, 0, 0 },
        visual = "wielditem",
        visual_size = {x = 0.25, y = 0.25},
        textures = {""},
        is_visible = false,
    },
    itemString = "",
    flooredPosition = nil,
    oldPosition     = nil,
    direction = 0,
    stopped = false,
    automatic_face_movement_dir = 0.0,
}

function beltItem:setItem(item)

    local stack = ItemStack(item or self.itemString)
    self.itemString = stack:to_string()

    if self.itemString == "" then
        -- item not yet known
        return
    end

    local itemname = stack:is_known() and stack:get_name() or "unknown"
    local def = registeredItems[itemname]
    local glow = def and def.light_source and math.floor(def.light_source / 2 + 0.5)

    self.object:set_properties({
        is_visible = true,
        visual = "wielditem",
        textures = {itemname},
        glow = glow,
    })
end

function beltItem:removeItem()
    self.object:set_properties({
        is_visible = false,
    })
end

-- Get the floored position
function beltItem:pollPosition(object)
    local flooredPosition = entityFloor(object)

    if not self.flooredPosition or not vector.equals(self.flooredPosition, flooredPosition) then

        if self.flooredPosition then
            self.oldFlooredPosition = self.flooredPosition
        else
            self.oldFlooredPosition = flooredPosition
        end

        self.flooredPosition = flooredPosition

        return true
    end
    return false
end



local directionSwitch = simpleSwitch:new({
    [0] = immutable(vector.new( 0, 0,-1)),
    [1] = immutable(vector.new(-1, 0, 0)),
    [2] = immutable(vector.new( 0, 0, 1)),
    [3] = immutable(vector.new( 1, 0, 0)),
})


-- Comment is the node rotation
local directionChangeSwitch = simpleSwitch:new({
    -- 0
    ["1 2"] = 1,
    ["3 2"] = 2,
    -- 1
    ["2 3"] = 1,
    ["0 3"] = 2,
    -- 2
    ["3 0"] = 1,
    ["1 0"] = 2,
    -- 3
    ["0 1"] = 1,
    ["2 1"] = 2
})

local function getDirectionChangeLane(newRotation, currentRotation)
    local case = buildString(currentRotation, " ", newRotation)
    return directionChangeSwitch:match(case)
end

function beltItem:pollBelt(object, update)

    if not update then return end

end

function beltItem:movement(object)

    local position = object:get_pos()
    local nodeIdentity = getNode(position)
    local beltName = extractName(nodeIdentity)
    local beltDir  = extractDirection(nodeIdentity)
    local beltSpeed, beltAngle = beltSwitch:match(beltName)
    
    if beltSpeed then

        local direction = directionSwitch:match(beltDir, object)
        beltSpeed = beltSpeed / 30
        local velocity = vecMultiply(direction, beltSpeed)
        local newPosition = vecAdd(position, velocity)


        --* Check if changing direction
        local frontNodeIdentity = getNode(newPosition)
        local frontBeltName = extractName(frontNodeIdentity)

        if not beltSwitch:match(frontBeltName) then return false end

        local frontBeltDir = extractDirection(frontNodeIdentity)

        local function findRoom(searchingPosition, radius)
            local objects = objectsInRadius(searchingPosition, radius)
            for _,gottenObject in ipairs(objects) do
                --! If you have an error here, complain to core devs about luajit versioning
                if not gottenObject then goto continue end
                if isPlayer(gottenObject) then goto continue end
                local gottenEntity = gottenObject:get_luaentity()
                if not gottenEntity then goto continue end
                if not gottenEntity.name then goto continue end
                if gottenEntity == self then goto continue end
                if gottenEntity.name == "tech:beltItem" then return false end
                ::continue::
            end
            return true
        end

        local turned = false

        if frontBeltDir ~= beltDir then
            -- write("change direction")
            local newLane = getDirectionChangeLane(beltDir, frontBeltDir)

            write("new lane: ", newLane)

            local position1 = vecRound(position)
            local position2 = vecRound(newPosition)

            local headingDirection = vecDirection(position1, position2)

            if headingDirection.x ~= 0 then
                newPosition.x = position1.x + (headingDirection.x * 0.75)
            elseif headingDirection.z ~= 0 then
                newPosition.z = position1.z + (headingDirection.z * 0.75)
            end

            turned = true
            
        end
        

        --* Check if there is enough room
        if not findRoom(newPosition, 0.2) then return false end
        
        if turned then
            local rotation = floor(object:get_yaw() * 100000)
            if rotation == 157079 then
                rotation = 0
            else
                rotation = math.pi / 2
            end

            object:set_yaw(rotation)
        end

        object:move_to(newPosition, false)
    -- Not on a belt
    else
        addItem(position, self.itemString)
        object:remove()
        return true
    end
end



function beltItem:on_step(delta)
    local object = self.object
    local removed = self:movement(object)
    if removed then return end
    local update = self:pollPosition(object)
    self:pollBelt(object, update)
end


local function gotStaticData(self, dataTable)
    for key, value in pairs(dataTable) do
        self[key] = value
    end

    self:setItem(self.itemString)
end


-- When the object comes into existence
function beltItem:on_activate(staticData)

    -- Something went horribly wrong
    if not staticData then self.object:remove() return end

    local dataTable = deserialize(staticData)

    --! Reloading
    if dataTable then
        gotStaticData(self, dataTable)
    --! Initial creation
    else
        self:pollPosition(self.object)
    end
end

-- Automate static data serialization
function beltItem:get_staticdata()
    local tempTable = {}

    for key,value in pairs(self) do
        if key ~= "object" then
            tempTable[key] = value
        end
    end

    return serialize(tempTable)
end

registerEntity("tech:beltItem", beltItem)