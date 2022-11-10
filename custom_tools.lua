local newVec = vector.new

-- This is a translation attempt out of D but done really badly - now yoinked from luatic

local function write(...)
    local rope = {...}
    for i = 1, select("#", ...) do
        rope[i] = tostring(rope[i])
    end
    print(table.concat(rope))
end

-- Original code is here: https://stackoverflow.com/questions/47956954/read-only-iterable-table-in-lua

local function readonly_newindex()
    error("Cannot modify immutable table!")
end

local function immutablePairs(tbl)
    if next(tbl) == nil then
        local mt = getmetatable(tbl)
        if mt and mt.__newindex == readonly_newindex then
            tbl = mt.__index
        end
    end
    return pairs(tbl)
end

-- I wrote this part, a whole new letter added on

local function immutableIpairs(tbl)
    if next(tbl) == nil then
        local mt = getmetatable(tbl)
        if mt and mt.__newindex == readonly_newindex then
            tbl = mt.__index
        end
    end
    return ipairs(tbl)
end

-- Original code is here: https://www.lua.org/pil/13.4.5.html

local function immutable(t)
    local proxy = {}
    local mt = {       -- create metatable
        __index = t,
        __newindex = readonly_newindex
    }
    setmetatable(proxy, mt)
    return proxy
end

-- A lua switch statement

local switch = {}

function switch:new(case_table)
    local object = {
        case_table = case_table
    }
    setmetatable(object, self)
    self.__index = self;
    return immutable(object)
end

-- let the programmer actually use it during runtime for matching cases
function switch:match(case, ...)
    -- only check against existing cases
    if self.case_table[case] then
        return self.case_table[case](...)
    end
    -- There's your fancy D default
    if self.case_table.default then
        return self.case_table.default(...)
    end
    return nil
end

-- Simpler switch
local boolSwitch = {}

function boolSwitch:new(case_table)
    local object = {
        case_table = case_table
    }
    setmetatable(object, self)
    self.__index = self;
    return immutable(object)
end

function boolSwitch:match(case)
    if self.case_table[case] then
        return true
    end
    return false
end

-- Simpler switch, don't feel like rewriting everything
local simpleSwitch = {}

function simpleSwitch:new(case_table)
    local object = {
        case_table = case_table
    }
    setmetatable(object, self)
    self.__index = self;
    return object
end

function simpleSwitch:match(case)
    if self.case_table[case] then
        return self.case_table[case]
    end
    return nil
end



-- I wrote this because I am very lazy

local stringSwitch = switch:new({
    string = function(stringBuilder, input)
        return stringBuilder .. input
    end,
    default = function(stringBuilder, input)
        return stringBuilder .. tostring(input)
    end
})

local function buildString(...)
    local stringBuilder = ""
    for _,word in ipairs({...}) do
        stringBuilder = stringSwitch:match(type(word), stringBuilder, word)
    end
    return stringBuilder
end

-- This is pulled from master branch - Modified because I felt like it
local dirSwitchX = switch:new({
    [true]  = function() return 3 end,
    [false] = function() return 1 end
})
local dirSwitchZ = switch:new({
    [true]  = function() return 2 end,
    [false] = function() return 0 end
})
local dirMasterSwitch = switch:new({
    [true]  = function(dir) return dirSwitchX:match(dir.x < 0) end,
    [false] = function(dir) return dirSwitchZ:match(dir.z < 0) end
})
local function dirToFourDir(dir)
    return dirMasterSwitch:match(math.abs(dir.x) > math.abs(dir.z), dir)
end

-- Table of possible dirs
local facedir_to_dir = {
	vector.new( 0,  0,  1),
	vector.new( 1,  0,  0),
	vector.new( 0,  0, -1),
	vector.new(-1,  0,  0),
	vector.new( 0, -1,  0),
	vector.new( 0,  1,  0),
}
-- Mapping from facedir value to index in facedir_to_dir.
local facedir_to_dir_map = {
	[0]=1, 2, 3, 4,
	5, 2, 6, 4,
	6, 2, 5, 4,
	1, 5, 3, 6,
	1, 6, 3, 5,
	1, 4, 3, 2,
}

local function fourDirToDir(fourdir)
	return facedir_to_dir[facedir_to_dir_map[fourdir % 4]]
end


-- Makes the belt face the direction the player expects
local function convertDir(inputDir)
    return (inputDir + 2) % 4
end

local function vec2(x,y)
    return newVec(x,y,0)
end

-- Give the vector a correct-er position to floor
local positionAdjustment = immutable(vector.new(0.5,0.5,0.5))

local function adjustFloor(inputVec)
    return vector.add(inputVec, positionAdjustment)
end

local function entityFloor(object)
    return vector.floor(adjustFloor(object:get_pos()))
end

-- Very lazy functions
local function extractName(nodeIdentity)
    return nodeIdentity.name
end

local function extractDirection(nodeIdentity)
    return nodeIdentity.param2
end

-- We've hit the bottom of the barrel with this one
local noMovement = vector.zero()
local function debugParticle(position)
    minetest.add_particle({
        pos = position,
        velocity = noMovement,
        acceleration = noMovement,
        expirationtime = 1,
        size = 1,
        collisiondetection = false,
        texture = "default_stone.png",
    })
end

-- Why did I make this
local function ternary(case, option1, option2)
    if case then
        return option1
    else
        return option2
    end
end

-- I'm actually surprised these two functions are missing from both LuaJIT and Minetest
function math.fma(x, y, z)
    return (x * y) + z
end
local fma = math.fma
--* Interpolation amount is a value in range of 0.0 to 1.0
function vector.lerp(vectorOrigin, vectorDestination, interpolationAmount)
    return newVec(
        fma(vectorDestination.x - vectorOrigin.x, interpolationAmount, vectorOrigin.x),
        fma(vectorDestination.y - vectorOrigin.y, interpolationAmount, vectorOrigin.y),
        fma(vectorDestination.z - vectorOrigin.z, interpolationAmount, vectorOrigin.z)
    )
end




-- There are two ways to do this: _, _, _ or {_, _, _}. I like the second one better
return {
    switch           = switch,
    boolSwitch       = boolSwitch,
    simpleSwitch     = simpleSwitch,
    write            = write,
    immutable        = immutable,
    immutableIpairs  = immutableIpairs,
    immutablePairs   = immutablePairs,
    buildString      = buildString,
    dirToFourDir     = dirToFourDir,
    fourDirToDir     = fourDirToDir,
    convertDir       = convertDir,
    vec2             = vec2,
    entityFloor      = entityFloor,
    extractName      = extractName,
    extractDirection = extractDirection,
    debugParticle    = debugParticle,
    ternary          = ternary
}