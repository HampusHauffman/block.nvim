local M       = {}

local api     = vim.api

---@class Block.Config
local options = {
    percent = 0.8,
    depth = 3,
}


function M.setup(opts)
    opts = vim.tbl_deep_extend("force", M.defaults, opts or {})
    M.options = opts
    require("block.util").create_hl(opts.depth, opts.start_color)

    local b = require("block.block")
    api.nvim_create_user_command("BlockToggle", b.toggle)
    api.nvim_create_user_command("BlockOn", b.on)
    api.nvim_create_user_command("BlockOff", b.off)
end

return M
