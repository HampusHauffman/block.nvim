--- @class BlockIndentConfig
--- @field priority integer
--- @field enabled boolean
--- @field char string
--- @field hl string|string[]

--- @class BlockConfig
--- @field indent BlockIndentConfig
--- @field filter fun(buf: integer): boolean

local M = {}

--- Whether block highlighting is currently enabled
--- @type boolean
M.enabled = true

--- Default configuration
--- @type BlockConfig
local defaults = {
  indent = {
    priority = 1,
    enabled = true,
    char = "│",
    hl = "Block",
  },
  filter = function(buf)
    return vim.g.block_indent ~= false
      and vim.b[buf].block_indent ~= false
      and vim.bo[buf].buftype == ""
  end,
}

--- Active configuration
--- @type BlockConfig
local config = defaults

--- Extmark namespace for block.nvim
--- @type integer
local ns = vim.api.nvim_create_namespace("block")

--- @class BlockRange
--- @field start integer
--- @field stop integer
--- @field indent integer

--- Get the highlight group name for an indent level
--- @param indent integer
--- @param shiftwidth integer
--- @return string
local function get_block_hl(indent, shiftwidth)
  local level = math.floor(indent / shiftwidth)
  return "Block" .. (level % 4)
end

--- Identify block ranges based on indentation
--- @param top integer
--- @return BlockRange[]
local function get_indent_blocks(lines, top)
  ---@type BlockRange[]
  local stack = {}
  ---@type BlockRange[]
  local blocks = {}

  for i, line in ipairs(lines) do
    local lnum = top + i - 1
    local indent = vim.fn.indent(lnum + 1)

    if line:match("^%s*$") then
      goto continue
    end

    while #stack > 0 and indent <= stack[#stack].indent do
      local closed = table.remove(stack)
      closed.stop = lnum - 1
      table.insert(blocks, closed)
    end

    table.insert(stack, { start = lnum, stop = lnum, indent = indent })

    ::continue::
  end

  for _, b in ipairs(stack) do
    b.stop = #lines - 1
    table.insert(blocks, b)
  end

  return blocks
end

--- Render extmarks for block ranges
--- @param win integer
--- @param buf integer
--- @param top integer
--- @param bottom integer
local function draw_blocks(win, buf, top, bottom)
  local shiftwidth = vim.bo[buf].shiftwidth > 0 and vim.bo[buf].shiftwidth
    or vim.bo[buf].tabstop

  -- Get visible lines
  local lines = vim.api.nvim_buf_get_lines(buf, top, bottom, false)
  local blocks = get_indent_blocks(lines, top)

  table.sort(blocks, function(a, b)
    return a.indent < b.indent
  end)

  vim.api.nvim_buf_call(buf, function()
    for _, block in ipairs(blocks) do
      local start = math.max(block.start, top)
      local stop = math.min(block.stop, bottom - 1)
      local level = math.floor(block.indent / shiftwidth)

      for lnum = start, stop do
        local line = vim.fn.getline(lnum + 1)
        if line and #line > block.indent then
          vim.api.nvim_buf_set_extmark(buf, ns, lnum, block.indent, {
            end_col = #line,
            hl_group = get_block_hl(block.indent, shiftwidth),
            hl_mode = "combine",
            ephemeral = true,
            priority = config.indent.priority + level,
          })
        end
      end
    end
  end)
end

--- Enable block rendering
function M.enable()
  M.enabled = true
  vim.print("block.nvim: enabled")

  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, win, buf, top, bottom)
      if M.enabled and config.filter(buf) then
        draw_blocks(win, buf, top, bottom)
      end
    end,
    on_line = function(_, win, buf, line)
      if M.enabled and config.filter(buf) then
        draw_blocks(win, buf, line, line + 1)
      end
    end,
  })
end

--- Disable block rendering
function M.disable()
  M.enabled = false
  vim.print("block.nvim: disabled")

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
  end

  vim.api.nvim_set_decoration_provider(ns, {})
end

return M
