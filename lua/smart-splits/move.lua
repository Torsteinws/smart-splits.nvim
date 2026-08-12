local lazy = require('smart-splits.lazy')
local config = lazy.require_on_index('smart-splits.config') --[[@as SmartSplitsConfig]]
local mux = lazy.require_on_exported_call('smart-splits.mux') --[[@as SmartSplitsMuxApi]]
local utils = require('smart-splits.utils')
local win = require('smart-splits.win')
local types = require('smart-splits.types')
local Direction = types.Direction
local FloatWinBehavior = types.FloatWinBehavior
local AtEdgeBehavior = types.AtEdgeBehavior
local mux_utils = require('smart-splits.mux.utils')
--- @module 'smart-splits.mux.zellij'
local zellij = lazy.require_on_exported_call('smart-splits.mux.zellij')
--- @module 'smart-splits.mux.wezterm'
local wezterm = lazy.require_on_exported_call('smart-splits.mux.wezterm')

local DirectionKeys = win.DirectionKeys
local DirectionKeysReverse = win.DirectionKeysReverse

--- @param direction SmartSplitsDirection The direction to move ('up'|'down'|'left'|'right')
--- @return nil
local function nvim_split_and_focus(direction)
  if direction == Direction.left or direction == Direction.right then
    vim.cmd('vsp')
    if vim.opt.splitright and direction == Direction.left then
      vim.cmd.wincmd('h')
    end
  else
    vim.cmd('sp')
    if vim.opt.splitbelow and direction == Direction.up then
      vim.cmd.wincmd('k')
    end
  end
end

--- Moves the cursor to the next nvim window in the given direction
--- @param direction SmartSplitsDirection The direction to move ('up'|'down'|'left'|'right')
--- @return nil
local function nvim_next_window(direction)
  local dir_key = DirectionKeys[direction]
  local current_is_embeded_floating = utils.is_embedded_floating_window()
  local offset = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]
  vim.cmd.wincmd(vim.v.count1 .. dir_key)
  local next_is_embeded_floating = utils.is_embedded_floating_window()
  if
    config.move_cursor_same_row
    and (direction == Direction.left or direction == Direction.right)
    and not current_is_embeded_floating
    and not next_is_embeded_floating
  then
    offset = offset - vim.api.nvim_win_get_position(0)
    vim.cmd('normal! ' .. offset .. 'H')
  end
end

--- Wraps the cursor around the edge in the given direction
--- @param direction SmartSplitsDirection The direction to move ('up'|'down'|'left'|'right')
--- @return nil
local function nvim_wrap_cursor(direction)
  local opposite_direction = DirectionKeysReverse[direction]

  -- If we are in a window that is technically floating but visually behaves like a sidebar or panel (e.g. snacks explorer),
  -- Then we first need to first exit the window
  local current_is_embeded_floating = utils.is_embedded_floating_window()
  if current_is_embeded_floating then
    vim.cmd.wincmd('999' .. opposite_direction)
  end

  local offset = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]
  vim.cmd.wincmd('999' .. opposite_direction)
  local next_is_embeded_floating = utils.is_embedded_floating_window()
  if
    config.move_cursor_same_row
    and (direction == Direction.left or direction == Direction.right)
    and not current_is_embeded_floating
    and not next_is_embeded_floating
  then
    offset = offset - vim.api.nvim_win_get_position(0)[1]
    vim.cmd('normal! ' .. offset .. 'H')
  end
end

--- Tries to move the cursor to the next nvim window in the given direction.
--- Does not wrap around screen edges.
--- @param direction SmartSplitsDirection The direction to move ('up'|'down'|'left'|'right')
--- @return boolean did_move True if the cursor moved to a new window, false otherwise
local function nvim_move_cursor(direction)
  -- Nothing to do if the current pane is floating and we are at an edge
  local is_floating_at_edge = utils.is_floating_window_at_screen_edge(nil, direction)
  if is_floating_at_edge then
    return false
  end

  -- Handle navigation for windows that are technically floating but visually behaves like a sidebar or panel (e.g. snacks explorer)
  local is_embeded_floating = utils.is_embedded_floating_window()
  if is_embeded_floating then
    nvim_next_window(direction)
    return true
  end

  -- NOTE:
  -- I don't quite understand the justification for this.
  -- This piece of code seems a bit dubios to me.
  -- Should ask mrjones2014 about their opinion in code review
  local is_floating = utils.is_floating_window()
  if is_floating and config.float_win_behavior == FloatWinBehavior.previous then
    local prev_win = vim.fn.win_getid(vim.fn.winnr('#'))
    local is_prev_floating = utils.is_floating_window(prev_win)
    if not is_prev_floating then
      vim.api.nvim_set_current_win(prev_win)
      return true
    end
  end

  local dir_key = DirectionKeys[direction]
  local current_win = vim.fn.winnr()
  local next_win = vim.fn.winnr(vim.v.count1 .. dir_key)
  local is_at_edge = next_win == current_win
  if not is_at_edge then
    nvim_next_window(direction)
    return true
  end

  return false
end

--- Tries to move the cursor to the next multiplexer window in the given direction.
--- @param direction SmartSplitsDirection The direction to move ('up'|'down'|'left'|'right')
--- @return boolean did_move True if the cursor moved, false otherwise
local function multiplexer_move_cursor(direction)
  if not mux_utils.is_mux_allowed() then
    return false
  end

  -- TODO:
  -- Implement integration for:
  --   * herdr
  --   * kitty
  --   * tmux
  if mux_utils.are_we_zellij() then
    return zellij.move_cursor(direction)
  elseif mux_utils.are_we_wezterm() then
    return wezterm.move_cursor(direction)
  else
    return false
  end
