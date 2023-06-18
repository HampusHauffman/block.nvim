local M   = {}
local api = vim.api

local function darken_hex_color(hex_color, percent)
    -- Remove the '#' symbol if present
    hex_color = hex_color:gsub("#", "")

    -- Convert the hexadecimal color to RGB
    local r = tonumber(hex_color:sub(1, 2), 16)
    local g = tonumber(hex_color:sub(3, 4), 16)
    local b = tonumber(hex_color:sub(5, 6), 16)

    r = math.floor(r * percent)
    g = math.floor(g * percent)
    b = math.floor(b * percent)

    -- Convert the darkened RGB values back to hexadecimal
    local darkened_hex_color = string.format("#%02X%02X%02X", r, g, b)

    return darkened_hex_color
end

function M.hl(i, c)
    vim.cmd('highlight Bloc' .. i .. ' guibg=' .. c)
end

function M.get_bg_color()
    local normal_color = api.nvim_get_hl(0, { name = "Normal" })
    return normal_color.bg and string.format("#%06X", normal_color.bg)
end

function M.create_highlights_from_depth(depth, percent, bg)
    for i = 0, depth do
        M.hl(i, bg)
        bg = darken_hex_color(bg, percent)
    end
end

return M
