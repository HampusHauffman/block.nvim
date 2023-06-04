local M = {}

function darken_hex_color(hex_color)
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

---@class MTSNode
---@field children MTSNode[]
---@field start_row integer
---@field end_row integer
---@field start_col integer
---@field end_col integer
---@field color integer
---@field pad integer
---@field parent MTSNode | nil
local MTSNode      = {}

local parsers      = require('nvim-treesitter.parsers')

--- @type table<integer,{lang:string, parser:LanguageTree}>
local buffers      = {}
local api          = vim.api
local ts           = vim.treesitter
local ns_id        = vim.api.nvim_create_namespace('bloc')
local colors       = {}

local normal_color = api.nvim_get_hl(0, { name = "Normal" })
local bg           = normal_color.bg
local fg           = normal_color.fg
local bg1          = darken_hex_color(bg)
local bg2          = darken_hex_color(bg1)
local bg3          = darken_hex_color(bg2)
vim.cmd('highlight Bloc0 guibg='..bg1)
vim.cmd('highlight Bloc1 guibg='..bg2)
vim.cmd('highlight Bloc2 guibg='..bg3)

---@param lines string[]
local function find_biggest_end_col(lines)
    local max = 0
    for _, i in ipairs(lines) do
        max = math.max(max, #i)
    end
    return max
end

-- Define the ModifiedTSNode class
---@param ts_node TSNode
---@param color integer
---@param lines string[]
---@param prev_start_row integer
---@param prev_start_col integer
---@param parent MTSNode | nil
---@return MTSNode
local function convert_ts_node(ts_node, color, lines, prev_start_row, prev_start_col, parent)
    local start_row, start_col, end_row, _ = ts_node:range()
    local node_lines = { table.unpack(lines, start_row + 1, end_row + 1) }
    local max_col = find_biggest_end_col(node_lines)
    local mts_node = {
        children = {},
        start_row = start_row,
        end_row = end_row,
        start_col = start_col,
        end_col = max_col,
        color = color,
        pad = 0,
        parent = parent,
    }
    local back = start_row == prev_start_row or ts_node:type() == "block" or ts_node:type() == "arguments"
    if back then
        mts_node.start_col = prev_start_col
        mts_node.color = color - 1
    end
    local max_child_col = mts_node.end_col + mts_node.pad
    for c in ts_node:iter_children() do
        local child_mts = convert_ts_node(c, mts_node.color + 1, lines, mts_node.start_row, mts_node.start_col, mts_node)
        if child_mts.start_row ~= child_mts.end_row then -- Only adds multiline children (chan be done better)
            table.insert(mts_node.children, child_mts)

            mts_node.pad = math.max(mts_node.pad, child_mts.pad)
            max_child_col = math.max(max_child_col, child_mts.end_col + child_mts.pad)
        end
    end
    if max_child_col >= mts_node.end_col + mts_node.pad and not back then
        mts_node.pad = mts_node.pad + 2
    end
    return mts_node
end

-- a func called tab_to_space that converts each tab to tabstop amount of spaces
---@param mts_node MTSNode
local function color_mts_node(mts_node, lines)
    for row = mts_node.start_row, math.min(#lines - 1, mts_node.end_row) do
        local str_len = string.len(lines[row + 1])
        vim.api.nvim_buf_set_extmark(0, ns_id, row, 0, {
            virt_text = { { string.rep(" ", mts_node.end_col - str_len + mts_node.pad),
                "bloc" .. mts_node.color % 3 } },
            virt_text_win_col = str_len,
            priority = 100 + mts_node.color,
        })
        local l = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
        if (#l > mts_node.start_col) then
            vim.api.nvim_buf_set_extmark(0, ns_id, row, mts_node.start_col, {
                end_col = #l,
                hl_group = "bloc" .. mts_node.color % 3,
                priority = 100 + mts_node.color,
            })
        end

        local expandtab = vim.bo.expandtab
        local a = 1
        if not expandtab then
            a = vim.lsp.util.get_effective_tabstop()
        end
        if string.len(lines[row + 1]) == 0 then
            if mts_node.parent ~= nil then
                vim.api.nvim_buf_set_extmark(0, ns_id, row, 0, {
                    virt_text = {
                        { string.rep(" ",
                            (mts_node.start_col - mts_node.parent.start_col) * a),
                            "bloc" .. mts_node.parent.color % 3 } },
                    virt_text_win_col = mts_node.parent.start_col * a,
                    priority = 201 - mts_node.color,
                })
            end
        end
    end
    for _, child in ipairs(mts_node.children) do
        color_mts_node(child, lines)
    end
end

---@param bufnr integer
local function update(bufnr)
    local lang_tree = buffers[bufnr].parser
    local trees = lang_tree:trees()
    local ts_node = trees[1]:root()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    for i, line in ipairs(lines) do
        local spaces = string.rep(" ", vim.lsp.util.get_effective_tabstop()) -- Spaces equivalent to one tab
        local converted_line = string.gsub(line, "\t", spaces)
        lines[i] = converted_line
    end
    vim.api.nvim_buf_clear_namespace(0, ns_id, 0, #lines)
    local l = convert_ts_node(ts_node, 0, lines, -1, -1)
    color_mts_node(l, lines)
end


---Update the parser for a buffer.
local function add_buff_and_start(bufnr)
    local lang = parsers.get_buf_lang(bufnr)
    local parser = ts.get_parser(bufnr, lang)
    buffers[bufnr] = { lang = lang, parser = parser }
    update(bufnr)
    parser:register_cbs({
        on_changedtree = function()
            update(bufnr)
            vim.defer_fn(function()
                update(bufnr)
            end, 0)
        end
    })
end

function M.on()
    local bufnr = api.nvim_get_current_buf()
    if not buffers[bufnr] then
        add_buff_and_start(bufnr)
    end
end

function M.off()
    local bufnr = api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    if buffers[bufnr] then
        local parser = buffers[bufnr].parser
        parser:register_cbs({}) -- Remove all callbacks by registering an empty table
        buffers[bufnr] = nil
    end
end

function M.toggle()
    local bufnr = api.nvim_get_current_buf()
    if buffers[bufnr] then
        M.off()
    else
        M.on()
    end
end

return M
