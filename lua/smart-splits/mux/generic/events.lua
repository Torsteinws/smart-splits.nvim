local M = {} ---@diagnostic disable-line: missing-fields

--- @class GenericMuxEventArg
--- @field on_enter_nvim? fun():nil
--- @field on_exit_nvim? fun():nil
--- @field on_nvim_layout_updated? fun():nil

--- Registers callbacks for useful nvim events.
--- @param subscriber GenericMuxEventArg The callbacks to register.
function M.register(subscriber)
  if subscriber.on_enter_nvim then
    vim.api.nvim_create_autocmd('VimResume', {
      callback = subscriber.on_enter_nvim,
    })
  end
  if subscriber.on_exit_nvim then
    vim.api.nvim_create_autocmd({ 'VimSuspend', 'VimLeavePre' }, {
      callback = subscriber.on_exit_nvim,
    })
  end
  if subscriber.on_nvim_layout_updated then
    vim.api.nvim_create_autocmd({ 'VimResume', 'VimEnter', 'VimResized', 'FocusGained' }, {
      callback = subscriber.on_nvim_layout_updated,
    })
  end
end

return M
