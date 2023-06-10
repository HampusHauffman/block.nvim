local M       = {}

local options = {
    percent = 0.8,
    depth = 3,
}

function M.setup(opts)
    print("HELLO")
end

return setmetatable(M, {
    __index = function(_, k)
        return require("block.block")[k]
    end,
})
