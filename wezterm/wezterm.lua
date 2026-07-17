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
          -- Tidy WezTerm's own history without touching the viewport (safe under TUIs).
          window:perform_action(act.ClearScrollback("ScrollbackOnly"), pane)
        else
          -- Remote herdr (--remote): no local server, so socket API failed.
          -- Send Ctrl+L and let herdr forward it to the remote pane's shell.
          window:perform_action(act.SendKey({ key = "L", mods = "CTRL" }), pane)
        end
      else
        -- Other TUIs: tidy WezTerm's own history without touching the viewport.
        window:perform_action(act.ClearScrollback("ScrollbackOnly"), pane)
      end
    end),
  },

  -- Cmd+Shift+O to open a URL from the pane's recent output via a picker.
  -- WezTerm regex-matches URLs on the physical rows it renders, so a long URL
  -- that soft-wraps inside a Herdr pane reaches it as separate lines and
  -- Shift+click opens a truncated link. Herdr still knows the logical line
  -- structure, so for Herdr panes we fetch the focused pane's recent output
  -- through its socket API with --source recent-unwrapped, which rejoins
  -- wrapped lines; plain panes use WezTerm's own logical-line text. Matches
  -- are listed newest-first in an InputSelector: Enter opens the top one,
  -- / filters, Esc cancels.
  {
    key = "o",
    mods = "CMD|SHIFT",
    action = wezterm.action_callback(function(window, pane)
      local text
      local proc = pane:get_foreground_process_name() or ""
      local name = proc:match("([^/\\]+)$") or proc
      if name == "herdr" then
        local herdr = "/opt/homebrew/bin/herdr"
        local ok, stdout = wezterm.run_child_process({ herdr, "pane", "process-info", "--current" })
        if ok then
          local parsed_ok, reply = pcall(wezterm.json_parse, stdout)
          local info = parsed_ok and reply.result and reply.result.process_info
          if info and info.pane_id then
            local read_ok, read_out = wezterm.run_child_process({
              herdr, "pane", "read", info.pane_id,
              "--source", "recent-unwrapped", "--lines", "200", "--format", "text",
            })
            if read_ok then
              text = read_out
            end
          end
        end
      end
      if not text then
        text = pane:get_logical_lines_as_text(200)
      end

      -- Strip prose punctuation from the end of a match; drop a trailing ")"
      -- only when it has no opening "(" inside the URL to pair with, so
      -- wikipedia-style /Foo_(bar) URLs survive while "(see https://x)" drops
      -- the closing paren.
      local function trim_url(url)
        while #url > 0 do
          local tail = url:sub(-1)
          if tail:match("[%.,;:!%]]") then
            url = url:sub(1, -2)
          elseif tail == ")" then
            local _, opens = url:gsub("%(", "")
            local _, closes = url:gsub("%)", "")
            if closes > opens then
              url = url:sub(1, -2)
            else
              break
            end
          else
            break
          end
        end
        return url
      end

      local matches = {}
      for url in text:gmatch("https?://[%w%-%._~:/?#%[%]@!$&'()*+,;=%%]+") do
        table.insert(matches, trim_url(url))
      end
      -- Newest first, deduped.
      local urls, seen = {}, {}
      for i = #matches, 1, -1 do
        if not seen[matches[i]] then
          seen[matches[i]] = true
          table.insert(urls, matches[i])
        end
      end
      if #urls == 0 then
        window:toast_notification("WezTerm", "No URLs found in pane output", nil, 3000)
        return
      end

      local choices = {}
      for _, url in ipairs(urls) do
        table.insert(choices, { label = url })
      end
      window:perform_action(
        act.InputSelector({
          title = "Open URL (newest first)",
          choices = choices,
          action = wezterm.action_callback(function(_, _, _, label)
            if label then
              wezterm.open_with(label)
            end
          end),
        }),
        pane
      )
    end),
  },
}

-- Return the configuration to WezTerm
return config
