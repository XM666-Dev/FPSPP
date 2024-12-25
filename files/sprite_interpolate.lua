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

local fract_frame = tonumber(ModTextFileGetContent("mods/fpspp/files/fract_frame.txt"))
local internal = ModTextFileGetContent("mods/fpspp/files/internal.txt") ~= "false"
local f = fract_frame - math.floor(fract_frame)

local entities = EntityGetInRadius(0, 0, math.huge)
for i, entity in ipairs(entities) do
    local entity_data = Entity(entity)
    local x, y, rotation, scale_x, scale_y = EntityGetTransform(entity)
    if EntityGetComponent(entity, "SpriteComponent") == nil then goto continue end
    if EntityGetComponent(entity, "VariableStorageComponent", "x") == nil then
        entity_data.previous_x = x
        entity_data.previous_y = y
        entity_data.previous_rotation = rotation
        entity_data.previous_scale_x = scale_x
        entity_data.previous_scale_y = scale_y
    elseif internal then
        entity_data.previous_x = entity_data.x
        entity_data.previous_y = entity_data.y
        entity_data.previous_rotation = entity_data.rotation
        entity_data.previous_scale_x = entity_data.scale_x
        entity_data.previous_scale_y = entity_data.scale_y
    end
    entity_data.x = x
    entity_data.y = y
    entity_data.rotation = rotation
    entity_data.scale_x = scale_x
    entity_data.scale_y = scale_y
    EntitySetTransform(entity,
        lerp(entity_data.previous_x, x, f),
        lerp(entity_data.previous_y, y, f),
        lerp_angle(entity_data.previous_rotation, rotation, f),
        lerp(entity_data.previous_scale_x, scale_x, f),
        lerp(entity_data.previous_scale_y, scale_y, f)
    )
    ::continue::
end

print("interpolate OK", GameGetFrameNum())
SetTimeOut(0, "mods/fpspp/files/reset.lua")
