local M       = {}

---@class MTSNode
---@field children MTSNode[]
---@field start_row integer
---@field end_row integer
---@field start_col integer
---@field end_col integer
---@field color integer
---@field pad integer
---@field parent MTSNode | nil
local MTSNode = {}


--- @type table<integer,{parser:LanguageTree}>
local buffers     = {}
local api         = vim.api
local ts          = vim.treesitter
local ns_id       = vim.api.nvim_create_namespace('bloc')
local nest_amount = require("block").options.depth

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
    local node_lines = { unpack(lines, start_row + 1, end_row + 1) }
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
        if child_mts.start_row ~= child_mts.end_row then
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
        -- Set the padding at the end of the line
        local str_len = string.len(lines[row + 1])
        vim.api.nvim_buf_set_extmark(0, ns_id, row, 0, {
            virt_text = { { string.rep(" ", mts_node.end_col - str_len + mts_node.pad),
                "bloc" .. mts_node.color % nest_amount } },
            virt_text_win_col = str_len,
            priority = 100 + mts_node.color,
        })

        -- Set the color of the line
        local l = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
        if (#l > mts_node.start_col + 1) then -- Check to make sure we dont draw on empty lines
            vim.api.nvim_buf_set_extmark(0, ns_id, row, mts_node.start_col, {
                end_col = #l,
                hl_group = "bloc" .. mts_node.color % nest_amount,
                virt_text_hide = true,
                priority = 100 + mts_node.color,
            })
        end

        -- Handle empty lines
        local expandtab = vim.bo.expandtab -- TODO: Move this to a better place
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
                            "bloc" .. mts_node.parent.color % nest_amount } },
                    virt_text_win_col = mts_node.parent.start_col * a,
                    virt_text_hide = true,
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
    --unfortunate bug. It seems register_cbs({}) wont unregister callbacks in v > 10 so this just checks that. no performace degredation should occur.
    if buffers[bufnr] == nil then return end

    local lang_tree = buffers[bufnr].parser
    local trees = lang_tree:trees()
    if #trees == 0 then return end
    local ts_node = trees[1]:root()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
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
    local success, parser = pcall(ts.get_parser, bufnr)
    if success then
        buffers[bufnr] = { parser = parser }
        update(bufnr)
        buffers[bufnr].parser:register_cbs({
            on_changedtree = function()
                update(bufnr)
                vim.defer_fn(
                    function() -- HACK: This is a hack to fix the issue of the parser not updating on the first change
                        update(bufnr)
                    end, 0)
            end
        })
    else
        -- Handle the failure case
    end
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
        buffers[bufnr].parser:register_cbs({ on_changedtree = function() end }) -- Register an empty function to remove the previous callback
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
