local M   = {}

M.options = {
    percent = 0.8,
    depth = 3,
}

function M.setup(opts)
    print("HELLO")
    M.options = vim.tbl_deep_extend("force", M.options, opts or {})
    require("block.util").create_hl(M.options.depth, M.options.start_color)
end

return setmetatable(M, {
    __index = function(_, k)
        return require("block.block")[k]
    end,
})
