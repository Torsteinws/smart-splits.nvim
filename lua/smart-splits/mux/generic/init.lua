local lazy = require('smart-splits.lazy')
--- @module 'smart-splits.mux.generic.events'
local events = lazy.require_on_exported_call('smart-splits.mux.generic.events')
--- @module 'smart-splits.mux.generic.move'
local move_mod = lazy.require_on_exported_call('smart-splits.mux.generic.move')

local M = {}

M.events = events
M.move_cursor = move_mod.move_cursor

return M
