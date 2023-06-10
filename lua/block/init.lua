local M = {}
local util = require("block.util")
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
        M.options.depth = #M.options.colors-1
        for i, c in ipairs(M.options.colors) do
            util.hl(i, c)
        end
    else
        util.create_highlights_from_depth(M.options.depth)
    end

    vim.api.nvim_create_user_command('Block', require("block").toggle, {})
    vim.api.nvim_create_user_command('BlockOn', require("block").on, {})
    vim.api.nvim_create_user_command('BlockOff', require("block").off, {})
end

return setmetatable(M, {
    __index = function(_, k)
        return require("block.block")[k]
    end,
})
