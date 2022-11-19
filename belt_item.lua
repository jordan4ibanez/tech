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
local vecDistance          = vector.distance
local vecLength            = vector.length
local vecCopy              = vector.copy
local vecEquals            = vector.equals
local vecLerp              = vector.lerp
local vecNormalize         = vector.normalize
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
local switchBeltSwitch = grabSwitchBeltsSwitch()

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
end


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


local function resolveBeltEntity(self, object, searchingPosition, originPosition, destinationPosition, disableDirCheck)
    if not object then return false end
    if isPlayer(object) then return false end
    object = object:get_luaentity()
    if not object then return false end
    if object == self then return false end
    if not object.name then return false end
    if object.name ~= "tech:beltItem" then return false end
    
    local pos1 = searchingPosition
    local pos2 = object.object:get_pos()
        
    -- This is a glitch due to stack operations, force pass it through
    --[[
    if vecDistance(pos1, pos2) == 0 then
        -- write("Heisenbug has occured due to stack operations")
        return false
    end
    ]]

    local p1 = originPosition
    local p2 = destinationPosition
    local selfDir = vecDirection(
        newVec(p1.x, 0, p1.z),
        newVec(p2.x, 0, p2.z)
    )
    local objectPos2d = newVec(
        pos2.x, 0, pos2.z
    )
    local p3 = searchingPosition
    local selfPosition2d = newVec(
        p3.x, 0, p3.z
    )
    
    if not disableDirCheck then
        local dirToObject = vecNormalize(vecDirection(selfPosition2d, objectPos2d))

        if selfDir.x ~= 0 then
            if dirToObject.x ~= selfDir.x then return false end
        else
            if dirToObject.z ~= selfDir.z then return false end
        end
    end

    
    local size = 0.249

    local minX1 = pos1.x - size
    local minX2 = pos2.x - size
    local maxX1 = pos1.x + size
    local maxX2 = pos2.x + size

    local minZ1 = pos1.z - size
    local minZ2 = pos2.z - size
    local maxZ1 = pos1.z + size
    local maxZ2 = pos2.z + size

    -- Exclusion 2D collision detection
    return not (minX1 > maxX2 or maxX1 < minX2 or
               minZ1 > maxZ2 or maxZ1 < minZ2)
end

function beltItem:findRoom(searchingPosition, radius, originPosition, destinationPosition, disableDirCheck)
    for _,gottenObject in ipairs(objectsInRadius(searchingPosition, radius)) do
        if resolveBeltEntity(self, gottenObject, searchingPosition, originPosition, destinationPosition, disableDirCheck) then
            return false
        end
    end
    return true
end