end

--- Split the current pane in the given direction.
--- @param direction SmartSplitsDirection The direction to split the pane.
--- @param size? number|nil Optional size of the new pane
--- @return boolean did_split True if the multiplexer did split the pane, false otherwise
local function multiplexer_split_and_focus(direction, size)
  if not mux_utils.is_mux_allowed() then
    return false
  end

  if mux_utils.are_we_wezterm() then
    return wezterm.split_and_focus(direction, size)
  else
    return false
  end
end

--- Executes a custom user-defined function to move the cursor.
--- @param direction SmartSplitsDirection The direction to move ('up'|'down'|'left'|'right').
--- @return boolean did_move True if the cursor moved, false otherwise.
--- @error Raises an error if the custom user function does not return a boolean.
local function custom_fn_move_cursor(direction)
  if type(config.at_edge) ~= 'function' then
    return false
  end

  local context = { ---@type SmartSplitsContext
    mux = mux.get(),
    direction = direction,
    split = function()
      nvim_split_and_focus(direction)
    end,
    wrap = function()
      nvim_wrap_cursor(direction)
    end,
  }
  local result = config.at_edge(context)
  if type(result) ~= 'boolean' then
    error(
      'Expected at_edge to return a boolean, but received '
        .. type(result)
        .. " with the value '"
        .. tostring(result)
        .. "'"
    )
  end
  return result
end

local M = {}

--- Entrypoint for smart cursor navigation
--- @param direction SmartSplitsDirection The direction to move ('up'|'down'|'left'|'right')
--- @error Raises an error if the user writes a bad custom function for config.at_edge
function M.move_cursor(direction)
  local moved_in_nvim = nvim_move_cursor(direction)
  if moved_in_nvim then
    return
  end

  -- We are at an edge if we have reached this point.
  -- Allow the user to roll their own edge handling.
  local moved_in_custom_fn = custom_fn_move_cursor(direction)
  if moved_in_custom_fn then
    return
  end

  local moved_in_multiplexer = multiplexer_move_cursor(direction)
  if moved_in_multiplexer then
    return
  end

  -- We have reached an inescapable edge. Nothing more to do.
  if config.at_edge == AtEdgeBehavior.stop then
    return
  end

  if config.at_edge == AtEdgeBehavior.wrap then
    nvim_wrap_cursor(direction)
    return
  end

  if config.at_edge == AtEdgeBehavior.split then
    local did_split = multiplexer_split_and_focus(direction)
    if not did_split then
      nvim_split_and_focus(direction)
    end
  end
end

---@param direction SmartSplitsDirection
---@param opts table
function M.move_cursor_old(direction, opts)
  local at_edge = config.at_edge
  local same_row = config.move_cursor_same_row

  local dir_key = DirectionKeys[direction]
  local offset = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]

  if utils.is_embedded_floating_window() then
    if utils.is_floating_window_at_screen_edge(nil, direction) then
      mux.move_pane(direction, true, at_edge)
      return
    end
    vim.cmd('wincmd ' .. dir_key)
    if (direction == Direction.left or direction == Direction.right) and same_row then
      offset = offset - vim.api.nvim_win_get_position(0)[1]
      vim.cmd('normal! ' .. offset .. 'H')
    end
    return
  end

  if win.handle_floating_window(function()
    mux.move_pane(direction, true, at_edge)
  end) then
    return
  end

  -- are we at an edge and attempting to move in the direction of the edge we're already at?
  local win_to_move_to = vim.fn.winnr(vim.v.count1 .. dir_key)
  local win_before = vim.v.count1 == 1 and vim.fn.winnr() or vim.fn.winnr(vim.v.count1 - 1 .. dir_key)
  local will_wrap = win_to_move_to == win_before

  if will_wrap then
    -- if we can move with mux, then we're good
    if mux.move_pane(direction, will_wrap, at_edge) then
      return
    end

    -- otherwise check at_edge behavior
    if type(at_edge) == 'function' then
      local ctx = { ---@type SmartSplitsContext
        mux = mux.get(),
        direction = direction,
        split = function()
          nvim_split_and_focus(direction)
        end,
        wrap = function()
          win.next_win_or_wrap(will_wrap, DirectionKeysReverse[direction])
        end,
      }
      at_edge(ctx)
      return
    elseif at_edge == AtEdgeBehavior.stop then
      return
    elseif at_edge == AtEdgeBehavior.split then
      -- if at_edge = 'split' and we're in an ignored buffer, just stop
      if
        vim.tbl_contains(config.ignored_buftypes, vim.bo.buftype)
        or vim.tbl_contains(config.ignored_filetypes, vim.bo.filetype)
      then
        return
      end

      local did_split = mux.split_pane(direction)
      if not did_split then
        nvim_split_and_focus(direction)
      end
      return
    else -- at_edge == AtEdgeBehavior.wrap
      -- shouldn't wrap if count is > 1
      if vim.v.count1 == 1 then
        dir_key = DirectionKeysReverse[direction]
      end
    end
  end

  win.next_win_or_wrap(will_wrap, dir_key)

  if (direction == Direction.left or direction == Direction.right) and same_row then
    offset = offset - vim.api.nvim_win_get_position(0)[1]
    vim.cmd('normal! ' .. offset .. 'H')
  end
end

return M
