local M = {}

--- @class BlockIndentConfig
--- @field priority integer
--- @field enabled boolean
--- @field hl string|string[]

--- @class BlockConfig
--- @field indent BlockIndentConfig
--- @field filter fun(buf: integer): boolean

M.enabled = true

local defaults = {
  indent = {
    priority = 1,
    enabled = true,
    hl = "Block",
  },
  filter = function(buf)
    return vim.g.block_indent ~= false
      and vim.b[buf].block_indent ~= false
      and vim.bo[buf].buftype == ""
  end,
}

local config = defaults
local ns = vim.api.nvim_create_namespace("block")

--- @class BlockRange
--- @field start integer
--- @field stop integer
--- @field indent integer
--- @field max_col integer

local block_cache = {} --- @type table<integer, BlockRange[]>

local function get_block_hl(indent, shiftwidth)
  local level_index = math.floor(indent / shiftwidth) % 4
  return "Block" .. level_index
end

local function get_indent_blocks(lines, top)
  local stack = {}
  local result = {}

  for i, line in ipairs(lines) do
    local lnum = top + i - 1
    local indent = vim.fn.indent(lnum + 1)
    local len = #line

    if not line:match("^%s*$") then
      while #stack > 0 and indent < stack[#stack].indent do
        local block = table.remove(stack)
        block.stop = lnum - 1
        table.insert(result, block)
      end

      table.insert(stack, {
        start = lnum,
        stop = lnum,
        indent = indent,
        max_col = len,
      })
    end

    for _, block in ipairs(stack) do
      block.max_col = math.max(block.max_col, len)
    end
  end

  for _, block in ipairs(stack) do
    block.stop = top + #lines - 1
    table.insert(result, block)
  end

  return result
end

local function compute_all_blocks(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  block_cache[buf] = get_indent_blocks(lines, 0)
end

local function set_virtual_highlight(
  buf,
  lnum,
  col,
  padding_len,
  indent,
  shiftwidth,
  hl_base
)
  if padding_len <= 0 then
    return
  end

  local line = vim.fn.getline(lnum + 1)
  local is_blank = line:match("^%s*$")

  local hl = hl_base or get_block_hl(indent, shiftwidth)
  local priority = config.indent.priority + math.floor(indent / shiftwidth)

  local virt_text = {}

  if is_blank then
    col = 0
    table.insert(virt_text, { string.rep(" ", indent), nil })
    table.insert(virt_text, { string.rep(" ", padding_len), hl })
  else
    table.insert(virt_text, { string.rep(" ", padding_len), hl })
  end

  vim.api.nvim_buf_set_extmark(buf, ns, lnum, col, {
    virt_text = virt_text,
    virt_text_pos = "overlay",
    hl_mode = "combine",
    ephemeral = true,
    priority = priority,
    strict = false,
  })
end

local function draw_blocks(_, buf, top, bottom)
  local shiftwidth = vim.bo[buf].shiftwidth > 0 and vim.bo[buf].shiftwidth
    or vim.bo[buf].tabstop
  local blocks = block_cache[buf]
  if not blocks then
    return
  end

  vim.api.nvim_buf_call(buf, function()
    table.sort(blocks, function(a, b)
      return a.indent > b.indent
    end)

    for _, block in ipairs(blocks) do
      local start_lnum = math.max(block.start, top)
      local stop_lnum = math.min(block.stop, bottom - 1)
      local hl = get_block_hl(block.indent, shiftwidth)
      local priority = config.indent.priority
        + math.floor(block.indent / shiftwidth)

      for lnum = start_lnum, stop_lnum do
        local line = vim.fn.getline(lnum + 1)
        local line_len = #line
        local virt_start = math.max(block.indent, line_len)
        local padding_len = block.max_col - virt_start

        -- Highlight the actual content range if it exists
        if line_len > block.indent then
          vim.api.nvim_buf_set_extmark(buf, ns, lnum, block.indent, {
            end_col = line_len,
            hl_group = hl,
            hl_mode = "combine",
            ephemeral = true,
            priority = priority,
            strict = false,
          })
        end

        -- Virtual highlight to visually fill space to max_col
        local virt_col = line:match("^%s*$") and block.indent or virt_start
        set_virtual_highlight(
          buf,
          lnum,
          virt_col,
          padding_len,
          block.indent,
          shiftwidth,
          hl
        )
      end
    end
  end)
end

function M.enable()
  M.enabled = true
  vim.print("block.nvim: enabled")

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and config.filter(buf) then
      compute_all_blocks(buf)
    end
  end

  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, win, buf, top, bottom)
      if M.enabled and config.filter(buf) then
        draw_blocks(win, buf, top, bottom)
      end
    end,
  })

  vim.api.nvim_create_autocmd(
    { "BufWritePost", "TextChanged", "TextChangedI", "InsertLeave" },
    {
      group = vim.api.nvim_create_augroup(
        "block.nvim.redraw",
        { clear = true }
      ),
      callback = function(args)
        if config.filter(args.buf) then
          compute_all_blocks(args.buf)
        end
      end,
    }
  )
end

function M.disable()
  M.enabled = false
  vim.print("block.nvim: disabled")

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
  end

  block_cache = {}
  vim.api.nvim_set_decoration_provider(ns, {})
end

vim.api.nvim_create_user_command("BlockTestVirtText", function()
  local buf = vim.api.nvim_get_current_buf()
  local ns = vim.api.nvim_create_namespace("block-test")
  local lnum = 0 -- top line of the buffer
  local indent = 6
  local padding_len = 20
  local filler = string.rep("a", padding_len)
  local hl = "Block1"
  local priority = 1000

  -- Make sure the line exists and is empty
  vim.api.nvim_buf_set_lines(buf, lnum, lnum + 1, false, { "" })

  -- Place virt_text at indent
  vim.api.nvim_buf_set_extmark(buf, ns, lnum, indent, {
    virt_text = { { filler, hl } },
    virt_text_pos = "overlay",
    hl_mode = "combine",
    ephemeral = false,
    priority = priority,
    strict = false,
  })

  vim.notify("Placed test virt_text at indent " .. indent)
end, {})
return M
