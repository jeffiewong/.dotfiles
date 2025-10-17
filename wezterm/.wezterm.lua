-- ----------------------------------------------------------------
-- WezTerm config for windows 
--
-- Enable similar functionalities as Tmux in Linux/MacOS
-- ----------------------------------------------------------------

local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action
local mux = wezterm.mux
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

-- Default shell (PowerShell 7)
config.default_prog = { "C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoLogo" }

local function is_wsl()
  local f = io.open('/proc/sys/kernel/osrelease', 'r')
  if f then
    local content = f:read('*all')
    f:close()
    if string.find(content:lower(), 'microsoft') or string.find(content:lower(), 'wsl') then
      return true
    end
  end
  if os.getenv('WSL_DISTRO_NAME') then
    return true
  end
  return false
end

local function is_powershell()
  -- Check default_prog first (instance-wide)
  if config.default_prog and #config.default_prog > 0 then
    local prog = config.default_prog[1]:lower()
    if prog:find('powershell%.exe') or prog:find('pwsh%.exe') then
      return true
    end
  end
  return false
end

-- local in_wsl = is_wsl()
-- wezterm.log_info(in_wsl and 'WSL detected' or 'Not WSL')

-- local in_powershell = is_powershell()
-- wezterm.log_info(in_powershell and 'Powershell detected' or 'Not Powershell') 

config.font = wezterm.font("Hack Nerd Font")
config.color_scheme = "Catppuccin Mocha"
config.window_decorations = "RESIZE"
config.enable_wayland = true

config.adjust_window_size_when_changing_font_size = false
config.hide_tab_bar_if_only_one_tab = false
config.pane_focus_follows_mouse = true

-- Tab bar
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.switch_to_last_active_tab_when_closing_tab = true
tabline.setup()
tabline.apply_to_config(config)

-- Open URLs with Ctrl+Click
config.mouse_bindings = {
    {
        event = { Up = { streak = 1, button = 'Left' } },
        mods = 'CTRL',
        action = act.OpenLinkAtMouseCursor,
    }
}

-- Event listener for copying highlighted text
wezterm.on('copy-or-interrupt', function(window, pane)
    local has_selection = window:get_selection_text_for_pane(pane) ~= ''
    if has_selection then
        window:perform_action(act.CopyTo 'Clipboard', pane)
        window:perform_action(act.ClearSelection, pane)
    else
        window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
    end
end)

-- Custom keybinds
config.keys = {
    -- Original keybind for leader key <C-a> is Select-All, rebind Select-All to <leader>a
    { key = 'a', mods = 'LEADER', action = act.SendKey { key = 'a', mods = 'CTRL' }, },
    -- <C-c> to copy text if there are text highlighted, otherwise send interrupt signal
    { key = 'c', mods = 'CTRL', action = act.EmitEvent 'copy-or-interrupt' },
    -- Paste with <C-v>
    { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
    -- Copy mode
    { key = '[', mods = 'LEADER', action = act.ActivateCopyMode, },
}

if in_powershell then
    config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 2000 }

    -- ----------------------------------------------------------------
    -- Workspaces
    --
    -- Roughly equivalent to tmux sessions.
    -- ----------------------------------------------------------------
    
    -- Show all workspaces
    table.insert(config.keys, {
        key = 's',
        mods = 'LEADER',
        action = act.ShowLauncherArgs { flags = 'WORKSPACES' },
    })

    -- Rename current session; analagous to command in tmux
    table.insert(config.keys, {
        key = '$',
        mods = 'LEADER|SHIFT',
        action = act.PromptInputLine {
            description = 'Enter new name for session',
            action = wezterm.action_callback(
                function(window, pane, line)
                    if line then
                        mux.rename_workspace(
                            window:mux_window():get_workspace(),
                            line
                        )
                    end
                end
            ),
        },
    })

    -- ----------------------------------------------------------------
    -- TABS
    --
    -- Tmux windows = wezterm tabs
    -- ----------------------------------------------------------------

    -- Show tab navigator; similar to listing windows in tmux
    table.insert(config.keys, {
        key = 'w',
        mods = 'LEADER',
        action = act.ShowTabNavigator,
    })
    -- Create a tab
    table.insert(config.keys, {
        key = 'c',
        mods = 'LEADER',
        action = act.SpawnTab 'CurrentPaneDomain',
    })
    -- Rename current window/tab displayed in Switch Menu
    table.insert(config.keys, {
        key = ',',
        mods = 'LEADER',
        action = act.PromptInputLine {
            description = 'Enter new name for tab',
            action = wezterm.action_callback(
                function(window, pane, line)
                    if line then
                        window:active_tab():set_title(line)
                    end
                end
            ),
        },
    })
    -- Move to next tab
    table.insert(config.keys, {
        key = 'n',
        mods = 'LEADER',
        action = act.ActivateTabRelative(1),
    })
    -- Move to previous tab
    table.insert(config.keys, {
        key = 'p',
        mods = 'LEADER',
        action = act.ActivateTabRelative(-1),
    })
    -- Close tab
    table.insert(config.keys, {
        key = '&',
        mods = 'LEADER|SHIFT',
        action = act.CloseCurrentTab{ confirm = true },
    })

    -- ----------------------------------------------------------------
    -- PANES
    --
    -- Can use "wezterm ssh" to ssh to another
    -- server, and still retain Wezterm as your terminal there.
    -- ----------------------------------------------------------------

    -- Vertical split
    table.insert(config.keys, {
        key = '|',
        mods = 'LEADER|SHIFT',
        action = act.SplitPane {
            direction = 'Right',
            size = { Percent = 50 },
        },
    })
    -- Horizontal split
    table.insert(config.keys, {
        -- -
        key = '-',
        mods = 'LEADER',
        action = act.SplitPane {
            direction = 'Down',
            size = { Percent = 50 },
        },
    })
    -- CTRL + (h,j,k,l) to move between panes
    table.insert(config.keys, { key = 'h', mods = 'CTRL', action = act.ActivatePaneDirection 'Left' })
    table.insert(config.keys, { key = 'j', mods = 'CTRL', action = act.ActivatePaneDirection 'Down' })
    table.insert(config.keys, { key = 'k', mods = 'CTRL', action = act.ActivatePaneDirection 'Up' })
    table.insert(config.keys,{ key = 'l', mods = 'CTRL', action = act.ActivatePaneDirection 'Right' })
    -- ALT + (h,j,k,l) to resize panes
    table.insert(config.keys,{ key = 'h', mods = 'ALT', action = act.AdjustPaneSize { 'Left', 1 } })
    table.insert(config.keys,{ key = 'j', mods = 'ALT', action = act.AdjustPaneSize { 'Down', 1 } })
    table.insert(config.keys,{ key = 'k', mods = 'ALT', action = act.AdjustPaneSize { 'Up', 1 } })
    table.insert(config.keys,{ key = 'l', mods = 'ALT', action = act.AdjustPaneSize { 'Right', 1 } })
    -- Close/kill active pane
    table.insert(config.keys,{
        key = 'x',
        mods = 'LEADER',
        action = act.CloseCurrentPane { confirm = true },
    })
    -- Swap active pane with another one
    table.insert(config.keys,{
        key = '{',
        mods = 'LEADER|SHIFT',
        action = act.PaneSelect { mode = "SwapWithActiveKeepFocus" },
    })
    -- Zoom current pane (toggle)
    table.insert(config.keys,{
        key = 'z',
        mods = 'LEADER',
        action = act.TogglePaneZoomState,
    })
end

return config