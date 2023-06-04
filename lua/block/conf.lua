local M = {}


M.options = {}
M.loaded = false
local defaults = {
    colors = {
        "#2f303d",
        "#2b2c38",
        "#272833"
    }
}
M._options = nil

function M.setup(options)
    M._options = options
    if vim.api.nvim_get_vvar("vim_did_enter") == 0 then
        vim.defer_fn(function()
            print("vim_did_enter")

            M._setup()
        end, 0)
    else
        M._setup()
    end
end

return M
