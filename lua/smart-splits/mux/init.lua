local mux_utils = require('smart-splits.mux.utils')
local lazy = require('smart-splits.lazy')
--- @module 'smart-splits.mux.wezterm'
local wezterm = lazy.require_on_exported_call('smart-splits.mux.wezterm')

local M = {}

local setup_complete = false
function M.setup()
  if setup_complete then
    return
  end

  if not mux_utils.is_mux_allowed() then
    return
  end

  if mux_utils.are_we_wezterm() then
    wezterm.setup()
  end

  setup_complete = true
end

return M
