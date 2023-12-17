
local wezterm = require 'wezterm'

local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end


config.window_background_opacity = 0.9

config.font = wezterm.font_with_fallback ({
  {
    family = "Monaco Nerd Font",
    -- family = "JetBrains Mono",
    weight = "Regular",
    stretch = "Expanded",
    harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }
  }, {
    family = "Source Han Code JP",
    weight = "Regular",
    stretch = "Expanded",
  }
})

config.font_size = 12.5
config.freetype_load_target = "Light"
config.cell_width = 0.9


config.color_scheme = 'iceberg-dark'



config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"

config.window_frame = {
  -- font = wezterm.font("JetBrains Mono"),
  font_size = 13.5,
}

config.colors = {
  tab_bar = {
    active_tab = {
      bg_color = "#1f222e",
      fg_color = "#c6c8d1",
    },
    inactive_tab = {
      bg_color = "#333333",
      fg_color = "#c6c8d1",
    },
    inactive_tab_hover = {
      bg_color = "#1f222e",
      fg_color = "#c6c8d1",
    },
  },
}





config.use_ime = true

return config