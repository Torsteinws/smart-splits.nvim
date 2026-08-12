local mux_utils = require('smart-splits.mux.utils')

local M = {}

local setup_complete = false
function M.setup()
  if setup_complete then
    return
  end

  if not mux_utils.is_mux_allowed() then
    return
  end

  setup_complete = true
end

return M
