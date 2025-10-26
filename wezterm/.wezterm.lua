-- ----------------------------------------------------------------
-- WezTerm config for windows 
--
-- Enable similar multiplexing functionalities as Tmux in Linux/MacOS
-- ----------------------------------------------------------------

local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action
local mux = wezterm.mux
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

-- Default shell (PowerShell 7)
config.default_prog = { "C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoLogo" }

-- Maximize on startup
wezterm.on("gui-startup", function(cmd)
    local tab, pane, window = mux.spawn_window(cmd or {})
    window:gui_window():toggle_fullscreen()
end)

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

-- Listen to is_tmux user var emitted from tmux; Disable leader key when tmux is active
-- wezterm.on('user-var-changed', function(window, pane, name, value)
--     wezterm.log_info("User Var detected: " .. tostring(name) .. " = " .. tostring(value))
--     if name == 'is_tmux' then
--         local overrides = window:get_config_overrides() or {}
        
--         if value == 'true' then
--             -- Disable WezTerm leader when tmux is active
--             overrides.leader = { key = 'a', mods = 'CTRL|ALT|SHIFT|SUPER', timeout_milliseconds = 1000 }
--             wezterm.log_info('Tmux active - WezTerm leader disabled')
--         else
--             -- Re-enable WezTerm leader
--             overrides.leader = nil
--             wezterm.log_info('Tmux inactive - WezTerm leader enabled')
--         end
        
--         window:set_config_overrides(overrides)
--     end
-- end)

-- Enable/disable wezterm leader key
wezterm.on("toggle-leader", function(window, pane)
    local overrides = window:get_config_overrides() or {}
    if not overrides.leader then
        overrides.leader = { key = "F13", mods = "CTRL|ALT|SHIFT|SUPER" }
        wezterm.log_info("[toggle-leader] WezTerm leader disabled")
    else
        -- restore to the main leader
        overrides.leader = nil
        wezterm.log_info("[toggle-leader] WezTerm leader enabled")
    end
    window:set_config_overrides(overrides)
end)

-- Custom keybinds for multiplexing
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 2000 }

