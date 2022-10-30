local getModName = minetest.get_current_modname
local getModPath = minetest.get_modpath;
local customTools = dofile(getModPath(getModName()) .. "/custom_tools.lua")
local switch          = customTools.switch
local write           = customTools.write
local immutable       = customTools.immutable
local immutableIpairs = customTools.immutableIpairs
local immutablePairs  = customTools.immutablePairs
local buildString     = customTools.buildString

--! No animation because that's not implemented into Minetest

local beltSpeeds = immutable({1,2,3})
local beltAngles = immutable({0,45,-45})

for _,beltSpeed in immutableIpairs(beltSpeeds) do
for _,beltAngle in immutableIpairs(beltAngles) do
    local definition = {
        paramtype = "light",
        paramtype2 = "4dir",

    }
    minetest.register_node(
        buildString(
            "tech:belt_", beltAngle, "_", beltSpeed
        ),
        definition
    );
end
end