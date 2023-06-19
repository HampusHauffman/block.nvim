local M = {}
local util = require("block.util")
---@class Opts
---@field percent number  -- The change in color. 0.8 would change each box to be 20% darker than the last and 1.2 would be 20% brighter.
---@field depth number -- De depths of changing colors. Defaults to 4. After this the colors reset. Note that the first color is taken from your "Normal" highlight so a 4 is 3 new colors.
---@field automatic boolean -- Automatically turns this on when treesitter finds a parser for the current file.
---@field colors string [] | nil -- A list of colors to use instead. If this is set percent and depth are not taken into account.
---@field bg string? -- Set this if block.nvim cannot automatically find your background color.


M.options = {
    percent = 0.8,
    depth = 4,
    automatic = false,
}

---@param opts Opts
function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.options, opts or {})
    if (M.options.colors) then
        M.options.depth = #M.options.colors
        for i, c in ipairs(M.options.colors) do
            util.hl(i - 1, c)
        end
    else
        vim.defer_fn(function() -- Getting the hl before vim loads throws an error
            local bg_color = M.options.bg or util.get_bg_color()
            if bg_color then
                util.create_highlights_from_depth(M.options.depth, M.options.percent, bg_color)
            else
                vim.notify_once(
                    "block.nvim could not find your background color.\n"
                        .. "Either use a colorscheme which sets guibg for Normal, or set `bg` in your block.nvim config.\n"
                        .. "(see the Troubleshooting section of README.md for more details)",
                    vim.log.levels.ERROR
                )
            end
        end, 0)
    end

    if M.options.automatic then
        vim.api.nvim_create_autocmd('FileType', {
            pattern = '*',
            callback = function(args)
                require("block").on()
            end
        })
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
