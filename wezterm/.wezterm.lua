-- ----------------------------------------------------------------
-- WezTerm config for windows 
--
-- Enable similar multiplexing functionalities as Tmux in Linux/MacOS
-- ----------------------------------------------------------------

local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action
local mux = wezterm.mux
local nerdfonts = wezterm.nerdfonts
local username = os.getenv("USER") or os.getenv("LOGNAME") or os.getenv("USERNAME")

-- Startup
config.default_prog = { "C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoLogo" }
-- config.default_prog = { "/bin/zsh" }
config.automatically_reload_config = true

-- wezterm.on("gui-startup", function(cmd)
--     local tab, pane, window = mux.spawn_window(cmd or {})
--     window:gui_window():toggle_fullscreen()
-- end)

-- Colorscheme
config.color_scheme = "Catppuccin Mocha"
local colors = wezterm.get_builtin_color_schemes()[config.color_scheme]
config.colors = {
    -- cursor_bg = colors.indexed[16],
    -- cursor_border = colors.indexed[16],
    -- split = colors.indexed[16],
    tab_bar = {
        background = colors.background,
        active_tab = {
            bg_color = colors.background,
            fg_color = colors.indexed[16],
            italic = true,
        }
    },
    visual_bell = colors.ansi[1]
}

-- Bell
config.visual_bell = {
    fade_in_function = 'Constant',
    fade_in_duration_ms = 0,
    fade_out_function =  'Constant',
    fade_out_duration_ms = 300,
    target = 'CursorColor',
}

-- Font
config.font = wezterm.font("JetBrainsMono Nerd Font Mono")
config.font_size = 11.0

-- Window
config.window_decorations = "RESIZE"
config.text_background_opacity = 0.9
config.window_background_opacity = 0.9
config.enable_wayland = true
config.window_padding = {
    left   = 3,
    right  = 3,
    top    = 10,
    bottom = 3,
}

config.pane_focus_follows_mouse = true

-- Tab config
config.enable_tab_bar = true
config.adjust_window_size_when_changing_font_size = false
config.switch_to_last_active_tab_when_closing_tab = true
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = true
config.tab_bar_at_bottom = false
config.use_fancy_tab_bar = false
config.tab_max_width = 35


-- Tab bar
local function tab_title(tab_info)
    local title = tab_info.tab_title
    -- if the tab title is explicitly set, use that
    if title and #title > 0 then
        return title
    end
    -- Otherwise, use the title from the active pane in that tab
    title = tab_info.active_pane.title
    title = string.gsub(title, "^Copy mode: ", "" )
    return title
end

-- Cache for system stats
local stats_cache = {
    cpu = 0,
    ram = 0,
    last_update = 0,
    throttle_seconds = 5
}

