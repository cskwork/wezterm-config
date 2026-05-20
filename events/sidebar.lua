-- Sidebar pane that lists all WezTerm windows/tabs/panes for quick jumping.
-- The sidebar pane runs `utils/sidebar.sh` which polls `wezterm cli list`
-- and accepts number keys to activate the chosen pane.
--
-- Pairs with `pane_switcher_action`: an InputSelector overlay usable from any pane.

local wezterm = require('wezterm')
local mux = wezterm.mux
local act = wezterm.action

local M = {}

-- The sidebar script announces itself via `printf '\033]0;wezterm-sidebar\007'`.
-- We use this title to recognize the sidebar pane from Lua.
local SIDEBAR_TITLE = 'wezterm-sidebar'
local SIDEBAR_WIDTH = 32

local function script_path()
   return wezterm.config_dir .. '/utils/sidebar.sh'
end

---@param mux_window any
---@return any|nil pane, any|nil tab
local function find_sidebar_pane(mux_window)
   for _, tab in ipairs(mux_window:tabs()) do
      for _, p in ipairs(tab:panes()) do
         if p:get_title() == SIDEBAR_TITLE then
            return p, tab
         end
      end
   end
   return nil, nil
end

---Split a left sidebar off the currently active pane.
---@param mux_window any MuxWindow
function M.spawn(mux_window)
   if find_sidebar_pane(mux_window) then return end
   local tab = mux_window:active_tab()
   if not tab then return end
   local active = tab:active_pane()
   if not active then return end

   active:split({
      direction = 'Left',
      size = { Cells = SIDEBAR_WIDTH },
      args = { '/usr/bin/env', 'bash', script_path() },
   })
   -- Restore focus to the original pane (split steals focus by default).
   active:activate()
end

M.toggle_action = wezterm.action_callback(function(gui_window, _pane)
   local mux_window = gui_window:mux_window()
   local existing = find_sidebar_pane(mux_window)
   if existing then
      wezterm.run_child_process({
         'wezterm', 'cli', 'kill-pane', '--pane-id', tostring(existing:pane_id()),
      })
   else
      M.spawn(mux_window)
   end
end)

M.switcher_action = wezterm.action_callback(function(gui_window, gui_pane)
   local choices = {}
   for _, w in ipairs(mux.all_windows()) do
      for _, tab in ipairs(w:tabs()) do
         for _, p in ipairs(tab:panes()) do
            if p:get_title() ~= SIDEBAR_TITLE then
               table.insert(choices, {
                  id = tostring(p:pane_id()),
                  label = string.format(
                     'W%d  T%d  P%d   %s',
                     w:window_id(), tab:tab_id(), p:pane_id(), p:get_title()
                  ),
               })
            end
         end
      end
   end
   gui_window:perform_action(
      act.InputSelector({
         title = 'Switch pane',
         choices = choices,
         fuzzy = true,
         fuzzy_description = 'pane > ',
         action = wezterm.action_callback(function(_w, _p, id, _label)
            if not id then return end
            wezterm.run_child_process({
               'wezterm', 'cli', 'activate-pane', '--pane-id', id,
            })
         end),
      }),
      gui_pane
   )
end)

return M
