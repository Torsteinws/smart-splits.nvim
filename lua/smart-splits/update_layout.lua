local mux_utils = require('smart-splits.mux.utils')
local lazy = require('smart-splits.lazy')
--- @module 'smart-splits.mux.wezterm'
local kitty = lazy.require_on_exported_call('smart-splits.mux.kitty')

local M = {}

function M.update_layout_details()
  if not mux_utils.is_mux_allowed() then
    return
  end

  if mux_utils.are_we_kitty() then
    kitty.update_mux_layout_details()
  end
end

return M
