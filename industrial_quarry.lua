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
local dirToYaw             = minetest.dir_to_yaw
local yawToDir             = minetest.yaw_to_dir
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

local HALF_PI = math.pi / 2
local WIDTH   = 8
local frameString = buildString("tech:quarry_frame_", tier)
local frameTextureString = buildString("tech_quarry_frame_", tier, ".png")

local frameEntityTextureString = buildString("[combine:", (((WIDTH * 2) - 1) * 16), "x16")
for i = 0, (WIDTH * 2) - 2 do
    frameEntityTextureString = buildString(frameEntityTextureString, ":", i * 16, ",0=", frameTextureString)
end
local frameEntityTextureStringR90 = buildString(frameEntityTextureString, "^[transformR90")


local frameEntity = {
    visual = "cube",
    visual_size = {
        x = 1,
        y = 1,
        z = (WIDTH * 2) - 1
    },
    textures = {
        frameEntityTextureStringR90,
        frameEntityTextureStringR90,
        frameEntityTextureString,
        frameEntityTextureString,
        frameTextureString,
        frameTextureString
    },
    axis = 0
}

function frameEntity:setAxis(newAxis)
    self.axis = newAxis
end

-- Axis X is 0, Z is 1
function frameEntity:sendTo(newPosition)
    local position = self.object:get_pos()

    if self.axis == 0 then
        position.x = newPosition.x
    else
        position.z = newPosition.z
    end
    self.object:move_to(position)
end

registerEntity(
    frameString,
    frameEntity
)

registerNode(
    frameString,
    {
        paramtype  = "light",
        drawtype   = "normal",
        tiles      = {frameTextureString}
    }
)

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
    local meta = getMeta(position)
    local inv = meta:get_inventory()
    inv:set_size("main", 8*4)
    meta:set_string("formspec", quarryFormspec)

    -- Start this thing up
    meta:set_int("setUpStep", 12)
    meta:set_int("distance", 1)
    getTimer(position):start(0)
end

local function addDrill(position, vectorDirection)
    local newPosition = vecCopy(position)

    local yaw = dirToYaw(vectorDirection)
    local newOffset = vecCopy(vectorDirection)

    newOffset = vecMultiply(newOffset, -WIDTH)
    newOffset.y = newOffset.y + (WIDTH * 2)
    newPosition = vecAdd(newPosition, newOffset)

    local adjacentFrame = addEntity(newPosition, frameString)
    local oppositeFrame = addEntity(newPosition, frameString)

    --! Check if the entity exists
    if adjacentFrame then
        adjacentFrame:set_yaw(yaw)
        local luaEntity = adjacentFrame:get_luaentity()
        if vectorDirection.x ~= 0 then
            luaEntity:setAxis(1)
        else
            luaEntity:setAxis(0)
        end
    end

    yaw = yaw - HALF_PI

    --! Check if the entity exists
    if oppositeFrame then
        oppositeFrame:set_yaw(yaw)
        local luaEntity = oppositeFrame:get_luaentity()
        if vectorDirection.x ~= 0 then
            luaEntity:setAxis(0)
        else
            luaEntity:setAxis(1)
        end
    end

    newPosition = vecCopy(position)
    newOffset = vecCopy(vectorDirection)
    
    local leftOffset = yawToDir(yaw)

    leftOffset = vecMultiply(leftOffset, (WIDTH) - 1)
    newOffset = vecMultiply(newOffset, (-WIDTH * 2) + 1)
    newPosition = vecAdd(newPosition, newOffset)
    newPosition.y = newPosition.y + (WIDTH * 2)
    newPosition = vecAdd(newPosition, leftOffset)

    --! This should probably check if the entity exists
    if adjacentFrame and oppositeFrame then
        adjacentFrame:get_luaentity():sendTo(newPosition)
        oppositeFrame:get_luaentity():sendTo(newPosition)
    end
end

