local M = {}

--- @type table<integer,{parser:LanguageTree, matchpairs: string, change_tick: integer}>
local buffers = {}
local api = vim.api
local ts = vim.treesitter
local ns_id = api.nvim_create_namespace("block")
local nest_amount = require("block").options.depth

---@param bufnr integer
---@return table<integer>
local function lines_width(bufnr)
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, true)
  local lines_with_width = {}
  for i, v in ipairs(lines) do
    lines_with_width[i] = vim.fn.strdisplaywidth(v)
  end
  return lines_with_width
end

local function color_node(
  bufnr,
  start_row,
  start_col,
  end_row,
  end_col,
  iteration
)
  local tabstop = vim.bo[bufnr].tabstop

  for i = start_row, end_row do
    api.nvim_buf_add_highlight(
      bufnr,
      ns_id,
      "Block" .. iteration % nest_amount,
      i,
      start_col,
      end_col
    )

    local l = api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
    if l == nil then
      goto continue
    end

    local l_len = vim.fn.strdisplaywidth(l)
    local virt_text_win_col = l_len

    if #l > 0 then
      api.nvim_buf_set_extmark(bufnr, ns_id, i, 0, {
        virt_text = {
          {
            string.rep(" ", end_col - l_len),
            "Block" .. iteration % nest_amount,
          },
        },
        virt_text_win_col = virt_text_win_col,
        priority = 100 + iteration,
      })
    else
      local actual_start_col = start_col
      if indent_type == "tabs" then
        actual_start_col = start_col * tabstop
      end
      api.nvim_buf_set_extmark(bufnr, ns_id, i, 0, {
        virt_text = {
          {
            string.rep(" ", end_col - actual_start_col),
            "Block" .. iteration % nest_amount,
          },
        },
        virt_text_win_col = actual_start_col,
        priority = 100 + iteration,
      })
    end

    ::continue::
  end
end

---@param bufnr integer
---@param node TSNode
---@param iteration integer
---@param prev_start_row integer
---@param prev_start_col integer
---@param prev_end_row integer
---@param lines table<integer>
---@return integer
local function block(
  bufnr,
  node,
  iteration,
  prev_start_row,
  prev_start_col,
  prev_end_row,
  lines
)
  local largest_col = 0
  local start_row, start_col, end_row, end_col = node:range()

  local unwanted_types = node:type() == "arguments" or node:type() == "block"
  local same_start_row = start_row == prev_start_row
  local same_start_col = start_col == prev_start_col
  local same_end_row = end_row == prev_end_row
  local start_and_end_col_dont_match = start_col - end_col > 1

  if
    unwanted_types
    or same_start_row
    or same_start_col
    or same_end_row
    or start_and_end_col_dont_match
  then
    iteration = iteration - 1
    start_row = prev_start_row
    start_col = prev_start_col
    end_row = prev_end_row
  end

  local node_lines = unpack(lines, start_row + 1, end_row + 1)
  local longest_line = math.max(node_lines)

  largest_col = math.max(largest_col, longest_line)

  if start_row == end_row then
    return longest_line + 1
  end

  for child_node in node:iter_children() do
    local child_largest_col = block(
      bufnr,
      child_node,
      iteration + 1,
      start_row,
      start_col,
      end_row,
      lines
    )
    largest_col = math.max(largest_col, child_largest_col)
  end

  color_node(bufnr, start_row, start_col, end_row, largest_col, iteration)
  return largest_col + 1
end

---@param bufnr integer
local function update(bufnr)
  if buffers[bufnr] == nil then
    return
  end

  local lang_tree = buffers[bufnr].parser
  local trees = lang_tree:trees()
  if #trees == 0 then
    return
  end

  local ts_node = trees[1]:root()
  local lines = lines_width(bufnr)

  api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  for c in ts_node:iter_children() do
    block(bufnr, c, nest_amount + 1, -1, -1, -1, lines)
  end
end

local function add_buff_and_start()
  vim.schedule(function()
    local bufnr = api.nvim_get_current_buf()

    if not buffers[bufnr] then
      buffers[bufnr] = {}
    end

    local success, parser = pcall(ts.get_parser, bufnr)
    if success then
      buffers[bufnr].parser = parser
      buffers[bufnr].matchpairs = vim.bo[bufnr].matchpairs
      vim.bo[bufnr].matchpairs = ""

      update(bufnr)

      parser:register_cbs({
        on_changedtree = function()
          vim.schedule(function()
            update(bufnr)
          end)
        end,
      }, false)
    end
  end)
end

function M.on()
  add_buff_and_start()
end

function M.off()
  local bufnr = api.nvim_get_current_buf()
  api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  if buffers[bufnr] then
    buffers[bufnr].parser:register_cbs({ on_changedtree = function() end })
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