-- Get system stats (CPU, Mem)
local function get_system_stats()
    local now = os.time()
  
    -- Return cached values if throttle period hasn't elapsed
    if now - stats_cache.last_update < stats_cache.throttle_seconds then
        return stats_cache.cpu, stats_cache.ram
    end
  
    -- Fetch and update cache
    local cpu_percent = 0
    local ram_percent = 0
  
    if wezterm.target_triple:find("linux") then
        -- Linux: Read from /proc/meminfo
        local success, mem_file = pcall(io.open, "/proc/meminfo", "r")
        if success and mem_file then
            local meminfo = mem_file:read("*all")
            mem_file:close()
        
            local mem_total = tonumber(meminfo:match("MemTotal:%s+(%d+)"))
            local mem_available = tonumber(meminfo:match("MemAvailable:%s+(%d+)"))
        
            if mem_total and mem_available then
                ram_percent = math.floor(((mem_total - mem_available) / mem_total) * 100)
            end
        end
    
        -- CPU: Use top command for simplicity
        local cpu_success, cpu_stdout = wezterm.run_child_process({
            "sh", "-c",
            "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | sed 's/%us,//'"
        })
        if cpu_success and cpu_stdout then
            cpu_percent = math.floor(tonumber(cpu_stdout) or 0)
        end
    
    elseif wezterm.target_triple:find("darwin") then
        -- macOS: CPU usage
        local cpu_success, cpu_stdout = wezterm.run_child_process({
            "sh", "-c",
            "ps -A -o %cpu | awk '{s+=$1} END {print s}'"
        })
        if cpu_success and cpu_stdout then
            cpu_percent = math.floor(tonumber(cpu_stdout) or 0)
            -- Cap at 100% (since ps shows per-core usage)
            if cpu_percent > 100 then cpu_percent = 100 end
        end
    
        -- macOS: RAM usage
        local ram_success, ram_stdout = wezterm.run_child_process({
            "sh", "-c",
            "vm_stat | awk '/Pages active/ {active=$3} /Pages wired/ {wired=$4} /Pages inactive/ {inactive=$3} /Pages free/ {free=$3} END {gsub(/\\./, \"\", active); gsub(/\\./, \"\", wired); gsub(/\\./, \"\", inactive); gsub(/\\./, \"\", free); total=active+wired+inactive+free; used=active+wired; print (used/total)*100}'"
        })
        if ram_success and ram_stdout then
            ram_percent = math.floor(tonumber(ram_stdout) or 0)
        end
    
    elseif wezterm.target_triple:find("windows") then
        -- Windows: CPU usage
        local cpu_success, cpu_stdout = wezterm.run_child_process({
        "wmic", "cpu", "get", "loadpercentage", "/value"
        })
        if cpu_success and cpu_stdout then
            cpu_percent = tonumber(cpu_stdout:match("LoadPercentage=(%d+)")) or 0
        end
    
        -- Windows: RAM usage
        local ram_success, ram_stdout = wezterm.run_child_process({
            "wmic", "OS", "get", "FreePhysicalMemory,TotalVisibleMemorySize", "/Value"
        })
        if ram_success and ram_stdout then
            local total = tonumber(ram_stdout:match("TotalVisibleMemorySize=(%d+)"))
            local free = tonumber(ram_stdout:match("FreePhysicalMemory=(%d+)"))
            if total and free then
                ram_percent = math.floor(((total - free) / total) * 100)
            end
        end
    end
  
    -- Update cache
    stats_cache.cpu = cpu_percent
    stats_cache.ram = ram_percent
    stats_cache.last_update = now
  
    return cpu_percent, ram_percent
end