--! This will clobber anything in it's path, so be careful
local function setUp(position, meta, step, vectorDirection)

    local yaw = dirToYaw(vectorDirection)

    local function setDistance(newDistance)
        meta:set_int("distance", newDistance)
    end
    local function setStep(newStep)
        meta:set_int("setUpStep", newStep)
    end
    local function buildFrame(newPosition)
        digNode(newPosition)
        setNode(newPosition, {name = frameString})
        playSound("tech_quarry_build", {pos = newPosition})
    end

    local distance = meta:get_int("distance")

    --! Turn this mess into a switch
    -- Building right side next to main node
    if step == 1 then
        -- Move it right
        local localYaw = yaw + HALF_PI
        local localDir = yawToDir(localYaw)
        local currentPoint = vecAdd(vecMultiply(localDir, distance), position)
        buildFrame(currentPoint)
        if distance < WIDTH then
            setDistance(distance + 1)
        else
            setDistance(1)
            setStep(step + 1)
        end
    -- Building left side next to main node
    elseif step == 2 then
        -- Move it left
        local localYaw = yaw - HALF_PI
        local localDir = yawToDir(localYaw)
        local currentPoint = vecAdd(vecMultiply(localDir, distance), position)
        buildFrame(currentPoint)
        if distance < WIDTH then
            setDistance(distance + 1)
        else
            setDistance(1)
            setStep(step + 1)
        end
    -- Building the right side forward
    elseif step == 3 then
        -- Move it right
        local localYaw = yaw + HALF_PI
        local localDir = yawToDir(localYaw)
        local currentPoint = vecAdd(vecMultiply(localDir, 8), position)
        -- Move it forward
        currentPoint = vecAdd(currentPoint, vecMultiply(vectorDirection, -distance))
        buildFrame(currentPoint)
        if distance < WIDTH * 2 then
            setDistance(distance + 1)
        else
            setDistance(1)
            setStep(step + 1)
        end
    -- Building the left side forward
    elseif step == 4 then
        -- Move it left
        local localYaw = yaw - HALF_PI
        local localDir = yawToDir(localYaw)
        local currentPoint = vecAdd(vecMultiply(localDir, 8), position)
        -- Move it forward
        currentPoint = vecAdd(currentPoint, vecMultiply(vectorDirection, -distance))
        buildFrame(currentPoint)
        if distance < WIDTH * 2 then
            setDistance(distance + 1)
        else
            setDistance(1)
            setStep(step + 1)
        end

    -- Building the back bottom
    elseif step == 5 then
        -- Move it right
        local localYaw = yaw + HALF_PI
        local localDir = yawToDir(localYaw)
        local currentPoint = vecAdd(vecMultiply(localDir, 8), position)
        -- Move it forward
        currentPoint = vecAdd(currentPoint, vecMultiply(vectorDirection, (-WIDTH * 2)))
        -- Move it left
        localYaw = yaw - HALF_PI
        localDir = yawToDir(localYaw)
        currentPoint = vecAdd(vecMultiply(localDir, distance), currentPoint)

        buildFrame(currentPoint)

        if distance < (WIDTH * 2) - 1 then
            setDistance(distance + 1)
        else
            setDistance(1)
            setStep(step + 1)
        end

    -- Building right support
    elseif step == 6 then
        -- Move it right
        local localYaw = yaw + HALF_PI
        local localDir = yawToDir(localYaw)
        local currentPoint = vecAdd(vecMultiply(localDir, 8), position)
        -- Move it up
        currentPoint = vecAdd(newVec(0,distance,0), currentPoint)

        buildFrame(currentPoint)

        if distance < WIDTH * 2 then
            setDistance(distance + 1)
        else
            setDistance(1)
            setStep(step + 1)
        end
    -- Building the left support
    elseif step == 7 then
        -- Move it left
        local localYaw = yaw - HALF_PI
        local localDir = yawToDir(localYaw)
        local currentPoint = vecAdd(vecMultiply(localDir, 8), position)
        -- Move it up
        currentPoint = vecAdd(newVec(0,distance,0), currentPoint)

        buildFrame(currentPoint)

        if distance < WIDTH * 2 then
            setDistance(distance + 1)
        else
            setDistance(1)
            setStep(step + 1)
        end
    -- Building back right support
    elseif step == 8 then
        -- Move it right
        local localYaw = yaw + HALF_PI
        local localDir = yawToDir(localYaw)
        local currentPoint = vecAdd(vecMultiply(localDir, 8), position)
        -- Move it forward
        currentPoint = vecAdd(currentPoint, vecMultiply(vectorDirection, (-WIDTH * 2)))
        -- Move it up
        currentPoint = vecAdd(newVec(0,distance,0), currentPoint)

        buildFrame(currentPoint)

        if distance < WIDTH * 2 then
            setDistance(distance + 1)
        else
            setDistance(1)
            setStep(step + 1)
        end
    -- Building the back left support
    elseif step == 9 then
        -- Move it left
        local localYaw = yaw - HALF_PI
        local localDir = yawToDir(localYaw)
        local currentPoint = vecAdd(vecMultiply(localDir, 8), position)
        -- Move it forward
        currentPoint = vecAdd(currentPoint, vecMultiply(vectorDirection, (-WIDTH * 2)))
        -- Move it up
        currentPoint = vecAdd(newVec(0,distance,0), currentPoint)

        buildFrame(currentPoint)

        if distance < WIDTH * 2 then
            setDistance(distance + 1)
        else
            setDistance(1)
            setStep(step + 1)
        end
    -- Building the top front
    elseif step == 10 then
        -- Move it right
        local localYaw = yaw + HALF_PI
        local localDir = yawToDir(localYaw)
        local currentPoint = vecAdd(vecMultiply(localDir, 8), vecAdd(position, newVec(0,WIDTH * 2, 0)))
        -- Move it left
        localYaw = yaw - HALF_PI
        localDir = yawToDir(localYaw)
        currentPoint = vecAdd(vecMultiply(localDir, distance), currentPoint)

        buildFrame(currentPoint)

        if distance < (WIDTH * 2) - 1 then
            setDistance(distance + 1)
        else
            setDistance(1)
            setStep(step + 1)
        end

    -- Building the top right
    elseif step == 11 then
        -- Move it right
        local localYaw = yaw + HALF_PI
        local localDir = yawToDir(localYaw)
        local currentPoint = vecAdd(vecMultiply(localDir, 8), vecAdd(position, newVec(0,WIDTH * 2, 0)))
        -- Move it forward
        currentPoint = vecAdd(currentPoint, vecMultiply(vectorDirection, -distance))
        buildFrame(currentPoint)
        if distance < (WIDTH * 2) - 1 then
            setDistance(distance + 1)
        else
            setDistance(1)
            setStep(step + 1)
        end
    -- Building the top left
    elseif step == 12 then
        -- Move it left
        local localYaw = yaw - HALF_PI
        local localDir = yawToDir(localYaw)
        local currentPoint = vecAdd(vecMultiply(localDir, 8), vecAdd(position, newVec(0,WIDTH * 2, 0)))
        -- Move it forward
        currentPoint = vecAdd(currentPoint, vecMultiply(vectorDirection, -distance))
        buildFrame(currentPoint)
        if distance < (WIDTH * 2) - 1 then
            setDistance(distance + 1)
        else
            setDistance(1)
            setStep(step + 1)
        end
    -- Building the top back
    elseif step == 13 then
        -- Move it right
        local localYaw = yaw + HALF_PI
        local localDir = yawToDir(localYaw)
        local currentPoint = vecAdd(vecMultiply(localDir, 8), vecAdd(position, newVec(0,WIDTH * 2, 0)))
        -- Move it forward
        currentPoint = vecAdd(currentPoint, vecMultiply(vectorDirection, (-WIDTH * 2)))
        -- Move it left
        localYaw = yaw - HALF_PI
        localDir = yawToDir(localYaw)
        currentPoint = vecAdd(vecMultiply(localDir, distance), currentPoint)

        buildFrame(currentPoint)

        if distance < (WIDTH * 2) - 1 then
            setDistance(distance + 1)
        else
            setDistance(0)
            setStep(0)
            playSound("tech_inserter_startup", {pos = position})
            addDrill(position, vectorDirection)
        end
    end
end

local function checkForIron(inv)
    local gottenItem = inv:remove_item("main", ItemStack("default:steel_ingot")):get_name()
    return true
    --if gottenItem == "" then return false end
    --return true

end

function quarry:on_timer()
    -- Try not to trash the game with 5 second intervals
    local refreshTime = 5

    local meta      = getMeta(self)
    local inv       = meta:get_inventory()
    local setUpStep = meta:get_int("setUpStep")
    local timer     = getTimer(self)
    local vectorDirection = fourDirToDir(extractDirection(getNode(self)))

    -- Building self
    if setUpStep > 0 and checkForIron(inv) then
        setUp(self, meta, setUpStep, vectorDirection)
        refreshTime = 0.25 / tier
    -- Mining
    else
        
    end

    timer:start(refreshTime)
end

registerNode(
    quarryNodeString,
    quarry
)



end