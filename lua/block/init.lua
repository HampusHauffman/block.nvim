local M   = {}

M.options = {
    percent = 0.8,
    depth = 3,
}

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.options, opts or {})
    require("block.util").create_hl(3)
    vim.api.nvim_create_user_command('BlockToggle', require("block").toggle,{})
end

return setmetatable(M, {
    __index = function(_, k)
        return require("block.block")[k]
    end,
})
