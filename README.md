# Fresh Mac setup — WezTerm + Herdr

Reproduces the terminal setup from chen's Mac (July 2026): WezTerm nightly with
Catppuccin Mocha, Warp-style pane shortcuts, frosted-glass transparency, and the
Herdr agent multiplexer.

## 1. Prerequisites — Homebrew

```sh
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## 2. Install WezTerm — use the NIGHTLY, not stable

```sh
brew install --cask wezterm@nightly
```

**Why nightly:** the last stable release (20240203) predates WezTerm's macOS
color-management fix ([#5824](https://github.com/wezterm/wezterm/issues/5824),
[#6063](https://github.com/wezterm/wezterm/issues/6063)). On wide-gamut
displays (e.g. LG Ultrawide 5K, MacBook XDR screens) the stable build renders
all theme colors oversaturated because it skips sRGB color-space conversion.
The nightly declares its window as sRGB and colors render true.

Maintenance notes:

- The nightly cask doesn't auto-upgrade; update with
  `brew reinstall --cask wezterm@nightly`.
- When a stable release newer than 20240203 finally ships, you can switch back:
  `brew uninstall --cask wezterm@nightly && brew install --cask wezterm`.

## 3. Install the font

The config uses BlexMono Nerd Font (IBM Plex Mono patched with Nerd Font
glyphs):

```sh
brew install --cask font-blex-mono-nerd-font
```

## 4. WezTerm config

Copy the config below to `~/.config/wezterm/wezterm.lua` (or copy the file
straight from the old machine). WezTerm hot-reloads on save.

```lua
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
```

### Pane shortcut cheat sheet (Warp-style)

| Action | Shortcut |
|---|---|
| Split right (side by side) | Cmd+D |
| Split down (stacked) | Cmd+Shift+D |
| Move between panes | Cmd+Option+Arrows |
| Cycle next / previous pane | Cmd+] / Cmd+[ |
| Resize pane (3 cells) | Cmd+Ctrl+Arrows |
| Maximize / restore pane | Cmd+Shift+Enter |
| Close pane (no confirm) | Cmd+W |
| Clear screen + scrollback | Cmd+K |

## 5. Install Herdr (agent multiplexer)

```sh
brew install herdr
```

- `herdr` in any directory launches or reattaches the persistent session
- tmux-style prefix `Ctrl+B` (detach with `Ctrl+B q`); sessions survive closing
  the terminal
- Sidebar shows which AI coding agents are waiting for input vs. working
- `herdr status` / `herdr update` for health and self-updates
- Zsh completions installed automatically
- Docs: https://herdr.dev/docs/quick-start/

## 6. Verify colors (optional, wide-gamut displays)

Run:

```sh
printf "\e[31mRed\e[0m \e[32mGreen\e[0m \e[34mBlue\e[0m\n"
```

Red/green/blue should look soft and pastel (Catppuccin `#f38ba8` / `#a6e3a1` /
`#89b4fa`), matching what a browser shows for those hex colors — not
neon/oversaturated. If they look oversaturated, you're on the old stable
WezTerm without the color-management fix (see step 2).
