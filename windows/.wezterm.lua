-- ~/.wezterm.lua (Windows side) — WezTerm set up to feel like my macOS iTerm2.
--
-- WezTerm runs on Windows, not inside WSL, so this file lives in the Windows
-- profile (%USERPROFILE%\.wezterm.lua). install.sh copies it there; edit the
-- repo copy (windows/.wezterm.lua) and re-run install.sh. WezTerm hot-reloads.
--
-- Values below are lifted from the iTerm2 "Default" profile: MesloLGS NF 14,
-- the custom colour scheme, Option-as-Esc+, ⌘←/⌘→/⌘⌫ line editing, dimmed
-- inactive panes, visual bell, hidden scrollbar.

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- There's no ⌘ on Windows. Everything iTerm did with ⌘ uses CMD below.
-- CTRL|SHIFT is the PC-terminal convention and never collides with the shell,
-- nvim or the tmux prefix (C-Space). Change to 'ALT' if you'd rather use the key
-- that sits where ⌘ does — but then Alt stops working as Meta (Esc+).
local CMD = 'CTRL|SHIFT'

-- -- Shell: open straight into WSL ---------------------------------------------

-- First real distro (usually Ubuntu), skipping Docker Desktop's internal ones.
-- Pin it instead with e.g. config.default_domain = 'WSL:Ubuntu-24.04'.
local wsl, default_domain = wezterm.default_wsl_domains(), nil
for _, d in ipairs(wsl) do
  d.default_cwd = '~'
  if not default_domain and not d.distribution:find '^docker%-desktop' then
    default_domain = d.name
  end
end
config.wsl_domains = wsl
config.default_domain = default_domain

-- -- Font -----------------------------------------------------------------------

-- MesloLGS NF is what powerlevel10k expects. Install it on *Windows* (the p10k
-- README links the four .ttf files) — WSL-side fonts aren't visible to WezTerm.
config.font = wezterm.font_with_fallback {
  'MesloLGS NF',
  'Symbols Nerd Font Mono', -- bundled with WezTerm
}
config.font_size = 14.0
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' } -- iTerm: ligatures off
config.bold_brightens_ansi_colors = 'BrightAndBold'          -- iTerm: "Use bright colours for bold text"

-- -- Colours (iTerm2 "Default" profile) -----------------------------------------

config.color_schemes = {
  ['iTerm Default'] = {
    foreground = '#e5e5e5',
    background = '#2a2a2a',
    cursor_bg = '#bbbbbb',
    cursor_fg = '#000000',
    cursor_border = '#bbbbbb',
    selection_bg = '#607c8a',
    selection_fg = '#000000',
    ansi = { '#546d79', '#fe5151', '#69efad', '#bbbb00', '#40c3fe', '#fe3f80', '#64fcda', '#bbbbbb' },
    brights = { '#b0bdc4', '#ff5555', '#b9f5c9', '#ffff55', '#80d7fe', '#fe7faa', '#a7fdeb', '#ffffff' },
    tab_bar = {
      background = '#1e1e1e',
      active_tab = { bg_color = '#2a2a2a', fg_color = '#e5e5e5' },
      inactive_tab = { bg_color = '#1e1e1e', fg_color = '#808080' },
      inactive_tab_hover = { bg_color = '#333333', fg_color = '#e5e5e5' },
      new_tab = { bg_color = '#1e1e1e', fg_color = '#808080' },
      new_tab_hover = { bg_color = '#333333', fg_color = '#e5e5e5' },
    },
  },
}
config.color_scheme = 'iTerm Default'

-- -- Window / tabs / panes --------------------------------------------------------

config.default_cursor_style = 'SteadyBlock'
config.enable_scroll_bar = false
config.scrollback_lines = 10000           -- tmux keeps the real history
config.window_padding = { left = 4, right = 4, top = 4, bottom = 4 }
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE' -- tabs in the title bar, like iTerm's minimal style
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32
config.window_frame = {
  font = wezterm.font { family = 'MesloLGS NF', weight = 'Bold' },
  font_size = 11.0,
  active_titlebar_bg = '#1e1e1e',
  inactive_titlebar_bg = '#1e1e1e',
}
config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.72 } -- iTerm dims inactive splits ~28%
config.visual_bell = {
  fade_in_duration_ms = 75, fade_out_duration_ms = 75,
  target = 'CursorColor',
}
config.audible_bell = 'Disabled'
config.window_close_confirmation = 'NeverPrompt'
config.adjust_window_size_when_changing_font_size = false

