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
local getNodeDrops         = minetest.get_node_drops
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
local addParticleSpawner   = minetest.add_particlespawner
formspec_version[6]
size[12,18]
list[context;stock;3.6,0.7;4,4;0]
list[context;output;3.6,6.3;4,4;0]
label[1.6,3.1;Stock]
label[1.6,8.7;Output]
list[current_player;main;1.1,12;8,4;0]