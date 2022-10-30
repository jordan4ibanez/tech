local function write(...)
    local stringBuilder = ""
    for _,val in pairs({...}) do
        stringBuilder = stringBuilder .. ((dump(val):match("%\"(%a+)%\"")) or tostring(val) or dump(val) or val or nil) -- Or quantum error
    end
    print(stringBuilder)
end

-- Original code is here: https://stackoverflow.com/questions/47956954/read-only-iterable-table-in-lua

local function readonly_newindex(_, _, _)
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
    return nil
end

-- There are two ways to do this: _, _, _ or {_, _, _}. I like the second one better
return {
    switch          = switch,
    write           = write,
    immutable       = immutable,
    immutableIpairs = immutableIpairs,
    immutablePairs  = immutablePairs,

}