-- -- Keys -------------------------------------------------------------------------

-- iTerm "Option sends Esc+" on both sides. (WezTerm default on Windows, made
-- explicit so it never turns into AltGr composition.)
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

config.keys = {
  -- Tabs / windows (⌘T ⌘W ⌘N ⌘⇧[ ⌘⇧])
  { key = 't', mods = CMD, action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = CMD, action = act.CloseCurrentPane { confirm = false } },
  { key = 'n', mods = CMD, action = act.SpawnWindow },
  { key = '{', mods = CMD, action = act.ActivateTabRelative(-1) },
  { key = '}', mods = CMD, action = act.ActivateTabRelative(1) },

  -- Splits (⌘D right, ⌘⇧D down) — iTerm's D/Shift-D become D/E here because
  -- CMD already includes Shift.
  { key = 'd', mods = CMD, action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'e', mods = CMD, action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = '[', mods = CMD, action = act.ActivatePaneDirection 'Prev' },
  { key = ']', mods = CMD, action = act.ActivatePaneDirection 'Next' },
  { key = 'Enter', mods = CMD, action = act.TogglePaneZoomState }, -- ⌘⇧↩ maximise pane
  { key = 'Enter', mods = 'ALT', action = act.ToggleFullScreen },  -- ⌘↩ full screen

  -- ⌘⌥ arrows: move between panes
  { key = 'LeftArrow', mods = CMD .. '|ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = CMD .. '|ALT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = CMD .. '|ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = CMD .. '|ALT', action = act.ActivatePaneDirection 'Down' },

  -- Clipboard / find / clear (⌘C ⌘V ⌘F ⌘K)
  { key = 'c', mods = CMD, action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = CMD, action = act.PasteFrom 'Clipboard' },
  { key = 'f', mods = CMD, action = act.Search 'CurrentSelectionOrEmptyString' },
  { key = 'k', mods = CMD, action = act.ClearScrollback 'ScrollbackAndViewport' },

  -- Font size (⌘+ ⌘- ⌘0)
  { key = '+', mods = CMD, action = act.IncreaseFontSize },
  { key = '_', mods = CMD, action = act.DecreaseFontSize },
  { key = ')', mods = CMD, action = act.ResetFontSize },

  -- Line editing, same as the iTerm profile's key map:
  --   ⌘← / ⌘→  → start / end of line (C-a / C-e)
  --   ⌘⌫       → kill to start of line (C-u)
  --   ⌥← / ⌥→  → back / forward a word (Esc b / Esc f)
  --   ⌥⌫       → delete word back (Esc DEL)
  --   ⌥⌦       → delete word forward (Esc d)
  { key = 'LeftArrow', mods = CMD, action = act.SendString '\x01' },
  { key = 'RightArrow', mods = CMD, action = act.SendString '\x05' },
  { key = 'Backspace', mods = CMD, action = act.SendString '\x15' },
  { key = 'LeftArrow', mods = 'ALT', action = act.SendString '\x1bb' },
  { key = 'RightArrow', mods = 'ALT', action = act.SendString '\x1bf' },
  { key = 'Backspace', mods = 'ALT', action = act.SendString '\x1b\x7f' },
  { key = 'Delete', mods = 'ALT', action = act.SendString '\x1bd' },

  -- Tabs by number (⌘1…⌘9) — CTRL+SHIFT+digit gives a symbol on some layouts,
  -- so these use ALT+digit, which zsh/nvim/tmux don't use here.
}
for i = 1, 9 do
  table.insert(config.keys, { key = tostring(i), mods = 'ALT', action = act.ActivateTab(i - 1) })
end

-- -- Mouse ------------------------------------------------------------------------

-- iTerm opens links on ⌘-click only; a plain click just selects.
config.mouse_bindings = {
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'NONE',
    action = act.CompleteSelection 'ClipboardAndPrimarySelection' },
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'CTRL',
    action = act.OpenLinkAtMouseCursor },
  { event = { Down = { streak = 1, button = 'Left' } }, mods = 'CTRL',
    action = act.Nop },
}

return config