config.keys = {

    -- Manual switch to disable wezterm leader key when using tmux
    {
		key = 'F12',
		mods = 'NONE',
		action = wezterm.action {EmitEvent = "toggle-leader"},
	},

    -- Original keybind for leader key <C-a> is Select-All, rebind Select-All to <leader>a
    { key = 'a', mods = 'LEADER', action = act.SendKey { key = 'a', mods = 'CTRL' }, },
    -- <C-c> to copy text if there are text highlighted, otherwise send interrupt signal
    { key = 'c', mods = 'CTRL', action = act.EmitEvent 'copy-or-interrupt' },
    -- Paste with <C-v>
    { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
    -- Copy mode
    { key = '[', mods = 'LEADER', action = act.ActivateCopyMode, },

    -- ----------------------------------------------------------------
    -- Workspaces
    --
    -- Roughly equivalent to tmux sessions.
    -- ----------------------------------------------------------------

    -- Create new workspace (with Powershell or WSL selection)
    {
        key = 'S',
        mods = 'LEADER|SHIFT',
        action = act.InputSelector {
            description = 'Choose shell for new workspace',
            choices = {
                { label = 'WSL', id= 'wsl' },
                { label = 'PowerShell', id = 'powershell' },
            },
            action = wezterm.action_callback(function(window, pane, id, label)
                wezterm.log_info('InputSelector triggered: id=' .. (id or 'nil') .. ', label=' .. (label or 'nil'))

                if (not id) or (not label) then
                    wezterm.log_info('No selection made, exiting')
                    return
                end

                local spawn_config
                if label == 'PowerShell' then
                    spawn_config = {
                        args = { 'C:\\Program Files\\PowerShell\\7\\pwsh.exe', '-NoLogo' }
                    }
                    wezterm.log_info('Selected PowerShell')
                elseif label == 'WSL' then
                    spawn_config = {
                        domain = { DomainName = 'WSL:Ubuntu-22.04' },  -- Spawn via WSL domain
                    }
                    wezterm.log_info('Selected Ubuntu-22.04 domain')
                else
                    wezterm.log_info('Unknown Selection: ' .. label)
                    return
                end

                wezterm.log_info('Attempting to switch to new workspace with: ' .. (spawn_config.domain and 'domain=' .. spawn_config.domain.DomainName or 'args=' .. table.concat(spawn_config.args or {}, ' ')))
                window:perform_action(
                    act.SwitchToWorkspace {
                        spawn = spawn_config
                    },
                    pane
                )
                wezterm.log_info('SwitchToWorkspace action dispatched')
            end),
        },
    },
    -- Show list of workspaces
    {
        key = 's',
        mods = 'LEADER',
        action = act.ShowLauncherArgs { flags = 'WORKSPACES' },
    },
    -- Rename current session
    {
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
    },

    -- ----------------------------------------------------------------
    -- TABS
    --
    -- Tmux windows = wezterm tabs
    -- ----------------------------------------------------------------

    -- Show tab navigator; similar to listing windows in tmux
    {
        key = 'w',
        mods = 'LEADER',
        action = act.ShowTabNavigator,
    },
    -- Create a tab
    {
        key = 'c',
        mods = 'LEADER',
        action = act.SpawnTab 'CurrentPaneDomain',
    },
    -- Rename current window/tab displayed in Switch Menu
    {
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
    },
    -- Move to next tab
    {
        key = 'n',
        mods = 'LEADER',
        action = act.ActivateTabRelative(1),
    },
    -- Move to previous tab
    {
        key = 'p',
        mods = 'LEADER',
        action = act.ActivateTabRelative(-1),
    },
    -- Close tab
    {
        key = '&',
        mods = 'LEADER|SHIFT',
        action = act.CloseCurrentTab{ confirm = true },
    },

    -- ----------------------------------------------------------------
    -- PANES
    --
    -- Can use "wezterm ssh" to ssh to another
    -- server, and still retain Wezterm as your terminal there.
    -- ----------------------------------------------------------------

    -- Vertical split
    {
        key = '|',
        mods = 'LEADER|SHIFT',
        action = act.SplitPane {
            direction = 'Right',
            size = { Percent = 50 },
        },
    },
    -- Horizontal split
    {
        key = '-',
        mods = 'LEADER',
        action = act.SplitPane {
            direction = 'Down',
            size = { Percent = 50 },
        },
    },
    -- Close/kill active pane
    {
        key = 'x',
        mods = 'LEADER',
        action = act.CloseCurrentPane { confirm = true },
    },
    -- Swap active pane with another one
    {
        key = '{',
        mods = 'LEADER|SHIFT',
        action = act.PaneSelect { mode = "SwapWithActiveKeepFocus" },
    },
    -- Zoom current pane (toggle)
    {
        key = 'z',
        mods = 'LEADER',
        action = act.TogglePaneZoomState,
    },
}
    
-- Switch tabs
for i = 1, 9 do
    table.insert(config.keys, {
        key = tostring(i),
        mods = "LEADER",
        action = act.ActivateTab(i - 1),
    })
end

-- smart-splits.nvim config. CTRL + (h,j,k,l) to move between panes | ALT + (h,j,k,l) to resize panes
local direction_keys = {
    h = "Left",
    j = "Down",
    k = "Up",
    l = "Right",
}

local function is_vim(pane)
    -- this is set by the plugin, and unset on ExitPre in Neovim
    return pane:get_user_vars().IS_NVIM == "true"
end

local function split_nav(resize_or_move, key)
    return {
        key = key,
        mods = resize_or_move == "resize" and "ALT" or "CTRL",
        action = wezterm.action_callback(function(win, pane)
            if is_vim(pane) then
                win:perform_action({
                    SendKey = { key = key, mods = resize_or_move == "resize" and "ALT" or "CTRL" },
                }, pane)
            else
                if resize_or_move == "resize" then
                    win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
                else
                    win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
                end
            end
        end),
    }
end

table.insert(config.keys, split_nav("move", "h"))
table.insert(config.keys, split_nav("move", "j"))
table.insert(config.keys, split_nav("move", "k"))
table.insert(config.keys, split_nav("move", "l"))
table.insert(config.keys, split_nav("resize", "h"))
table.insert(config.keys, split_nav("resize", "j"))
table.insert(config.keys, split_nav("resize", "k"))
table.insert(config.keys, split_nav("resize", "l"))

return config