function beltItem:movement(object, delta)

    -- Initial scan the belt is is on
    if not beltSwitch:match(getNode(self.integerPosition).name) then
        if vecEquals(self.integerPosition, vecZero()) then
            local position = object:get_pos()
            write("A item has glitched out at ", position.x, ", ", position.y, ", ", position.z)
        end
        addItem(self.integerPosition, self.itemString)
        object:remove()
        return false
    end

    local failure = false


    --[[
    --! This is debug
    debugParticle(self.integerPosition)
    if self.originPosition then
        debugParticle(self.originPosition)
        debugParticle(self.destinationPosition)
        debugParticle(self.nextIntegerPosition)
    end
    ]]
    

    -- Still moving along the belt
    local oldProgress = self.movementProgress
    if self.movementProgress < 1 then
        self.movementProgress = self.movementProgress + (self.speed / 10)
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

    if not self:findRoom(newPosition, 0.3, self.originPosition, self.destinationPosition) then
        self.movementProgress = oldProgress
        return
    end

    object:move_to(newPosition, false)
    -- object:set_pos(newPosition)
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
    local nodeDirection = extractDirection(nodeIdentity)

    --! Something has gone extremely wrong if this is on the intial position
    local beltSpeed, beltAngle = beltSwitch:match(nodeName)

    -- Have to get old data or else there are A LOT of glitches
    local oldNodeIdentity = getNode(self.integerPosition)
    local oldNodeName     = extractName(oldNodeIdentity)
    local oldNodeDirection  = extractDirection(oldNodeIdentity)
    local oldBeltSpeed, oldBeltAngle = beltSwitch:match(oldNodeName)

    local upGlitch = false
    -- Some rigid logic gates for glitches, teleport & phasing
    if oldBeltAngle == 45 and beltAngle == 0 then
        -- write("glitch 1")
        upGlitch = true
    elseif oldBeltAngle == 45 and beltAngle == 45 then
        -- write("glitch 2")
        upGlitch = true
    elseif beltAngle ~= 0 and oldNodeDirection ~= nodeDirection and beltAngle ~= nil then
        -- write("glitch 3")
        upGlitch = true
    elseif oldBeltAngle == 0 and beltAngle == -45 then
        -- write("glitch 4")
        upGlitch = true
    end
    

    if upGlitch or not beltSpeed then

        local failure = false

        -- Try to get an upward belt - This takes priority
        do
            integerPosition.y = integerPosition.y + 1
            nodeIdentity = getNode(integerPosition)
            nodeName     = extractName(nodeIdentity)
            nodeDirection = extractDirection(nodeIdentity)
            beltSpeed, beltAngle = beltSwitch:match(nodeName)

            if not beltSpeed or beltAngle == -45 or (beltAngle == 0 and oldBeltAngle == nil) then
                failure = true
            end
        end

        -- Try to get a downward belt
        if failure then
            integerPosition.y = integerPosition.y - 2
            nodeIdentity = getNode(integerPosition)
            nodeName     = extractName(nodeIdentity)
            nodeDirection = extractDirection(nodeIdentity)
            beltSpeed, beltAngle = beltSwitch:match(nodeName)

            if not beltSpeed or beltAngle ~= -45 then
                failure = true
            else
                -- Success!
                failure = false
            end
        end

        -- There are no belts
        if failure then return false end
    end

    local storageIntegerPosition
    local storageNextIntegerPosition
    local storageOriginPosition
    local storageDestinationPosition
    local storageMovementProgress
    local laneStorage = self.lane
    local turning = false
    local disableDirCheck = false

    if beltAngle == 45 then
        local vectorDirection = fourDirToDir(nodeDirection)
        -- Due to how this was set up, this is inverted
        local inverseDirection = vecMultiply(vectorDirection, 0.5)
        local direction = vecMultiply(inverseDirection, -1)
        -- Set the rigid inline positions - They are on the center of the node
        local originPosition      = vecAdd(integerPosition, inverseDirection)
        local destinationPosition = vecAdd(integerPosition, direction)

        -- Needs to have the height or else it'll just be silly
        destinationPosition.y = destinationPosition.y + 1

        -- The lane is 90 degrees adjacent to the direction
        local directionModifier = ternary(laneStorage == 1, 1, -1) * (math.pi / 2)
        local yaw = dirToYaw(direction) + directionModifier
        local laneDirection = vecMultiply(vecRound(yawToDir(yaw)), 0.25)

        -- Now store the values outside this scope
        storageIntegerPosition     = integerPosition
        storageNextIntegerPosition = vecAdd(integerPosition, vecMultiply(vectorDirection, -1))
        storageOriginPosition      = vecAdd(originPosition, laneDirection)
        storageDestinationPosition = vecAdd(destinationPosition, laneDirection)
        storageMovementProgress    = 0

    elseif beltAngle == -45 then
        local vectorDirection = fourDirToDir(nodeDirection)
        -- Due to how this was set up, this is inverted
        local inverseDirection = vecMultiply(vectorDirection, 0.5)
        local direction = vecMultiply(inverseDirection, -1)
        -- Set the rigid inline positions - They are on the center of the node
        local originPosition      = vecAdd(integerPosition, inverseDirection)
        local destinationPosition = vecAdd(integerPosition, direction)

        -- Needs to have the height or else it'll just be silly
        originPosition.y = originPosition.y + 1

        -- The lane is 90 degrees adjacent to the direction
        local directionModifier = ternary(laneStorage == 1, 1, -1) * (math.pi / 2)
        local yaw = dirToYaw(direction) + directionModifier
        local laneDirection = vecMultiply(vecRound(yawToDir(yaw)), 0.25)

        -- Now store the values outside this scope
        storageIntegerPosition     = integerPosition
        storageNextIntegerPosition = vecAdd(integerPosition, vecMultiply(vectorDirection, -1))
        storageOriginPosition      = vecAdd(originPosition, laneDirection)
        storageDestinationPosition = vecAdd(destinationPosition, laneDirection)
        storageMovementProgress    = 0
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

            turning = true
        end
    elseif turnBeltSwitch:match(nodeName) then

        -- Turns can only turn
        if nodeDirection == oldNodeDirection then return end

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

        turning = true
        
    elseif switchBeltSwitch:match(nodeName) then

        -- Add a goto statement for trying it again with a straight belt

        -- Switches are extremely rigid
        if nodeDirection ~= oldNodeDirection then return false end

        -- First do the flat belt calculation
        local vectorDirection = fourDirToDir(nodeDirection)
        -- Due to how this was set up, this is inverted
        local inverseDirection = vecMultiply(vectorDirection, 0.5)
        local direction = vecMultiply(inverseDirection, -1)
        -- Set the rigid inline positions - They are on the center of the node
        local originPosition      = vecAdd(integerPosition, inverseDirection)
        local destinationPosition = vecAdd(integerPosition, direction)
        -- The lane is 90 degrees adjacent to the direction
        local directionModifier = ternary(laneStorage == 1, 1, -1) * (math.pi / 2)
        local yaw = dirToYaw(direction)
        local originalYaw = yaw
        yaw = yaw + directionModifier
        local laneDirection = vecMultiply(vecRound(yawToDir(yaw)), 0.25)
        
        -- Next store the values outside this scope
        storageIntegerPosition     = integerPosition
        storageNextIntegerPosition = vecAdd(integerPosition, vecMultiply(vectorDirection, -1))
        storageOriginPosition      = vecAdd(originPosition, laneDirection)
        storageDestinationPosition = vecAdd(destinationPosition, laneDirection)
        storageMovementProgress = 0

        -- Next get the new switch direction
        yaw = originalYaw + (ternary(nodeName:find("left"), -1, 1) * (math.pi / 2))

        write(yaw)

        if nodeName:find("left") then
            -- write("yep that's left")
        else
            -- write("yep that's to the right now")
        end
        local lanePositionModifier = vecRound(yawToDir(yaw))

        write(dump(lanePositionModifier))

        -- Finally, everything is pushed in that direction
        storageIntegerPosition     = vecAdd(storageIntegerPosition, lanePositionModifier)
        storageNextIntegerPosition = vecAdd(storageNextIntegerPosition, lanePositionModifier)
        storageOriginPosition      = vecAdd(storageOriginPosition, lanePositionModifier)
        storageDestinationPosition = vecAdd(storageDestinationPosition, lanePositionModifier)


        -- debugParticle(vecAdd(storageOriginPosition, lanePositionModifier))

        disableDirCheck = true



        -- return false
    else
        write("this has not been implemented yet")
        return false
    end

    local newPosition = vecLerp(storageOriginPosition, storageDestinationPosition, storageMovementProgress)

    debugParticle(newPosition)
    
    if not self:findRoom(newPosition, 0.35, storageOriginPosition, storageDestinationPosition, disableDirCheck) and not initialPlacement then
        return false
    end

    -- If it found room, set the new values
    self.integerPosition     = storageIntegerPosition
    self.nextIntegerPosition = storageNextIntegerPosition
    self.originPosition      = storageOriginPosition
    self.destinationPosition = storageDestinationPosition
    self.movementProgress    = storageMovementProgress
    self.lane                = laneStorage
    self.speed               = beltSpeed

    if turning then
        local object = self.object
        local rotation = object:get_yaw()
        if rotation ~= 0 then
            rotation = 0
        else
            rotation = math.pi / 2
        end
        object:set_yaw(rotation)
    end
    
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