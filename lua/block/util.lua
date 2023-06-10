local M   = {}
local api = vim.api

local function darken_hex_color(hex_color)
    -- Remove the '#' symbol if present
    hex_color = hex_color:gsub("#", "")

    -- Convert the hexadecimal color to RGB
    local r = tonumber(hex_color:sub(1, 2), 16)
    local g = tonumber(hex_color:sub(3, 4), 16)
    local b = tonumber(hex_color:sub(5, 6), 16)

    local darken_amount = 0.90
    r = math.floor(r * darken_amount)
    g = math.floor(g * darken_amount)
    b = math.floor(b * darken_amount)

    -- Convert the darkened RGB values back to hexadecimal
    local darkened_hex_color = string.format("#%02X%02X%02X", r, g, b)

    return darkened_hex_color
end

function M.create_hl(depth, start_color)
    local normal_color = api.nvim_get_hl(0, { name = "Normal" })
    local bg           = normal_color.bg
    local hex_color    = string.format("#%06X", bg)
    vim.cmd('highlight Bloc' .. 0 .. ' guibg=' .. hex_color)
    for i = 1, depth do
        hex_color = darken_hex_color(hex_color)
        vim.cmd('highlight Bloc' .. i .. ' guibg=' .. hex_color)
    end
end

return M
