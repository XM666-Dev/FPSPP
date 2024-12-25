dofile_once("mods/fpspp/files/sult.lua")
dofile_once("mods/fpspp/NoitaPatcher/load.lua")

ModLuaFileAppend("data/scripts/init.lua", "mods/fpspp/files/init_appends.lua")
ModTextFileSetContent("data/scripts/init.lua", ModTextFileGetContent("data/scripts/init.lua"))

local ffi = require("ffi")
local np = require("noitapatcher")

local p_frame = ffi.cast("int**", DebugGetIsDevBuild() and 0x134328C or 0x122172C)[0]
local systems = { "MoveToSurfaceOnCreateSystem", "AttachToEntitySystem", "InheritTransformSystem", "ControlsSystem", "GameEffectSystem", "LevitationSystem", "ConsumableTeleportSystem", "InventoryGuiSystem", "CharacterPlatformingSystem",
    "CharacterCollisionSystem", "PlayerCollisionSystem", "Inventory2System", "PlatformShooterPlayerSystem", "ItemPickUpperSystem", "AISystem", "AbilitySystem", "AdvancedFishAISystem", "AltarSystem", "AnimalAISystem", "ArcSystem", "AreaDamageSystem",
    "AudioListenerSystem", "AudioLoopSystem", "AudioSystem", "BiomeTrackerSystem", "BlackHoleSystem", "BossDragonSystem", "BossHealthBarSystem", "CameraBoundSystem", "CardinalMovementSystem", "CellEaterSystem", "CollisionTriggerSystem",
    "ControllerGoombaAISystem", "CrawlerAnimalSystem", "DamageModelSystem", "DamageNearbyEntitiesSystem", "DebugFollowMouseSystem", "DebugLogMessagesSystem", "DebugSpatialVisualizerSystem", "DieIfSpeedBelowSystem", "DroneLauncherSystem", "DrugEffectSystem",
    "ElectricChargeSystem", "ElectricityReceiverSystem", "ElectricitySourceSystem", "ElectricitySystem", "EndingMcGuffinSystem", "ExplodeOnDamageSystem", "ExplosionSystem", "FishAISystem", "FlyingSystem", "FogOfWarRadiusSystem", "GameAreaEffectSystem",
    "GameLogSystem", "GasBubbleSystem", "GhostSystem", "GunSystem", "HealthBarSystem", "HitboxSystem", "HomingSystem", "IngestionSystem", "InteractableSystem", "ItemAlchemySystem", "ItemChestSystem", "ItemCostSystem", "ItemRechargeNearGroundSystem",
    "ItemStashSystem", "ItemSystem", "LaserEmitterSystem", "LifetimeSystem", "LightSystem", "LightningSystem", "LimbBossSystem", "LoadEntitiesSystem", "LooseGroundSystem", "MagicConvertMaterialSystem", "MagicXRaySystem", "ManaReloaderSystem",
    "MaterialAreaCheckerSystem", "MaterialInventorySystem", "MaterialSeaSpawnerSystem", "MaterialSuckerSystem", "MusicEnergyAffectorSystem", "OrbSystem", "PathFindingGridMarkerSystem", "PathFindingSystem", "PhysicsBodyCollisionDamageSystem",
    "PhysicsJoint2MutatorSystem", "PhysicsPickUpSystem", "PhysicsRagdollSystem", "PhysicsThrowableSystem", "PixelSceneSystem", "PixelSpriteSystem", "PositionSeedSystem", "PotionSystem", "PressurePlateSystem", "RotateTowardsSystem",
    "SetLightAlphaFromVelocitySystem", "SetStartVelocitySystem", "SimplePhysicsSystem", "SineWaveSystem", "SpriteAnimatorSystem", "SpriteOffsetAnimatorSystem", "SpriteStainsSystem", "StatusEffectDataSystem", "StreamingKeepAliveSystem", "TelekinesisSystem",
    "TeleportProjectileSystem", "TeleportSystem", "TorchSystem", "VariableStorageSystem", "VelocitySystem", "VerletWorldJointSystem", "WalletSystem", "WorldStateSystem", "WormAISystem", "WormAttractorSystem", "WormPlayerSystem", "WormSystem",
    "PhysicsBody2System", "PhysicsBodySystem", "PhysicsJointSystem", "PhysicsAISystem", "ProjectileSystem", "SpriteParticleEmitterSystem", "VerletWeaponSystem", "ParticleEmitterSystem", "LuaSystem", "EnergyShieldSystem", "VerletPhysicsSystem",
    "IKLimbAttackerSystem", "IKLimbWalkerSystem", "IKLimbsAnimatorSystem", "IKLimbSystem", "SpriteSystem", "GameStatsSystem",
}
local excluded_systems = {
    --"ControlsSystem",
    "InventoryGuiSystem",
    --"CharacterPlatformingSystem",
    --"CharacterCollisionSystem",
    --"PlayerCollisionSystem",
    --"Inventory2System",
    --"PlatformShooterPlayerSystem",
    "ItemPickUpperSystem",
    --"SpriteAnimatorSystem",
    --"StatusEffectDataSystem",
    --"ProjectileSystem",
    "LuaSystem",
    --"VerletPhysicsSystem",
    --"SpriteSystem",
}
for i, system in ipairs(excluded_systems) do
    table.remove(systems, table.find(systems, function(s) return s == system end))
end

function OnWorldInitialized()
    local entity = EntityCreateNew()
    EntityAddComponent2(entity, "LuaComponent", { script_source_file = "mods/fpspp/files/sprite_interpolate.lua", execute_every_n_frame = 0 })
end

local time_scale = 1
local fract_frame = 0
local previous_fract_frame = -time_scale
local ModTextFileSetContent = ModTextFileSetContent
local button_frames = {}
function OnWorldPreUpdate()
    local internal = fract_frame >= math.floor(previous_fract_frame) + 1
    ModTextFileSetContent("mods/fpspp/files/fract_frame.txt", ("%.16a"):format(fract_frame))
    ModTextFileSetContent("mods/fpspp/files/internal.txt", tostring(internal))
    previous_fract_frame = fract_frame
    fract_frame = fract_frame + time_scale
    for i, system in ipairs(systems) do
        np.ComponentUpdatesSetEnabled(system, internal)
    end
    np.MagicNumbersSetValue("DEBUG_PAUSE_BOX2D", not internal)
    np.MagicNumbersSetValue("GRID_MAX_UPDATES_PER_FRAME", internal and 128 or 0)
    if not internal then
        p_frame[0] = p_frame[0] - 1
    end

    local player = np.GetPlayerEntity()
    if player ~= nil then
        local controls = EntityGetFirstComponent(player, "ControlsComponent")
        if controls ~= nil then
            local members = ComponentGetMembers(controls) or {}
            for k in pairs(members) do
                if k:find("mButtonFrame") then
                    local button_frame = ComponentGetValue2(controls, k)
                    if button_frame ~= 0 then
                        button_frames[k] = button_frame
                        ComponentSetValue2(controls, k, 0)
                    end
                    if internal and button_frames[k] ~= nil then
                        ComponentSetValue2(controls, k, button_frames[k])
                    end
                end
            end
        end
    end

    if InputIsKeyJustDown(10) then
        if time_scale == 1 then
            time_scale = 0.5
        elseif time_scale == 0.5 then
            time_scale = 0.1
        elseif time_scale == 0.1 then
            time_scale = 0
        else
            time_scale = 1
        end
        debug_print(time_scale)
    end
end

function OnWorldPostUpdate()
    print("fpspp", GameGetFrameNum())
end
