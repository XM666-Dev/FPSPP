dofile("data/scripts/lib/mod_settings.lua")

local mod_id = "fpspp"
mod_settings_version = 1
mod_settings =
{
    {
        id = "framerate",
        ui_name = "Framerate",
        ui_description = "The framerate of the game.",
        value_default = 60,
        value_min = 1,
        value_max = 180,
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
        id = "interpolation",
        ui_name = "Interpolation",
        ui_description = "The method used to interpolate transforms between frames.",
        value_default = "predictive",
        values = { { "predictive", "Predictive" }, { "general", "General" }, { "disabled", "Disabled" } },
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
}

function ModSettingsUpdate(init_scope)
    mod_settings_update(mod_id, mod_settings, init_scope)
end

function ModSettingsGuiCount()
    return mod_settings_gui_count(mod_id, mod_settings)
end

function ModSettingsGui(gui, in_main_menu)
    mod_settings_gui(mod_id, mod_settings, gui, in_main_menu)
end
