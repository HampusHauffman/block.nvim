local M           = {}

--- @type table<integer,{parser:LanguageTree, tabstop: integer, matchpairs: string}>
local buffers     = {}
local api         = vim.api
local ts          = vim.treesitter
local ns_id       = vim.api.nvim_create_namespace('block')
local nest_amount = require("block").options.depth

---@param lines string[]
local function find_biggest_end_col(lines)
    local max = 0
    for _, i in ipairs(lines) do
        max = math.max(max, vim.fn.strdisplaywidth(i))
    end
    return max
end

---@param start_row integer The first row
---@param start_col integer The start column
---@param end_row integer The final row to go to
---@param end_col integer the column to witch all highligts must reach
---@param iteration integer How deep we are in the recursive cycle
local function color_node(bufnr, start_row, start_col, end_row, end_col, iteration)
    for i = start_row, end_row do
        api.nvim_buf_add_highlight(bufnr, ns_id, "Block" .. iteration % nest_amount, i, start_col, end_col)
        -- Highlight that comes after the end of the line
        local l = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
        local l_len = vim.fn.strdisplaywidth(l)
        if (l == nil) then goto continue end -- AH YES THE FORBIDDEN FRUIT TODO fix this. Seems
        if (#l > 0) then
            api.nvim_buf_set_extmark(bufnr, ns_id, i, 0, {
                virt_text = {
                    { string.rep(" ", end_col - l_len),
                        "Block" .. iteration % nest_amount
                    }
                },
                virt_text_win_col = l_len,
                priority = 100 + iteration
            })
        else
            -- Highlight the empty lines
            api.nvim_buf_set_extmark(bufnr, ns_id, i, 0, {
                virt_text = {
                    { string.rep(" ", end_col - start_col),
                        "Block" .. iteration % nest_amount } },
                virt_text_win_col = start_col * buffers[bufnr].tabstop,
                priority = 100 + iteration
            })
        end

        ::continue::
    end
end

---Highlight all the nodes under the input node
---@param bufnr integer
---@param node TSNode the node currently at
---@param iteration integer How deep we are in the recursive cycle
---@param prev_start_row integer
---@param prev_start_col integer
---@param prev_end_row integer
---@return integer largest_col
local function block(bufnr, node, iteration, prev_start_row, prev_start_col, prev_end_row)
    -- The largest col nr
    local largest_col = 0

    -- Get the range of the node
    local start_row, start_col, end_row, end_col = node:range()

    -- Use the parent starting and end position if its on the same line
    local unwanted_types = node:type() == "arguments" or node:type() == "block"
    local same_start_row = start_row == prev_start_row
    local same_start_col = start_col == prev_start_col
    local same_end_row = end_row == prev_end_row
    local start_and_end_col_dont_match = start_col - end_col > 2
    if unwanted_types or same_start_row or same_start_col or same_end_row or start_and_end_col_dont_match then
        iteration = iteration - 1
        start_row = prev_start_row
        start_col = prev_start_col
        end_row = prev_end_row
    end

    -- Get all the lines for node
    local lines = api.nvim_buf_get_lines(bufnr, start_row, end_row, true)
    local longest_line = find_biggest_end_col(lines)

    -- Update longest_col to the biggest out of all children or longest line
    largest_col = math.max(largest_col, longest_line)

    -- If the node is only one line then return the this line
    if start_row == end_row then
        return longest_line + 1
    end

    -- Go into child node unless no children are found
    for child_node in node:iter_children() do
        local child_largest_col = block(bufnr, child_node, iteration + 1, start_row, start_col, end_row)

        -- Update largest end col
        largest_col = math.max(largest_col, child_largest_col)
    end

    -- print all the data for the node: Start, End, and width (end col)
    -- print(string.format("start_row: %d, start_col %d, largest_end_col %d, end_row: %d, iteration: %d, type: %s", start_row, start_col, largest_col, end_row, iteration, node:type()))

    color_node(bufnr, start_row, start_col, end_row, largest_col, iteration)
    return largest_col + 1
end


---@param bufnr integer
local function update(bufnr)
    --unfortunate bug. It seems register_cbs({}) wont unregister callbacks in v > 10 so this just checks that. no performace degredation should occur.
    if buffers[bufnr] == nil then return end

    local lang_tree = buffers[bufnr].parser
    local trees = lang_tree:trees()
    if #trees == 0 then return end -- Seems an already Blocked buffer might result in this returning nil-- Seems an already Blocked buffer might result in this returning nil
    local ts_node = trees[1]:root()

    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    for c in ts_node:iter_children() do
        block(bufnr, c, nest_amount + 1, -1, -1, -1)
    end
end

---Update the parser for a buffer.
local function add_buff_and_start(bufnr)
    local success, parser = pcall(ts.get_parser, bufnr)
    if (success) then
        buffers[bufnr] = {}
        buffers[bufnr].parser = parser

        -- Add the tabstop to the buffer
        local expandtab = vim.bo[bufnr].expandtab
        local a = 1
        if not expandtab then
            a = vim.lsp.util.get_effective_tabstop(bufnr)
        end
        buffers[bufnr].tabstop = a


        -- set matchpairs to empty string to avoid conflicts with treesitter
        buffers[bufnr].matchpairs = vim.bo[bufnr].matchpairs
        vim.bo[bufnr].matchpairs = ""

        -- Initialize the buffer and update it
        vim.print(buffers[bufnr].tabstop)
        vim.schedule(function()
            update(bufnr)
        end)
        -- Autocommand that checks the
        parser:register_cbs({
            on_changedtree = function()
                vim.schedule(function()
                    update(bufnr)
                end)
            end
        }, false)
    end
end


function M.on()
    local bufnr = api.nvim_get_current_buf()
    -- If the buffer isnt in the list of buffers then add it and run
    if not buffers[bufnr] then
        add_buff_and_start(bufnr)
    end
end

function M.off()
    local bufnr = api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    if buffers[bufnr] then
        buffers[bufnr].parser:register_cbs({ on_changedtree = function() end }) -- Register an empty function to remove the previous callback
        vim.bo.matchpairs = buffers[bufnr].matchpairs
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
