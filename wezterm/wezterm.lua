-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Color Scheme (Built-in Themes)
config.color_scheme = "Catppuccin Mocha"
-- config.color_scheme = "Rose Pine Dawn"

-- Font Settings
-- Using the newly installed 'JetBrainsMono Nerd Font Mono' with Medium weight
config.font = wezterm.font("JetBrainsMono Nerd Font Mono", { weight = "Medium" })
config.font_size = 12.0

-- Appearance
config.enable_tab_bar = false             -- Hide tab bar for a clean, tab-free look
config.window_decorations = "RESIZE"     -- Borderless window but preserves resize borders
config.window_background_opacity = 0.9    -- 90% opacity for slight transparency
config.macos_window_background_blur = 20  -- Enable frosted-glass background blur on macOS

-- Multiplexer & Session Management (replacing tmux)
-- Set Leader key to Ctrl + a (standard tmux behavior)
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }

local act = wezterm.action
config.keys = {
  -- Splits (Intuitive horizontal/vertical splits)
  -- Leader + \ or | for horizontal split (side by side)
  {
    key = "\\",
    mods = "LEADER",
    action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
  },
  -- Leader + - for vertical split (top and bottom)
  {
    key = "-",
    mods = "LEADER",
    action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
  },

  -- Navigation (Vim-style pane navigation)
  -- Leader + h/j/k/l to switch between split panes
  {
    key = "h",
    mods = "LEADER",
    action = act.ActivatePaneDirection("Left"),
  },
  {
    key = "j",
    mods = "LEADER",
    action = act.ActivatePaneDirection("Down"),
  },
  {
    key = "k",
    mods = "LEADER",
    action = act.ActivatePaneDirection("Up"),
  },
  {
    key = "l",
    mods = "LEADER",
    action = act.ActivatePaneDirection("Right"),
  },

  -- Pane Resizing
  -- Leader + Shift + H/J/K/L to resize panes by 5 cells
  {
    key = "H",
    mods = "LEADER|SHIFT",
    action = act.AdjustPaneSize({ "Left", 5 }),
  },
  {
    key = "J",
    mods = "LEADER|SHIFT",
    action = act.AdjustPaneSize({ "Down", 5 }),
  },
  {
    key = "K",
    mods = "LEADER|SHIFT",
    action = act.AdjustPaneSize({ "Up", 5 }),
  },
  {
    key = "L",
    mods = "LEADER|SHIFT",
    action = act.AdjustPaneSize({ "Right", 5 }),
  },

  -- Pane Management
  -- Leader + z to toggle pane zoom (maximize pane, equivalent to tmux's zoom)
  {
    key = "z",
    mods = "LEADER",
    action = act.TogglePaneZoomState,
  },
  -- Leader + x to close the current active pane without confirmation prompt
  {
    key = "x",
    mods = "LEADER",
    action = act.CloseCurrentPane({ confirm = false }),
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
