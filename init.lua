local getModName           = minetest.get_current_modname
local getModPath           = minetest.get_modpath;
-- Jordan4ibanez functions
local customTools = dofile(getModPath(getModName()) .. "/custom_tools.lua")
local switch               = customTools.switch
local write                = customTools.write
local immutable            = customTools.immutable
local immutableIpairs      = customTools.immutableIpairs
local immutablePairs       = customTools.immutablePairs
local buildString          = customTools.buildString
local dirToFourDir         = customTools.dirToFourDir
local convertDir           = customTools.convertDir
-- Minetest functions
local registerNode         = minetest.register_node
local getNode              = minetest.get_node
local setNode              = minetest.set_node
local onLoaded             = minetest.register_on_mods_loaded
local registerEntity       = minetest.register_entity
local registeredNodes      = minetest.registered_nodes
local registeredItems      = minetest.registered_items --? Why are these two different?
local registeredCraftItems = minetest.registered_craftitems
local newVec               = vector.new

local function vec2(x,y)
    return newVec(x,y,0)
end


--! No animation because that's not implemented into Minetest

local beltSpeeds = immutable({ 1, 2, 3})
local beltAngles = immutable({-45, 0, 45})
local beltSwitch = {}

for _,beltSpeed in immutableIpairs(beltSpeeds) do
for _,beltAngle in immutableIpairs(beltAngles) do

    local angleConversion = tostring(beltAngle):gsub("-", "negative_")

    local nameString = buildString(
        "tech:belt_", angleConversion, "_", beltSpeed
    )

    -- Automate data extraction during runtime
    beltSwitch[nameString] = function()
        return beltSpeed, beltAngle
    end

    -- Todo: Make belts act like rails
    local definition = {
        paramtype  = "light",
        paramtype2 = "facedir",
        drawtype   = "mesh",
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




--! Beginning of the inserter object

local inserterAnimations = switch:new({
    unpack   = function()
        return vec2(1,20), 20, 0, false
    end,
    selfTest = function()
        return vec2(20,40), 60, 0, false
    end,
    fullyInitialize = function()
        return vec2(40,60), 30, 0, false
    end
})

local inserter = {
    initial_properties = {
        visual = "mesh",
        mesh = "inserter.b3d",
        textures ={"default_dirt.png"}
    },
    animationTimer = 0.0,
    boot = true,
    bootStage = 0
}

-- Animation mechanics
function inserter:setAnimation(animation)
    self.object:set_animation(inserterAnimations:match(animation))
end

function inserter:animationTick(delta)
    self.animationTimer = self.animationTimer + delta
    return self.animationTimer
end
function inserter:resetAnimationTimer()
    self.animationTimer = 0
end

-- Inserter boot procedure
local bootSwitch = switch:new({
    [0] = function(self)
        if self.animationTimer >= 1.5 then
            self:setAnimation("selfTest")
            self:resetAnimationTimer()
            self.bootStage = self.bootStage + 1;
        end
    end,
    [1] = function(self)
        if self.animationTimer >= 1.5 then
            self:setAnimation("fullyInitialize")
            self:resetAnimationTimer()
            self.bootStage = self.bootStage + 1;
        end
    end,
    [2] = function(self)
        if self.animationTimer >= 1.5 then
            -- Boot procedure complete
            self.bootStage = -1
            self.boot = false
        end

    end
})

function inserter:bootProcedure()
    if not self.boot then return end
    bootSwitch:match(self.bootStage, self)
end

--! No idea how to fix the rotation in blender
local rotationFix = newVec(math.pi / 2, 0, 0)
function inserter:on_activate()
    self.object:set_rotation(rotationFix)
    self:setAnimation("unpack")
end



function inserter:on_step(delta)
    local animationTimer = self:animationTick(delta)
    self:bootProcedure()
end


registerEntity("tech:inserter", inserter)













--! Beginning of belt item object

local beltItem = {
    flooredPosition = nil,
    oldPosition     = nil
}

-- Give the vector a correct-er position to floor
local adjustment = immutable(vector.new(0.5,0.5,0.5))
local function adjustFloor(inputVec)
    return vector.add(inputVec, adjustment)
end

-- Get the floored position
function beltItem:pollPosition(object)
    local flooredPosition = vector.floor(adjustFloor(object:get_pos()))

    if not self.flooredPosition or not vector.equals(self.flooredPosition, flooredPosition) then
        self.flooredPosition = flooredPosition
    end
end

-- When the object comes into existence
function beltItem:on_activate(staticdata, dtime_s)
    self:pollPosition(self.object)
    self:saveStepMemory()
end

-- Save memory for the next server step
function beltItem:saveStepMemory()
    if not self.oldPosition or not vector.equals(self.flooredPosition, self.oldPosition) then
        self.oldPosition = vector.copy(self.flooredPosition)
    end
end

-- This is a hack to make the things move on the belts for now
local vec0 = immutable(vector.new( 0, 0,-1))
local vec1 = immutable(vector.new(-1, 0, 0))
local vec2 = immutable(vector.new( 0, 0, 1))
local vec3 = immutable(vector.new( 1, 0, 0))
local directionSwitch = switch:new({
    [0] = function(object)
        object:set_velocity(vec0)
    end,
    [1] = function(object)
        object:set_velocity(vec1)
    end,
    [2] = function(object)
        object:set_velocity(vec2)
    end,
    [3] = function(object)
        object:set_velocity(vec3)
    end,
})

-- Very lazy functions
local function extractName(nodeIdentity)
    return nodeIdentity.name
end
local function extractDirection(nodeIdentity)
    return nodeIdentity.param2
end

function beltItem:pollBelt(object)
    local position = self.flooredPosition
    local nodeIdentity = getNode(position)
    local beltName = extractName(nodeIdentity)
    local beltDir  = extractDirection(nodeIdentity)
    local beltSpeed, beltAngle = beltSwitch:match(beltName)

    if beltSpeed then
        -- write(beltSpeed, " ", beltAngle, " ", beltDir)
        directionSwitch:match(beltDir, object)
    else
        write("I ain't on no belt")
    end
end

function beltItem:on_step(delta)
    local object = self.object
    
    self:pollPosition(object)

    self:pollBelt(object)
    
    self:saveStepMemory()
end

-- Todo: Make this do a thing!
registerEntity("tech:beltItem", beltItem)