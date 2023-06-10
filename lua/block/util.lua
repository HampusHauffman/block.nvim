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

function M.create_highlights_from_depth(depth, percent)
    vim.defer_fn(function() -- Getting the hl before vim loads throws an error
        local normal_color = api.nvim_get_hl(0, { name = "Normal" })
        local bg           = normal_color.bg
        local hex_color    = string.format("#%06X", bg)
        M.hl(0, hex_color)
        for i = 1, depth do
            M.hl(i, darken_hex_color(hex_color, percent))
        end
    end, 0)
end

return M
