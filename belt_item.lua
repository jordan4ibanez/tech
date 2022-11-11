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
local dirToYaw             = minetest.dir_to_yaw
local yawToDir             = minetest.yaw_to_dir
local newVec               = vector.new
local vecZero              = vector.zero
local vecMultiply          = vector.multiply
local vecAdd               = vector.add
local vecFloor             = vector.floor
local vecRound             = vector.round
local vecDirection         = vector.direction
local vecCopy              = vector.copy
local vecLerp              = vector.lerp
local serialize            = minetest.serialize
local deserialize          = minetest.deserialize
local objectsInRadius      = minetest.get_objects_inside_radius
local isPlayer             = minetest.is_player

-- Lua functions
local floor = math.floor
local abs   = math.abs

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

    integerPosition     = vecZero(),
    nextIntegerPosition = vecZero(),
    originPosition      = vecZero(),
    destinationPosition = vecZero(),
    movementProgress    = 0,
    speed = 0,
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
    write("I am on lane ", lane)
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
    ["1 2"] = 2,
    ["3 2"] = 1,
    -- 1
    ["2 3"] = 2,
    ["0 3"] = 1,
    -- 2
    ["3 0"] = 2,
    ["1 0"] = 1,
    -- 3
    ["0 1"] = 2,
    ["2 1"] = 1
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

local function resolveBeltEntity(self, object)
    if not object then return false end
    if isPlayer(object) then return false end
    object = object:get_luaentity()
    if not object then return false end
    if not object.name then return false end
    if object == self then return false end
    if object.name == "tech:beltItem" then return true end
end

function beltItem:findRoom(searchingPosition, radius)
    for _,gottenObject in ipairs(objectsInRadius(searchingPosition, radius)) do
        if resolveBeltEntity(self, gottenObject) then
            return false
        end
    end
    return true
end

function beltItem:movement(object, delta)

    -- Initial scan the belt is is on
    if not beltSwitch:match(getNode(self.integerPosition).name) then
        addItem(self.integerPosition, self.itemString)
        object:remove()
        return false
    end

    local failure = false

    debugParticle(self.integerPosition)

    --! This is debug
    if self.originPosition then
        debugParticle(self.originPosition)
        debugParticle(self.destinationPosition)
        debugParticle(self.nextIntegerPosition)
    end
    

    -- Still moving along the belt
    local oldProgress = self.movementProgress
    if self.movementProgress < 1 then
        self.movementProgress = self.movementProgress + delta
        if self.movementProgress >= 1 then
            self.movementProgress = 1
        end
    else
        -- Has to be inverted due to logic gate
        failure = not self:updatePosition(self.nextIntegerPosition)
    end

    if failure then
        self.movementProgress = oldProgress
        return false
    end

    local newPosition = vecLerp(self.originPosition, self.destinationPosition, self.movementProgress)

    if not self:findRoom(newPosition, 0.2) then
        self.movementProgress = oldProgress
        return
    end

    object:move_to(newPosition)
end

function beltItem:setMovementProgress(movementProgress)
    self.movementProgress = movementProgress
end

--* Returns true if could update, false if failure. This is getting the direction on the NEXT node
function beltItem:updatePosition(pos, initialPlacement)
    -- Create a new heap object
    local position = vecCopy(pos)

    local integerPosition = vecRound(position)
    local nodeIdentity  = getNode(integerPosition)
    local nodeName      = extractName(nodeIdentity)

    --! Something has gone extremely wrong if this is on the intial position

    local beltSpeed, beltAngle = beltSwitch:match(nodeName)

    if not beltSpeed then

        -- Try to get a downward belt
        integerPosition.y = integerPosition.y - 1
        nodeIdentity = getNode(integerPosition)
        nodeName     = extractName(nodeIdentity)

        beltSpeed, beltAngle = beltSwitch:match(nodeName)

        -- There's no downward belt there
        if not beltSpeed or beltAngle ~= -45 then
            return false
        end

    end

    local nodeDirection     = extractDirection(nodeIdentity)
    local oldNodeDirection  = extractDirection(getNode(self.integerPosition))

    local storageIntegerPosition
    local storageNextIntegerPosition
    local storageOriginPosition
    local storageDestinationPosition
    local storageMovementProgress
    local laneStorage = self.lane

    if beltAngle == 45 then
        -- Do things
        write("Wow, a 45 belt")
    elseif beltAngle == -45 then
        -- Do things
        write("Wow, a -45 belt")
    elseif flatBeltSwitch:match(nodeName) then

        local doLanePositionCalculation = false

        -- Going straight
        if initialPlacement or nodeDirection == oldNodeDirection then
            storageMovementProgress = 0
        else
            local newLane = getDirectionChangeLane(nodeDirection, oldNodeDirection)
            doLanePositionCalculation = true
            if not newLane then return false end
            laneStorage = newLane
        end
        

        local vectorDirection = fourDirToDir(nodeDirection)
        -- Due to how this was set up, this is inverted
        local inverseDirection = vecMultiply(vectorDirection, 0.5)
        local direction = vecMultiply(inverseDirection, -1)
        -- Set the rigid inline positions - They are on the center of the node
        local originPosition      = vecAdd(integerPosition, inverseDirection)
        local destinationPosition = vecAdd(integerPosition, direction)
        -- The lane is 90 degrees adjacent to the direction
        local directionModifier = ternary(laneStorage == 1, 1, -1) * (math.pi / 2)
        local yaw = dirToYaw(direction) + directionModifier
        local laneDirection = vecMultiply(vecRound(yawToDir(yaw)), 0.25)

        -- Now store the values outside this scope
        storageIntegerPosition     = integerPosition
        storageNextIntegerPosition = vecAdd(integerPosition, vecMultiply(vectorDirection, -1))
        storageOriginPosition      = vecAdd(originPosition, laneDirection)
        storageDestinationPosition = vecAdd(destinationPosition, laneDirection)

        -- Needs to calculate a new offset to the direction
        if doLanePositionCalculation then

            local floatingPosition = self.object:get_pos()

            local start
            local offset

            if direction.x ~= 0 then
                start  = storageOriginPosition.x
                offset = floatingPosition.x - start
                storageMovementProgress = abs(offset)
            elseif direction.z ~= 0 then
                start  = storageOriginPosition.z
                offset = floatingPosition.z - start
                storageMovementProgress = abs(offset)
            end

            if not storageMovementProgress then
                storageMovementProgress = 0
            end
        end
    end

    local newPosition = vecLerp(storageOriginPosition, storageDestinationPosition, storageMovementProgress)

    if not self:findRoom(newPosition, 0.2) then return false end

    -- If it found room, set the new values
    self.integerPosition     = storageIntegerPosition
    self.nextIntegerPosition = storageNextIntegerPosition
    self.originPosition      = storageOriginPosition
    self.destinationPosition = storageDestinationPosition
    self.movementProgress    = storageMovementProgress
    self.lane                = laneStorage
    
    return true
end


function beltItem:on_step(delta)
    local object = self.object
    self:movement(object, delta)
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