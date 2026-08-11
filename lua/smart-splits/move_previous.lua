--- @type number|nil
local prev_win = nil

vim.api.nvim_create_autocmd('WinLeave', {
  callback = function()
    prev_win = tonumber(vim.api.nvim_get_current_win())
  end,
})

local M = {}

function M.move_cursor_previous()
  if prev_win and vim.api.nvim_win_is_valid(prev_win) then
    vim.api.nvim_set_current_win(prev_win)
  end
end

return M
