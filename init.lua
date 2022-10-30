local getModName = minetest.get_current_modname
local getModPath = minetest.get_modpath;

print(getModPath(getModName()) .. "\\custom_tools.lua")

local customTools = dofile(getModPath(getModName()) .. "/custom_tools.lua")
local switch          = customTools.switch
local write           = customTools.write
local immutable       = customTools.immutable
local immutableIpairs = customTools.immutableIpairs
local immutablePairs  = customTools.immutablePairs

--! No animation because that's not implemented into Minetest

local beltSpeeds = immutable({1,2,3})
local beltAngles = immutable({0,45,-45})

for _,val in immutableIpairs(beltAngles) do
    local definition = {
        paramtype = "light",
        paramtype2 = "4dir",

    }
    minetest.register_node("tech:" .. tostring(angle) .. ,definition);
end
