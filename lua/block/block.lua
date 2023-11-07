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


--- @type table<integer,{parser:LanguageTree,scroll: integer, prev_left_col: integer, mts_node:MTSNode, max_row:integer, min_row:integer}>
local buffers     = {}
local api         = vim.api
local ts          = vim.treesitter
local ns_id       = vim.api.nvim_create_namespace('bloc')
local nest_amount = require("block").options.depth

---@param lines string[]
local function find_biggest_end_col(lines)
    local max = 0
    for _, i in ipairs(lines) do
        max = math.max(max, vim.fn.strdisplaywidth(i))
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
---@param bufnr integer
---@param mts_node MTSNode
local function color_mts_node(bufnr, mts_node, win_start_row, win_end_row)
    if mts_node.start_row > win_end_row or mts_node.end_row < win_start_row then return end
    local offset = vim.fn.winsaveview().leftcol

    for row = mts_node.start_row, mts_node.end_row - 1 do
        local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]
        --print(row)
        --print(line)
        local str_len = vim.fn.strdisplaywidth(line)
        -- Set the padding at the end of the line
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, 0, {
            virt_text = {
                -- end_col + pad - str_len or use offset of we're offset more than str_len
                { string.rep(" ", mts_node.end_col + mts_node.pad - ((offset + 1) <= str_len and str_len or offset)),
                    "bloc" .. mts_node.color % nest_amount } },
            virt_text_win_col = math.max(0, str_len - offset),
            priority = 100 + mts_node.color,
        })

        -- Set the color of the line
        if (#line > mts_node.start_col + 1) then -- Check to make sure we dont draw on empty lines
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, mts_node.start_col, {
                end_col = #line,
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
        if vim.fn.strdisplaywidth(line) == 0 then
            if mts_node.parent ~= nil then
                vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, 0, {
                    virt_text = {
                        { string.rep(" ",
                            (mts_node.start_col - mts_node.parent.start_col) * a),
                            "bloc" .. mts_node.parent.color % nest_amount } },
                    virt_text_win_col = mts_node.parent.start_col * a,
                    virt_text_hide = true,
                    priority = 100 + mts_node.color,
                })
            end
        end
    end
    for _, child in ipairs(mts_node.children) do
        color_mts_node(bufnr, child, win_start_row, win_end_row)
    end
end

---@param bufnr integer
---@param changed boolean
local function update(bufnr, changed)
    --unfortunate bug. It seems register_cbs({}) wont unregister callbacks in v > 10 so this just checks that. no performace degredation should occur.
    if buffers[bufnr] == nil then return end

    local win_id = vim.fn.bufwinid(bufnr)
    local win_start_row = vim.fn.line("w0", win_id)
    local win_end_row = vim.fn.line("w$", win_id)

    local lang_tree = buffers[bufnr].parser
    local trees = lang_tree:tree_for_range({ win_start_row, 0, win_end_row, 0 })
    if trees == nil then return end -- Seems an already Blocked buffer might result in this returning nil
    local ts_node = trees:root()


    if changed then
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
        vim.api.nvim_buf_clear_namespace(0, ns_id, win_start_row, win_end_row)
        local l = convert_ts_node(ts_node, 0, lines, -1, -1)
        buffers[bufnr].mts_node = l
    end
    color_mts_node(bufnr, buffers[bufnr].mts_node, win_start_row, win_end_row)
end

---Update the parser for a buffer.
local function add_buff_and_start(bufnr)
    local success, parser = pcall(ts.get_parser, bufnr)
    if success then
        buffers[bufnr] = {}
        buffers[bufnr].parser = parser
        update(bufnr, true)
        buffers[bufnr].parser:register_cbs({
            on_changedtree = function()
                vim.defer_fn(
                    function() -- HACK: This is a hack to fix the issue of the parser not updating on the first change
                        update(bufnr, true)
                    end, 0)
            end
        })

        -- This might cause a lot of latency and should be improved.
        -- Maybe check if wrap is even off in the first. Also other performance improvemts come before this one
        buffers[bufnr].prev_left_col = vim.fn.winsaveview().leftcol
        buffers[bufnr].scroll =
            vim.api.nvim_create_autocmd('WinScrolled', {
                group = 'block.nvim',
                pattern = string.format('<buffer=%d>', bufnr),
                callback = function(_)
                    if buffers[bufnr].prev_left_col == vim.fn.winsaveview().leftcol then return end -- This is in order to not update unless horizontal scrolled
                    buffers[bufnr].prev_left_col = vim.fn.winsaveview().leftcol
                    update(bufnr, false)
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
        api.nvim_del_autocmd(buffers[bufnr].scroll)
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

function M.ff()
    -- get lang of current file
    local bufnr = api.nvim_get_current_buf()
    local parser = ts.get_parser()
    local query = ts.query.get(parser:lang(), "indents")
    local trees = parser:tree_for_range({ 0, 0, -1, 0 })

    if trees == nil or query == nil then return end -- Seems an already Blocked buffer might result in this returning nil

    local root = trees:root()

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)

    local linelength = {}
    for i, line in ipairs(lines) do
        linelength[i] = vim.fn.strdisplaywidth(line)
    end
    print(vim.inspect(linelength))

    local q = {}
    local d = 0

    for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
        if query then
            local start_row, start_col, end_row, _ = node:range()
            local c = query.captures[id]
            local s = node:start()
            local e = node:end_()
            if c == "indent.end" then d = d - 1 end
            if c == "indent.begin" then
                d = d + 1
                if s ~= e and not q[s] then
                    q[s] = {}
                    q[s].start = s
                    q[s].end_ = e
                    q[s].depth = d
                end
            end
        end
    end
    print(vim.inspect(q))
end

return M