-- Events update status
wezterm.on("update-status", function(window, pane)

    -- Workspace name
    local active_key_table = window:active_key_table()
    local stat = window:active_workspace()
    local workspace_color = "#f5bde6"--colors.ansi[3]
    local time = wezterm.strftime("%Y-%m-%d %H:%M")

    if active_key_table then
        stat = active_key_table
        workspace_color = "#f0c6c6"
    elseif window:leader_is_active() then
        stat = "leader"
        workspace_color = "#f4dbd6"
    end

    -- CPU and RAM usage status
    local cpu_percent, ram_percent = get_system_stats()

    -- Left status (left of the tab line)
    window:set_left_status(wezterm.format({
        { Attribute  = { Intensity = "Bold" }                       },
        { Background = { Color = colors.background }                },
        { Text       = " "                                          },
        { Background = { Color = colors.background }                },
        { Foreground = { Color = workspace_color }                  },
        { Text       = nerdfonts.ple_left_half_circle_thick         },
        { Background = { Color = workspace_color }                  },
        { Foreground = { Color = colors.ansi[1] }                   },
        { Text       = nerdfonts.cod_terminal_tmux .. " "           },
        { Background = { Color = colors.ansi[1] }                   },
        { Foreground = { Color = workspace_color }                  },
        { Text       = " " .. stat .. " "                           },
        { Background = { Color = colors.background }                },
        { Foreground = { Color = colors.ansi[1] }                   },
        { Text       = nerdfonts.ple_right_half_circle_thick .. " " },
    }))

    -- Right status
    window:set_right_status(wezterm.format({
        { Text       = " "                                   },
        { Background = { Color = colors.background }         },
        { Foreground = { Color = "#f38ba8" }               },
        { Text       = nerdfonts.ple_left_half_circle_thick  },
        { Background = { Color = "#f38ba8" }               },
        { Foreground = { Color = colors.background }         },
        { Text       = nerdfonts.md_chip .. " "              },
        { Background = { Color = colors.ansi[1] }            },
        { Foreground = { Color = colors.foreground }         },
        { Text       = " " .. cpu_percent .. " %"            },
        { Background = { Color = colors.background }         },
        { Foreground = { Color = colors.ansi[1] }            },
        { Text       = nerdfonts.ple_right_half_circle_thick },

        { Text       = " "                                   },
        { Background = { Color = colors.background }         },
        { Foreground = { Color = "#eba0ac" }               },
        { Text       = nerdfonts.ple_left_half_circle_thick  },
        { Background = { Color = "#eba0ac" }               },
        { Foreground = { Color = colors.background }         },
        { Text       = nerdfonts.md_memory .. " "            },
        { Background = { Color = colors.ansi[1] }            },
        { Foreground = { Color = colors.foreground }         },
        { Text       = " " .. ram_percent .. " %"            },
        { Background = { Color = colors.background }         },
        { Foreground = { Color = colors.ansi[1] }            },
        { Text       = nerdfonts.ple_right_half_circle_thick },

        { Text       = " "                                   },
        { Background = { Color = colors.background }         },
        { Foreground = { Color = "#fab387" }               },
        { Text       = nerdfonts.ple_left_half_circle_thick  },
        { Background = { Color = "#fab387" }               },
        { Foreground = { Color = colors.ansi[1] }            },
        { Text       = nerdfonts.md_account .. " "           },
        { Background = { Color = colors.ansi[1] }            },
        { Foreground = { Color = colors.foreground }         },
        { Text       = " " .. username                       },
        { Background = { Color = colors.background }         },
        { Foreground = { Color = colors.ansi[1] }            },
        { Text       = nerdfonts.ple_right_half_circle_thick },

        { Text       = " "                                   },
        { Background = { Color = colors.background }         },
        { Foreground = { Color = "#f9e2af"}                },
        { Text       = nerdfonts.ple_left_half_circle_thick  },
        { Background = { Color = "#f9e2af"}                },
        { Foreground = { Color = colors.background }         },
        { Text       = nerdfonts.md_calendar_clock .. " "    },
        { Background = { Color = colors.ansi[1] }            },
        { Foreground = { Color = colors.foreground }         },
        { Text       = " " .. time                           },
        { Background = { Color = colors.background }         },
        { Foreground = { Color = colors.ansi[1] }            },
        { Text       = nerdfonts.ple_right_half_circle_thick },

    }))

end)

