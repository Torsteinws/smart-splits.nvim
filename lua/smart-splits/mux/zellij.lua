local Direction = require('smart-splits.types').Direction
local lazy = require('smart-splits.lazy')
local config = lazy.require_on_index('smart-splits.config') --[[@as SmartSplitsConfig]]
local utils = require('smart-splits.utils')
--- @module 'smart-splits.mux.generic'
local generic_mux = lazy.require_on_index('smart-splits.mux.generic')

local function zellij_exec(cmd)
  local command = vim.deepcopy(cmd)
  table.insert(command, 1, 'zellij')
  return utils.system(command)
end

-- It is very expensive to ask zellij for the current pane id.
-- We also don't need the ID to move to the next pane.
-- However, SmartSplitsMultiplexer (and ./init.lua) demands that we return a number.
-- So let's just return -1
local function current_pane_id()
  return -1
end

-- Not supported yet: https://github.com/mrjones2014/smart-splits.nvim/issues/477
local function current_pane_at_edge()
  return false
end

local function current_pane_is_zoomed()
  return false
end

local function next_pane(direction)
  local action = 'move-focus'
  if config.zellij_move_focus_or_tab and (direction == Direction.left or direction == Direction.right) then
    action = 'move-focus-or-tab'
  end
  local _, code = zellij_exec({ 'action', action, direction })
  return code == 0
end

-- size is not supported on zellij
-- function M.split_pane(direction, _size) ---@diagnostic disable-line: unused-local
--   -- zellij only splits right and down; for the others,
--   -- we must split right and down then swap the panes
--   local args = { 'action', 'new-pane' }
--   local need_swap
--   if direction == Direction.left then
--     table.insert(args, 'right')
--     need_swap = 'right'
--   elseif direction == Direction.up then
--     table.insert(args, 'down')
--     need_swap = 'down'
--   else
--     table.insert(args, direction)
--   end
--   local _, split_code = zellij_exec(args)
--   if need_swap ~= nil then
--     local _, swap_code = zellij_exec({ 'action', 'move-pane', need_swap })
--     M.update_mux_layout_details()
--     return split_code == 0 and swap_code == 0
--   end
--   M.update_mux_layout_details()
--   return split_code == 0
-- end

local M = {}

--- @type GenericMuxMoveCursorArg
local move_cursor_mux = {
  current_pane_id = current_pane_id,
  current_pane_at_edge = current_pane_at_edge,
  current_pane_is_zoomed = current_pane_is_zoomed,
  next_pane = next_pane,
}

--- Tries to move the cursor to the next multiplexer window in the given direction.
--- @param direction SmartSplitsDirection The direction to move ('up'|'down'|'left'|'right')
--- @return boolean did_move True if the cursor moved, false otherwise
function M.move_cursor(direction)
  return generic_mux.move_cursor(direction, move_cursor_mux)
end

--- Resize the pane with multiplexer
--- @param direction SmartSplitsDirection The direction to resize the pane
function M.resize(direction)
  if config.disable_multiplexer_nav_when_zoomed and current_pane_is_zoomed() then
    return false
  end
  local _, code = zellij_exec({ 'action', 'resize', 'increase', direction })
  return code == 0
end

return M
