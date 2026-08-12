local lazy = require('smart-splits.lazy')
--- @module 'smart-splits.config'
local config = lazy.require_on_index('smart-splits.config')

local M = {}

--- Check if we are allowed to use multiplexer integrations
--- @return boolean True if we are allowed to use multiplexer integration, otherwise false
function M.is_mux_allowed()
  if
    config.multiplexer_integration == nil
    or config.multiplexer_integration == false
    or #tostring(config.multiplexer_integration or '') == 0
  then
    return false
  end

  if M.are_we_gui() then
    return false
  end

  return true
end

function M.are_we_tmux()
  if M.are_we_gui() then
    return false
  end

  local term = vim.trim((vim.env.TERM_PROGRAM or ''):lower())
  return term == 'tmux'
end

function M.are_we_wezterm()
  if M.are_we_gui() then
    return false
  end

  local term = vim.trim((vim.env.TERM_PROGRAM or ''):lower())
  return term == 'wezterm'
end

function M.are_we_kitty()
  if M.are_we_gui() then
    return false
  end

  return vim.env.KITTY_LISTEN_ON ~= nil
end

function M.are_we_herdr()
  if M.are_we_gui() then
    return false
  end

  return vim.env.HERDR_ENV ~= nil and vim.env.HERDR_ENV ~= ''
end

function M.are_we_zellij()
  if M.are_we_gui() then
    return false
  end

  return vim.env.ZELLIJ ~= nil
end

--- Check if we're in WSL
---@return boolean
function M.are_we_WSL()
  return vim.env.WSL_DISTRO_NAME ~= nil and vim.env.WSL_DISTRO_NAME ~= ''
end

---Check if Neovim is running in a GUI (rather than TUI)
---@return boolean
function M.are_we_gui()
  -- if running in a GUI instead of terminal TUI, disable mux
  -- because you aren't in any terminal, you're in a Neovim GUI
  local current_ui = vim.tbl_filter(function(ui)
    return ui.chan == 1
  end, vim.api.nvim_list_uis())[1]
  return current_ui ~= nil and not current_ui.stdin_tty and not current_ui.stdout_tty
end

--- Tries to locate the WezTerm executable in the system `PATH`.
--- @return 'wezterm.exe'|'org.wezfurlong.wezterm'|'wezterm' executable The resolved executable name, defaulting to `'wezterm'` if no alternative is found.
function M.try_find_wezterm()
  -- Windows path
  if vim.fn.executable('wezterm.exe') == 1 then
    return 'wezterm.exe'
  end

  -- Flatpak path
  if vim.fn.executable('org.wezfurlong.wezterm') == 1 then
    return 'org.wezfurlong.wezterm'
  end

  -- Default value
  return 'wezterm'
end

return M
