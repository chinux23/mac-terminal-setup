-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Color Scheme (Built-in Themes)
-- To switch to Rose Pine Dawn, just comment Catppuccin Mocha and uncomment Rose Pine Dawn
config.color_scheme = "Catppuccin Mocha"
-- config.color_scheme = "Rose Pine Dawn"

-- Font Settings
-- Using 'BlexMono Nerd Font Mono' with Medium weight to make it thicker
config.font = wezterm.font("BlexMono Nerd Font Mono", { weight = "Medium" })
config.font_size = 13.0

-- Appearance
config.enable_tab_bar = false             -- Hide tab bar for a clean, tab-free look
config.window_decorations = "RESIZE"     -- Borderless window but preserves resize borders
config.window_background_opacity = 0.9    -- 90% opacity for slight transparency
config.macos_window_background_blur = 20  -- Enable frosted-glass background blur on macOS

-- Pane Management (Warp-style shortcuts, no leader key)
local act = wezterm.action
config.keys = {
  -- Splits
  -- Cmd+D for split right (side by side), Cmd+Shift+D for split down (top and bottom)
  {
    key = "d",
    mods = "CMD",
    action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
  },
  {
    key = "d",
    mods = "CMD|SHIFT",
    action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
  },

  -- Close current pane (closes the window when it's the last pane)
  {
    key = "w",
    mods = "CMD",
    action = act.CloseCurrentPane({ confirm = false }),
  },

  -- Navigation
  -- Cmd+Option+Arrows to move between panes
  {
    key = "LeftArrow",
    mods = "CMD|OPT",
    action = act.ActivatePaneDirection("Left"),
  },
  {
    key = "DownArrow",
    mods = "CMD|OPT",
    action = act.ActivatePaneDirection("Down"),
  },
  {
    key = "UpArrow",
    mods = "CMD|OPT",
    action = act.ActivatePaneDirection("Up"),
  },
  {
    key = "RightArrow",
    mods = "CMD|OPT",
    action = act.ActivatePaneDirection("Right"),
  },
  -- Cmd+] / Cmd+[ to cycle to the next/previous pane
  {
    key = "]",
    mods = "CMD",
    action = act.ActivatePaneDirection("Next"),
  },
  {
    key = "[",
    mods = "CMD",
    action = act.ActivatePaneDirection("Prev"),
  },

  -- Pane Resizing
  -- Cmd+Ctrl+Arrows to resize the current pane by 3 cells
  {
    key = "LeftArrow",
    mods = "CMD|CTRL",
    action = act.AdjustPaneSize({ "Left", 3 }),
  },
  {
    key = "DownArrow",
    mods = "CMD|CTRL",
    action = act.AdjustPaneSize({ "Down", 3 }),
  },
  {
    key = "UpArrow",
    mods = "CMD|CTRL",
    action = act.AdjustPaneSize({ "Up", 3 }),
  },
  {
    key = "RightArrow",
    mods = "CMD|CTRL",
    action = act.AdjustPaneSize({ "Right", 3 }),
  },

  -- Cmd+Shift+Enter to toggle pane zoom (maximize/restore the current pane)
  {
    key = "Enter",
    mods = "CMD|SHIFT",
    action = act.TogglePaneZoomState,
  },

  -- Cmd+K to clear the screen and scrollback (Ctrl+L makes the shell redraw its prompt)
  {
    key = "k",
    mods = "CMD",
    action = act.Multiple({
      act.ClearScrollback("ScrollbackAndViewport"),
      act.SendKey({ key = "L", mods = "CTRL" }),
    }),
  },
}

-- Return the configuration to WezTerm
return config
