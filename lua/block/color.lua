local M = {}
function M.darken_hex_color(hex_color)
    -- Remove the '#' symbol if present
    hex_color = hex_color:gsub("#", "")

    -- Convert the hexadecimal color to RGB
    local r = tonumber(hex_color:sub(1, 2), 16)
    local g = tonumber(hex_color:sub(3, 4), 16)
    local b = tonumber(hex_color:sub(5, 6), 16)

    -- Darken the color by 2%
    local darken_amount = 0.98
    r = math.floor(r * darken_amount)
    g = math.floor(g * darken_amount)
    b = math.floor(b * darken_amount)

    -- Convert the darkened RGB values back to hexadecimal
    local darkened_hex_color = string.format("#%02X%02X%02X", r, g, b)

    return darkened_hex_color
end

return M
