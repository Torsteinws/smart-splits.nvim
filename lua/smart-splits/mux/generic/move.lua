local lazy = require('smart-splits.lazy')
local log = lazy.require_on_exported_call('smart-splits.log')
local config = lazy.require_on_index('smart-splits.config')
local types = require('smart-splits.types')
local Direction = types.Direction
local AtEdgeBehavior = types.AtEdgeBehavior

local directions_reverse = {
  [Direction.left] = Direction.right,
  [Direction.right] = Direction.left,
  [Direction.up] = Direction.down,
  [Direction.down] = Direction.up,
}

local function move_multiplexer_inner(direction, multiplexer)
  local current_pane = multiplexer.current_pane_id()
  if not current_pane then
    log.debug('Failed to get multiplexer pane ID')
    return false
  end

  local ok = multiplexer.next_pane(direction)
  if not ok then
    log.debug('Failed to select multiplexer pane')
    return false
  end
  local new_pane = multiplexer.current_pane_id()
  if not new_pane then
    log.debug('Failed to get multiplexer pane ID')
    return false
  end

  -- we've moved to a new multiplexer pane, finish
  if current_pane ~= new_pane then
    return true
  end

  -- zellij does not support multiplexer.current_pane_id(), so we will just assume that it was successfull
  if multiplexer.type == 'zellij' then
    return true
  end

  return false
end

local M = {}

--- @class GenericMuxMoveCursorArg
--- @field current_pane_id fun():number|nil
--- @field current_pane_at_edge fun(direction:SmartSplitsDirection):boolean
--- @field current_pane_is_zoomed fun():boolean
--- @field next_pane fun(direction:SmartSplitsDirection):boolean

--- Moves the cursor to another multiplexer pane.
---
--- This is the legacy, default movement algorithm used by
--- multiplexer integrations that do not implement their own cursor-movement logic.
--- @param direction SmartSplitsDirection The direction to move ('up'|'down'|'left'|'right')
--- @param multiplexer GenericMuxMoveCursorArg Multiplexer operations that is used to determine state and movement
function M.move_cursor(direction, multiplexer)
  local ok, result = pcall(function()
    if config.at_edge ~= AtEdgeBehavior.wrap and multiplexer.current_pane_at_edge(direction) then
      return false
    end

    if config.disable_multiplexer_nav_when_zoomed and multiplexer.current_pane_is_zoomed() then
      return false
    end

    local multiplexer_moved = move_multiplexer_inner(direction, multiplexer)
    if multiplexer_moved then
      return multiplexer_moved
    end

    if config.at_edge == AtEdgeBehavior.wrap then
      return move_multiplexer_inner(directions_reverse[direction], multiplexer)
    end

    return false
  end)

  if not ok then
    log.error(result)
    return false
  end

  return result
end

return M
