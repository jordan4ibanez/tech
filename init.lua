local getModName = minetest.get_current_modname
local getModPath = minetest.get_modpath;
-- Jordan4ibanez functions
local customTools = dofile(getModPath(getModName()) .. "/custom_tools.lua")
local switch          = customTools.switch
local write           = customTools.write
local immutable       = customTools.immutable
local immutableIpairs = customTools.immutableIpairs
local immutablePairs  = customTools.immutablePairs
local buildString     = customTools.buildString
-- Minetest functions
local setNode         = minetest.set_node


-- This is pulled from master branch
local function dir_to_fourdir(dir)
	if math.abs(dir.x) > math.abs(dir.z) then
		if dir.x < 0 then
			return 3
		else
			return 1
		end
	else
		if dir.z < 0 then
			return 2
		else
			return 0
		end
	end
end

-- Makes the belt face the direction the player expects
local function convertDir(inputDir)
    return (inputDir + 2) % 4
end


--! No animation because that's not implemented into Minetest

local beltSpeeds = immutable({1,2,3})
local beltAngles = immutable({0,45})

for _,beltSpeed in immutableIpairs(beltSpeeds) do
for _,beltAngle in immutableIpairs(beltAngles) do

    local nameString = buildString(
        "tech:belt_", beltAngle, "_", beltSpeed
    )

    -- Todo: Make belts act like rails
    local definition = {
        paramtype  = "light",
        paramtype2 = "facedir",
        drawtype   = "mesh",
        mesh = buildString("belt_", tostring(beltAngle), ".b3d"),
        tiles = { buildString("belt_",beltSpeed,".png") },
        visual_scale = 0.5,
        after_place_node = function(_, placer, _, pointedThing)
            local lookDir = placer:get_look_dir()
            local fourDir = convertDir(dir_to_fourdir(lookDir))
            setNode(pointedThing.above, {name = nameString, param2 = fourDir})
        end
    }
    minetest.register_node(
        nameString,
        definition
    );
end
end