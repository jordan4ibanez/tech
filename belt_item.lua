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
local turnBeltSwitch = grabTurnBeltSwitch()
local flatBeltSwitch = grabFlatBelts()

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
    lane = 0,
    itemString = "",
    direction = 0,
    stopped = false,
    automatic_face_movement_dir = 0.0,
    lockedInTurn = false
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

function beltItem:setLane(lane)
    self.lane = lane
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


-- Comment is the input belt's rotation
-- Value is movement amount, inner or outer, true is inner, false is outer
local inner = 1
local outer = 2
local turnChangeSwitch = simpleSwitch:new({
    --0
    ["3 2 1"] = outer,
    ["1 2 1"] = inner,
    ["3 2 2"] = inner,
    ["1 2 2"] = outer,
    -- 1
    ["0 3 1"] = outer,
    ["2 3 1"] = inner,
    ["0 3 2"] = inner,
    ["2 3 2"] = outer,
    -- 2
    ["1 0 1"] = outer,
    ["3 0 1"] = inner,
    ["1 0 2"] = inner,
    ["3 0 2"] = outer,
    -- 3
    ["2 1 1"] = outer,
    ["0 1 1"] = inner,
    ["2 1 2"] = inner,
    ["0 1 2"] = outer
})

local function getDirectionTurn(newRotation, currentRotation, currentLane)
    local case = buildString(currentRotation, " ", newRotation, " ", currentLane)
    return turnChangeSwitch:match(case)
end

-- Todo: Rewrite this mess with a headway position
function beltItem:movement(object)

    local position = object:get_pos()
    local nodeIdentity = getNode(newVec(
        position.x, position.y - 0.5, position.z
    ))
    local beltName = extractName(nodeIdentity)
    local beltDir  = extractDirection(nodeIdentity)
    local beltSpeed, beltAngle = beltSwitch:match(beltName)
    

    if not beltSpeed then
        --! This is a hack for downward belts
        nodeIdentity = getNode(newVec(
            position.x, position.y + 0.5, position.z
        ))
        beltName = extractName(nodeIdentity)
        beltDir  = extractDirection(nodeIdentity)
        beltSpeed, beltAngle = beltSwitch:match(beltName)

        if not beltSpeed then
            addItem(position, self.itemString)
            object:remove()
            return true
        end
    end

    local direction = directionSwitch:match(beltDir, object)
    beltSpeed = beltSpeed / 30
    local velocity = vecMultiply(direction, beltSpeed)
    local newPosition = vecAdd(position, velocity)

    local frontNodeIdentity = getNode(newPosition)
    
    
    local frontBeltName = extractName(frontNodeIdentity)
    local frontBeltSpeed, frontBeltAngle = beltSwitch:match(frontBeltName)
    
    -- Going up to flat or up again
    if not frontBeltSpeed and beltAngle == 45 then

        local integerPosition = vecAdd(vecRound(newPosition), direction)
        
        frontNodeIdentity = getNode(integerPosition)
    
        frontBeltName = extractName(frontNodeIdentity)
        frontBeltSpeed, frontBeltAngle = beltSwitch:match(frontBeltName)

        if not frontBeltSpeed then return false end

        if direction.x ~= 0 then
            integerPosition.x = integerPosition.x + (direction.x * -0.45)
            newPosition.x = integerPosition.x
        elseif direction.z ~= 0 then
            integerPosition.z = integerPosition.z + (direction.z * -0.45)
            newPosition.z = integerPosition.z
        end
        newPosition.y = integerPosition.y

    --! Going flat to down - This is a logic limitation, flat to down, and down to down, if you can come up with a better solution, make a pr
    elseif not frontBeltSpeed then

        local integerPosition = vecRound(newPosition)
        integerPosition.y = integerPosition.y - 1
        frontNodeIdentity = getNode(integerPosition)
        frontBeltName = extractName(frontNodeIdentity)
        frontBeltSpeed, frontBeltAngle = beltSwitch:match(frontBeltName)

        if not frontBeltSpeed then return false end

        if direction.x ~= 0 then
            newPosition.x = integerPosition.x
        elseif direction.z ~= 0 then
            newPosition.z = integerPosition.z
        end

        newPosition.y = integerPosition.y + 0.45

    end

    if not frontBeltSpeed then return false end

    -- Upward belt logic flow
    if frontBeltAngle == 45 or beltAngle == 45 then
        newPosition.y = newPosition.y + beltSpeed
    
    -- Downwards belt logic flow - This needs an additional check because it's a mess
    elseif frontBeltAngle == -45 or beltAngle == -45 then

        newPosition.y = newPosition.y - beltSpeed
        
        -- Here is the additional check

        frontNodeIdentity = getNode(newPosition)
        frontBeltName = extractName(frontNodeIdentity)

        if flatBeltSwitch:match(frontBeltName) then
            newPosition.y = math.ceil(newPosition.y)
        end
    end
        




    

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


    local turning = false
    local turned = false
    local newLane = 0

    
    local frontBeltDir = extractDirection(frontNodeIdentity)


    --* Check if going into a turn

    if turnBeltSwitch:match(frontBeltName) then

        local turnApex = getDirectionTurn(beltDir, frontBeltDir, self.lane)

        if not turnApex then goto quickExit end

        local position1 = vecRound(position)
        local position2 = vecRound(newPosition)

        local headingDirection = vecDirection(position1, position2)

        if turnApex == outer then

            if headingDirection.x ~= 0 then
                newPosition.x = position1.x + (headingDirection.x * 1.25)
            elseif headingDirection.z ~= 0 then
                newPosition.z = position1.z + (headingDirection.z * 1.25)
            end

        else
            if headingDirection.x ~= 0 then
                newPosition.x = position1.x + (headingDirection.x * 0.75)
            elseif headingDirection.z ~= 0 then
                newPosition.z = position1.z + (headingDirection.z * 0.75)
            end
        end
        
        turned = true
        turning = true
        newLane = self.lane
    end

    ::quickExit::
    

    --* Check if turning straight to straight
    if not turning and frontBeltDir ~= beltDir and not turnBeltSwitch:match(frontBeltName) and flatBeltSwitch:match(frontBeltName) then

        newLane = getDirectionChangeLane(beltDir, frontBeltDir)

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

    ::turnLogicSkip::

    --* Check if there is enough room
    if not findRoom(newPosition, 0.2) then return false end
    
    if turned then
        local rotation = object:get_yaw()
        if rotation ~= 0 then
            rotation = 0
        else
            rotation = math.pi / 2
        end

        object:set_yaw(rotation)

        self:setLane(newLane)
    end

    object:move_to(newPosition, false)
end


function beltItem:on_step(delta)
    local object = self.object
    self:movement(object)
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