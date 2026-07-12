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

  -- Cmd+K to clear the screen and scrollback (Ctrl+L makes the shell redraw its prompt).
  -- Only safe when a plain shell owns the pane: TUIs (herdr, claude, vim) repaint
  -- incrementally and get garbled if the viewport is wiped under them.
  -- Inside Herdr, scrollback belongs to Herdr, not WezTerm, so we go through its
  -- socket API instead: if the focused Herdr pane is an idle zsh prompt, stash any
  -- half-typed input (esc q = zsh push-line, restored after), then run `clear`
  -- (macOS clear emits ESC[3J, which Herdr honors by wiping that pane's history).
  -- Focused Herdr panes running claude/vim/etc. are left untouched.
  {
    key = "k",
    mods = "CMD",
    action = wezterm.action_callback(function(window, pane)
      local shells = { zsh = true, bash = true, fish = true, sh = true, nu = true }
      local proc = pane:get_foreground_process_name() or ""
      local name = proc:match("([^/\\]+)$") or proc
      if shells[name] and not pane:is_alt_screen_active() then
        window:perform_action(
          act.Multiple({
            act.ClearScrollback("ScrollbackAndViewport"),
            act.SendKey({ key = "L", mods = "CTRL" }),
          }),
          pane
        )
        return
      end
      if name == "herdr" then
        local herdr = "/opt/homebrew/bin/herdr"
        local ok, stdout = wezterm.run_child_process({ herdr, "pane", "process-info", "--current" })
        if ok then
          local parsed_ok, reply = pcall(wezterm.json_parse, stdout)
          local info = parsed_ok and reply.result and reply.result.process_info
          local fg = info and info.foreground_processes
          if fg and #fg == 1 and fg[1].name == "zsh" then
            wezterm.run_child_process({ herdr, "pane", "send-keys", info.pane_id, "esc", "q" })
            wezterm.run_child_process({ herdr, "pane", "run", info.pane_id, "clear" })
          end
        end
      end
      -- Tidy WezTerm's own history without touching the viewport (safe under TUIs).
      window:perform_action(act.ClearScrollback("ScrollbackOnly"), pane)
    end),
  },
}

-- Return the configuration to WezTerm
return config
