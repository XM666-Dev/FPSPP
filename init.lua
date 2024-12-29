dofile_once("mods/fpspp/files/tactic.lua")
dofile_once("mods/fpspp/NoitaPatcher/load.lua")

local np = require("noitapatcher")
local ffi = require("ffi")
local dev = DebugGetIsDevBuild()
local p_frame = ffi.cast("int**", dev and 0x134328C or 0x122172C)[0]
local p_framerate_inverse = ffi.cast("double*", dev and 0x1341B28 or 0x121FBD8)
--local p_framerate = ffi.cast("int*", dev and 0x19EE0C or 0x19EDFC)

p_framerate_inverse[0] = 1 / ModSettingGet("fpspp.framerate")
function OnPausePreUpdate()
    p_framerate_inverse[0] = 1 / ModSettingGet("fpspp.framerate")
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
np.CrossCallAdd("fpspp.valve", function()
    local previous_fract_frame = fract_frame
    fract_frame = fract_frame + get_time_scale()
    local internal = fract_frame >= math.floor(previous_fract_frame) + 1
    ModTextFileSetContent("mods/fpspp/files/internal.txt", tostring(internal))
    ModTextFileSetContent("mods/fpspp/files/fract_frame.txt", ("%.16a"):format(fract_frame))

    if not internal then
        p_frame[0] = p_frame[0] - 1
    end

    for i, system in ipairs(dofile_once("mods/fpspp/files/systems.lua")) do
        np.ComponentUpdatesSetEnabled(system, internal)
    end
    np.MagicNumbersSetValue("DEBUG_PAUSE_BOX2D", not internal)
    np.MagicNumbersSetValue("DEBUG_PAUSE_GRID_UPDATE", not internal)
    np.MagicNumbersSetValue("GRID_MAX_UPDATES_PER_FRAME", internal and 128 or 0)

    local world_state = GameGetWorldStateEntity()
    local world_state_component = EntityGetFirstComponent(world_state, "WorldStateComponent")
    if world_state_component ~= nil then
        ComponentSetValue2(world_state_component, "time_dt", get_time_scale())
        ComponentSetValue2(world_state_component, "wind", ComponentGetValue2(world_state_component, "wind") * get_time_scale())
    end

    for i = 0, 3 do
        local player = np.GetPlayerEntity(i)
        if player == nil then goto continue end
        local controls = EntityGetFirstComponent(player, "ControlsComponent")
        if controls == nil then goto continue end
        if internal then
            local frame = frames[player]
            if frame == nil then goto continue end
            frames[player] = nil
            ComponentSetValue2(controls, "mButtonFrameInventory", frame)
            goto continue
        end
        local frame = ComponentGetValue2(controls, "mButtonFrameInventory")
        if frame < GameGetFrameNum() then goto continue end
        frames[player] = frame
        ComponentSetValue2(controls, "mButtonFrameInventory", 0)
        ::continue::
    end
end)
function OnWorldPreUpdate()
    SetTimeOut(0, "mods/fpspp/files/valve.lua")
end

ffi.cdef [[
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
        int frame_x;
        int frame_y;
        float frame_time;
    } Sprite;
]]
local function get_pp_sprite(sprite)
    return ffi.cast("Sprite**", np.GetComponentAddress(sprite) + (dev and 236 or 228))
end

local transforms = {}
local previous_transforms = {}
local camera_x, camera_y
local previous_camera_x, previous_camera_y
function OnWorldPostUpdate()
    local internal = ModTextFileGetContent("mods/fpspp/files/internal.txt") ~= "false"
    local weight = fract_frame - math.floor(fract_frame)

    if internal then
        previous_transforms = transforms
        transforms = {}
    end
    for i, entity in ipairs(EntityGetInRadius(0, 0, math.huge)) do
        local weight = weight
        if ModSettingGet("fpspp.interpolation") == "predict" and EntityHasTag(entity, "projectile") then
            weight = weight + 1
        end
        for i, sprite in ipairs(EntityGetComponent(entity, "SpriteComponent") or {}) do
            local p_sprite = get_pp_sprite(sprite)[0]
            if p_sprite ~= nil then
                if internal then
                    transforms[sprite] = { p_sprite.x, p_sprite.y, p_sprite.rotation_x, p_sprite.rotation_y, p_sprite.scale_x, p_sprite.scale_y }
                end
                local previous_transform = previous_transforms[sprite]
                local transform = transforms[sprite]
                if previous_transform ~= nil and transform ~= nil and ModSettingGet("fpspp.interpolation") ~= "off" then
                    p_sprite.x = lerp(previous_transform[1], transform[1], weight)
                    p_sprite.y = lerp(previous_transform[2], transform[2], weight)
                    p_sprite.rotation_x, p_sprite.rotation_y = lerp_angle_vec(previous_transform[3], previous_transform[4], transform[3], transform[4], weight)
                    p_sprite.scale_x = lerp(previous_transform[5], transform[5], weight)
                    p_sprite.scale_y = lerp(previous_transform[6], transform[6], weight)
                end
                p_sprite.frame_time = p_sprite.frame_time + (get_time_scale_external() - 1) / ModSettingGet("fpspp.framerate")
            end
        end
    end

    if internal then
        previous_camera_x, previous_camera_y = camera_x, camera_y
        camera_x, camera_y = GameGetCameraPos()
    end
    if previous_camera_x ~= nil and previous_camera_y ~= nil and camera_x ~= nil and camera_y ~= nil and ModSettingGet("fpspp.interpolation") ~= "off" then
        GameSetCameraPos(lerp(previous_camera_x, camera_x, weight), lerp(previous_camera_y, camera_y, weight))
    end

    --local player = EntityGetWithTag("player_unit")[1]
    --if player == nil then return end
    --local sprite = EntityGetFirstComponent(player, "SpriteComponent")
    --if sprite == nil then return end
    --local p_sprite = get_pp_sprite(sprite)[0]
    --local pointer = ffi.cast("float*", p_sprite)
    --if InputIsKeyJustDown(11) then
    --    search(pointer)
    --end
    --if InputIsKeyJustDown(12) then
    --    clear()
    --end
end

local previous_values = {}
function search(pointer)
    print("\n")
    for i = 0, 255 do
        local value = pointer[i]
        local previous_value = previous_values[i]
        if previous_value ~= nil and value > previous_value then
            print(i, value .. " > " .. previous_value)
        end
        previous_values[i] = value
    end
end

function clear()
    previous_values = {}
end

function OnModPreInit()
    do_mod_appends("mods/fpspp/init.lua")
end
