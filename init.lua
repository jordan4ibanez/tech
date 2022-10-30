local customTools = require("custom_tools")
local switch          = customTools.switch
local write           = customTools.write
local immutable       = customTools.immutable
local immutableIpairs = customTools.immutableIpairs
local immutablePairs  = customTools.immutablePairs

local angles = immutable({0,45,-45})

for _,val in immutableIpairs(angles) do
    write("angle: ", val)
end
