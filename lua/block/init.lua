local M = {}

local core = require("block.block")
local util = require("block.util")

--- Setup the plugin
function M.setup()
  vim.api.nvim_create_augroup("block.nvim", { clear = true })

  -- Hardcoded depth and colors for MVP

  local colors = {
    "#1a1a2e", -- Block0: deep navy
    "#2f1a2e", -- Block1: deep burgundy
    "#1a2e1a", -- Block2: dark forest green
    "#2e261a", -- Block3: warm brown/bronze
  }

  for i, c in ipairs(colors) do
    util.hl(i - 1, c)
  end

  vim.api.nvim_create_user_command("BlockOn", core.enable, {})
  vim.api.nvim_create_user_command("BlockOff", core.disable, {})
end

return M
