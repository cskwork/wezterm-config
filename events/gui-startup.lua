local wezterm = require('wezterm')
local mux = wezterm.mux
local sidebar = require('events.sidebar')

local M = {}

---@param opts? { spawn_sidebar?: boolean }
M.setup = function(opts)
   opts = opts or {}
   local spawn_sidebar = opts.spawn_sidebar ~= false
   wezterm.on('gui-startup', function(cmd)
      local _, _, window = mux.spawn_window(cmd or {})
      window:gui_window():maximize()
      if spawn_sidebar then
         sidebar.spawn(window)
      end
   end)
end

return M
