dofile_once("mods/fpspp/files/tactic.lua")
dofile_once("mods/fpspp/NoitaPatcher/load.lua")

local np = require("noitapatcher")
local ffi = require("ffi")

local p_framerate = ffi.cast("double*", np.GetPlatform() + 56)
p_framerate[0] = 1 / ModSettingGet("fpspp.framerate")
function OnPausePreUpdate()
    p_framerate[0] = 1 / ModSettingGet("fpspp.framerate")
end

function get_time_scale_internal()
    return 60 / ModSettingGet("fpspp.framerate")
end

function get_time_scale_external()
    return 1
end

function get_time_scale()
    return get_time_scale_internal() * get_time_scale_external()
end

local ModTextFileSetContent = ModTextFileSetContent

local fract_frame = 0
local frames = {}
function OnWorldPreUpdate()
    local time_scale = get_time_scale()

    local previous_fract_frame = fract_frame
    fract_frame = fract_frame + time_scale
    local internal = fract_frame >= math.floor(previous_fract_frame) + 1
    ModTextFileSetContent("mods/fpspp/files/internal.txt", tostring(internal))
    ModTextFileSetContent("mods/fpspp/files/fract_frame.txt", ("%.16a"):format(fract_frame))

    for i, system in ipairs(dofile_once("mods/fpspp/files/systems.lua")) do
        np.ComponentUpdatesSetEnabled(system, internal)
    end
    for i, system in ipairs(dofile_once("mods/fpspp/files/systems_all.lua")) do
        np.ComponentUpdatesSetStep(system, 1 / 60)
        if system == "PlatformShooterPlayerSystem" then
            np.ComponentUpdatesSetStep(system, 1 / ModSettingGet("fpspp.framerate"))
        end
    end

    np.EnableGameGlobalUpdate(internal)
    np.EnableGameWorldUpdate(internal)

    for i, entity in ipairs(EntityGetInRadius(0, 0, math.huge)) do
        for i, controls in ipairs(EntityGetComponent(entity, "ControlsComponent") or {}) do
            if ComponentGetValue2(controls, "enabled") then
                frames[controls] = frames[controls] or {}
                for i, field in ipairs(dofile_once("mods/fpspp/files/fields.lua")) do
                    local frame = ComponentGetValue2(controls, field)
                    if frame ~= 0 then
                        frames[controls][i] = frame
                        ComponentSetValue2(controls, field, 0)
                    end
                    if internal and frames[controls][i] ~= nil then
                        ComponentSetValue2(controls, field, frames[controls][i])
                        frames[controls][i] = nil
                    end
                end
            end
        end
    end

    local world_state = GameGetWorldStateEntity()
    local world_state_component = EntityGetFirstComponent(world_state, "WorldStateComponent")
    if world_state_component ~= nil then
        ComponentSetValue2(world_state_component, "time_dt", time_scale)
        ComponentSetValue2(world_state_component, "wind", ComponentGetValue2(world_state_component, "wind") * time_scale)
    end
end

ffi.cdef[[
    typedef struct Sprite {
        char _[96];
        float x;
        float y;
        float rotation_x;
        float rotation_y;
        char _[8];
        float scale_x;
        float scale_y;
        char _[52];
        int frame;
        int frame_next;
        float frame_time;
    } Sprite;
]]
local offset = DebugGetIsDevBuild() and 236 or 228
local function get_pp_sprite(sprite)
    return ffi.cast("Sprite**", np.GetComponentAddress(sprite) + offset)
end

local transforms = {}
local previous_transforms = {}
local camera_x, camera_y
local previous_camera_x, previous_camera_y
function OnWorldPostUpdate()
    if ModSettingGet("fpspp.interpolation") == "disabled" then
        return
    end
    local internal = ModTextFileGetContent("mods/fpspp/files/internal.txt") ~= "false"
    local weight = fract_frame - math.floor(fract_frame)

    if internal then
        previous_transforms = transforms
        transforms = {}
    end
    for i, entity in ipairs(EntityGetInRadius(0, 0, math.huge)) do
        local weight = weight
        if ModSettingGet("fpspp.interpolation") == "predictive" and EntityHasTag(entity, "projectile") then
            weight = weight + 1
        end
        for i, sprite in ipairs(EntityGetComponent(entity, "SpriteComponent") or {}) do
            local p_sprite = get_pp_sprite(sprite)[0]
            if p_sprite ~= nil then
                if internal then
                    transforms[sprite] = {p_sprite.x, p_sprite.y, p_sprite.rotation_x, p_sprite.rotation_y, p_sprite.scale_x, p_sprite.scale_y}
                end
                local previous_transform = previous_transforms[sprite]
                local transform = transforms[sprite]
                if previous_transform ~= nil and transform ~= nil then
                    p_sprite.x = lerp(previous_transform[1], transform[1], weight)
                    p_sprite.y = lerp(previous_transform[2], transform[2], weight)
                    p_sprite.rotation_x, p_sprite.rotation_y = lerp_angle_vec(previous_transform[3], previous_transform[4], transform[3], transform[4], weight)
                    p_sprite.scale_x = lerp(previous_transform[5], transform[5], weight)
                    p_sprite.scale_y = lerp(previous_transform[6], transform[6], weight)
                end
            end
        end
    end

    if internal then
        previous_camera_x, previous_camera_y = camera_x, camera_y
        camera_x, camera_y = GameGetCameraPos()
    end
    if previous_camera_x ~= nil and previous_camera_y ~= nil and camera_x ~= nil and camera_y ~= nil then
        GameSetCameraPos(lerp(previous_camera_x, camera_x, weight), lerp(previous_camera_y, camera_y, weight))
    end
end

function OnModPreInit()
    do_mod_appends("mods/fpspp/init.lua")
end
