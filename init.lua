local getModName           = minetest.get_current_modname
local getModPath           = minetest.get_modpath;
local rootPath             = getModPath(getModName())

-- Jordan4ibanez functions
local customTools          = dofile(rootPath .. "/custom_tools.lua")
local buildString          = customTools.buildString


--! Automate loading
local fileList = {
    "belt",
    "inserter",
    "belt_item",
    "inserter_visual",
    "industrial_furnace",
    "industrial_quarry"
}

local function loadFromRoot(fileName)
    assert(
        loadfile(
            buildString(
                rootPath, "/", fileName, ".lua"
            )
        )
    )(rootPath, customTools)
end

for _,fileName in ipairs(fileList) do
    loadFromRoot(fileName)
end