-- Events define tab title
wezterm.on("format-tab-title", function(tab, panes)

    local command_args = nil
    local command = nil
    local pane = tab.active_pane
    local title = tab_title(tab)
    local tab_number = tostring(tab.tab_index + 1)
    local program = pane.user_vars.WEZTERM_PROG

    -- Filter command name
    if not program or program ~= "" then
        command_args = program
        if command_args then
            command = string.match(command_args, "^%S+")
        end
    end

    -- Shrink title if too long
    if string.len(title) > config.tab_max_width - 3 then
        title  = string.sub(title, 1, config.tab_max_width - 12) .. ".. "
    end

    -- Add terminal icon
    if tab.is_active then
        title = nerdfonts.dev_terminal .. " " .. title
    end

    -- Add zoom icon
    if pane.is_zoomed then
        title = nerdfonts.cod_zoom_in .. " " .. title
    end

    -- Add copy icon
    if string.match(pane.title,"^Copy mode:") then
        title = nerdfonts.md_content_copy .. " " .. title
    end

    -- Add icon to command
    if command then

        -- Add docker icon
        if command == "docker" or command == "podman" then
            title = nerdfonts.linux_docker .. " " .. title
        end

        -- Add kubernetes icon
        if command == "kind" or command == "kubectl" then
            title = nerdfonts.md_kuberntes .. " " .. title
        end

        -- Add ssh icon
        if command == "ssh" then
            title = nerdfonts.md_remote_desktop .. " " .. title
        end

        -- Add monitoring icon
        if string.match(command,"^([bh]?)top") then
            title = nerdfonts.md_monitor_eye .. " " .. title
        end

        -- Add vim icon
        if string.match(command,"^(n?)vi(m?)") then
            title = nerdfonts.dev_vim .. " " .. title
        end

        -- Add watch icon
        if command == "watch" then
            title = nerdfonts.md_eye_outline .. " " .. title
        end

    end

    -- Add bell icon
    -- on inactive panes if something shows up
    local has_unseen_output = false
    if not tab.is_active then

        for _, pane in ipairs(tab.panes) do
            if pane.has_unseen_output then
                has_unseen_output = true
                break
            end
        end
    end

    -- Add bell icon
    if has_unseen_output then
        title = nerdfonts.md_bell_ring_outline .. " " .. title
    end

    if tab.is_active then
        return {
            { Background = { Color = colors.background }                },
            { Foreground = { Color = "#cba6f7"}                       },
            { Text       = title .. " "                                 },
            { Background = { Color = "#cba6f7"}                       },
            { Foreground = { Color = colors.background }                },
            { Text       = " " .. tab_number                            },
            { Background = { Color = colors.background }                },
            { Foreground = { Color = "#cba6f7"}                       },
            { Text       = nerdfonts.ple_right_half_circle_thick .. " " },
      }
    else
        return {
            { Background = { Color = colors.background }                },
            { Foreground = { Color = colors.ansi[1]    }                },
            { Text       = nerdfonts.ple_left_half_circle_thick         },
            { Background = { Color = colors.ansi[1]    }                },
            { Foreground = { Color = colors.foreground }                },
            { Text       = title .. " "                                 },
            { Background = { Color = "#b4befe"     }                  },
            { Foreground = { Color = colors.background }                },
            { Text       = " " .. tab_number                            },
            { Background = { Color = colors.background }                },
            { Foreground = { Color = "#b4befe"    }                   },
            { Text       = nerdfonts.ple_right_half_circle_thick .. " " },
        }
    end
end)

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

-- Enable/disable tmux mode
local tmux_mode = false

local function set_tmux_keys(window)
    local overrides = window:get_config_overrides() or {}
    if tmux_mode == true then
        overrides.leader = { key = "F13", mods = "CTRL|ALT|SHIFT|SUPER" }
        overrides.keys = {
            { key = 'F12', mods = 'NONE', action = wezterm.action_callback(function(window, pane)
              tmux_mode = not tmux_mode
              set_tmux_keys(window)
            end), },
            { key = 'c', mods = 'CTRL', action = act.EmitEvent 'copy-or-interrupt' },
        }
        wezterm.log_info("Tmux mode ON")
    else
        overrides.leader = nil
        overrides.keys = nil
        wezterm.log_info("Tmux mode OFF")
    end
    window:set_config_overrides(overrides)
end

-- Wezterm shell integration (download wezterm.sh)
wezterm.on('user-var-changed', function(window, pane, name, value)
  if name == 'WEZTERM_IN_TMUX' then
    wezterm.log_info('WEZTERM_IN_TMUX = ' .. value)
    tmux_mode = (value == "1")
    set_tmux_keys(window)
  end
end)

-- Custom keybinds for multiplexing
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 2000 }

config.keys = {

    -- Manual switch to disable wezterm leader key when using tmux
    {
        key = 'F12',
        mods = 'NONE',
        action = wezterm.action_callback(function(window, pane)
            wezterm.log_info("Manual toggle Tmux mode")
            tmux_mode = not tmux_mode
            set_tmux_keys(window)
        end),
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
        action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' },
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
    -- Move/Resize panes
    split_nav("move", "h"),
    split_nav("move", "j"),
    split_nav("move", "k"),
    split_nav("move", "l"),
    split_nav("resize", "h"),
    split_nav("resize", "j"),
    split_nav("resize", "k"),
    split_nav("resize", "l"),
}
    
-- Switch tabs
for i = 1, 9 do
    table.insert(config.keys, {
        key = tostring(i),
        mods = "LEADER",
        action = act.ActivateTab(i - 1),
    })
end

return config
