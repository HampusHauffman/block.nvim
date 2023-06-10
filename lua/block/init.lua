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
end

return setmetatable(M, {
    __index = function(_, k)
        return require("block.block")[k]
    end,
})
