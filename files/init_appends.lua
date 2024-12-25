dofile_once("mods/fpspp/files/sult.lua")

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
function OnWorldPostUpdate()
    local entities = EntityGetInRadius(0, 0, math.huge)
    for i, entity in ipairs(entities) do
        local entity_data = Entity(entity)
        if EntityGetComponent(entity, "SpriteComponent") == nil then goto continue end
        EntitySetTransform(entity, entity_data.x, entity_data.y, entity_data.rotation, entity_data.scale_x, entity_data.scale_y)
        ::continue::
    end
    print("data", GameGetFrameNum())
end
