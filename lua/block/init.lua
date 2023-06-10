local M = {}
local util = require("block.util")
local block = require("block")
---@class Opts
---@field percent number  -- The change in color. 0.8 would change each box to be 20% darker than the last and 1.2 would be 20% brighter
---@field depth number -- De depths of changing colors. Defaults to 3
---@field colors string [] | nil -- A list of colors to use instead. if this is not nil depth and percent are not used


M.options = {
    percent = 0.8,
    depth = 3,
}

---@param opts Opts
function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.options, opts or {})
    if (M.options.colors) then
        for i, c in ipairs(M.options.colors) do
            util.hl(i, c)
        end
    else
        util.create_highlights_from_depth(M.options.depth)
    end

    vim.api.nvim_create_user_command('Block', M.block.toggle, {})
    vim.api.nvim_create_user_command('BlockOn', M.block.on, {})
    vim.api.nvim_create_user_command('BlockOff', M.block.off, {})
end

return setmetatable(M, {
    __index = function(_, k)
        return require("block.block")[k]
    end,
})
