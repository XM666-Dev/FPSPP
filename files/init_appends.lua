dofile_once("mods/120fps/files/sult.lua")

--local ffi = require("ffi")
--local dev = DebugGetIsDevBuild()
--local p_stream = dev and 0x134328C or 0x122172C
--local p_frame = ffi.cast("int**", p_stream)[0] --CrossCall("ffi.cast", "int**", p_stream)[0]
--local raw_on_world_pre_update = OnWorldPreUpdate
--function OnWorldPreUpdate()
--    raw_on_world_pre_update()
--    print(p_frame)
--    print("appends OK")
--end

local Entity = setmetatable(Class {
    x = VariableAccessor("x", "value_float"),
    y = VariableAccessor("y", "value_float"),
    rotation = VariableAccessor("rotation", "value_float"),
    scale_x = VariableAccessor("scale_x", "value_float"),
    scale_y = VariableAccessor("scale_y", "value_float"),
    previous_x = VariableAccessor("previous_x", "value_float"),
    previous_y = VariableAccessor("previous_y", "value_float"),
    previous_rotation = VariableAccessor("previous_rotation", "value_float"),
    previous_scale_x = VariableAccessor("previous_scale_x", "value_float"),
    previous_scale_y = VariableAccessor("previous_scale_y", "value_float"),
}, {
    __call = function(t, ...) return setmetatable({ id = ... }, t) end,
})
local raw_on_world_post_update = OnWorldPostUpdate
function OnWorldPostUpdate()
    if raw_on_world_post_update ~= nil then raw_on_world_post_update() end
    local entities = EntityGetInRadius(0, 0, math.huge)
    for i, entity in ipairs(entities) do
        local entity_data = Entity(entity)
        EntitySetTransform(entity, entity_data.x, entity_data.y, entity_data.rotation, entity_data.scale_x, entity_data.scale_y)
    end
end
