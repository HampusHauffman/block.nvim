--- @class BlockIndentConfig
--- @field priority integer
--- @field enabled boolean
--- @field hl string|string[]

--- @class BlockConfig
--- @field indent BlockIndentConfig
--- @field filter fun(buf: integer): boolean

local M = {}

--- Whether block highlighting is currently enabled
M.enabled = true

--- Default configuration
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
  local level = math.floor(indent / shiftwidth)
  return "Block" .. (level % 4)
end

local function get_indent_blocks(lines, top)
  ---@type BlockRange[]
  local stack = {}
  ---@type BlockRange[]
  local blocks = {}

  for i, line in ipairs(lines) do
    local lnum = top + i - 1
    local indent = vim.fn.indent(lnum + 1)
    local line_len = #line

    if not line:match("^%s*$") then
      while #stack > 0 and indent < stack[#stack].indent do
        local closed = table.remove(stack)
        closed.stop = lnum - 1
        table.insert(blocks, closed)
      end

      table.insert(stack, {
        start = lnum,
        stop = lnum,
        indent = indent,
        max_col = line_len,
      })
    end

    -- Always update max_col for all open blocks
    for _, b in ipairs(stack) do
      b.max_col = math.max(b.max_col, line_len)
    end
  end

  for _, b in ipairs(stack) do
    b.stop = top + #lines - 1
    table.insert(blocks, b)
  end

  return blocks
end

local function compute_all_blocks(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  block_cache[buf] = get_indent_blocks(lines, 0)
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
      return a.indent < b.indent
    end)

    for _, block in ipairs(blocks) do
      local start = math.max(block.start, top)
      local stop = math.min(block.stop, bottom - 1)
      local hl = get_block_hl(block.indent, shiftwidth)
      local priority = config.indent.priority
        + math.floor(block.indent / shiftwidth)
      local max_len = block.max_col

      for lnum = start, stop do
        local line = vim.fn.getline(lnum + 1)
        local line_len = #line

        -- 1. Highlight actual text, if present
        if line_len > block.indent then
          vim.api.nvim_buf_set_extmark(buf, ns, lnum, block.indent, {
            end_col = line_len,
            hl_group = hl,
            hl_mode = "combine",
            ephemeral = true,
            priority = priority,
          })
        end

        -- 2. Add virtual padding to reach max_col
        local virt_start = math.max(block.indent, line_len)
        if virt_start < max_len then
          local padding = string.rep(" ", max_len - virt_start)
          vim.api.nvim_buf_set_extmark(buf, ns, lnum, virt_start, {
            virt_text = {
              { padding, hl },
            },
            virt_text_pos = "overlay",
            hl_mode = "combine",
            ephemeral = true,
            priority = priority,
          })
        end
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

vim.api.nvim_create_user_command("BlockShowBlocks", function()
  local buf = vim.api.nvim_get_current_buf()
  local blocks = block_cache[buf]
  if not blocks then
    vim.notify("No blocks cached for this buffer.", vim.log.levels.WARN)
    return
  end

  local lines = {}
  table.insert(lines, ("Total blocks: %d"):format(#blocks))
  table.insert(lines, "Idx  Start  Stop  Indent  MaxCol")
  table.insert(lines, "---- ------ ----- ------- -------")

  for i, b in ipairs(blocks) do
    table.insert(
      lines,
      ("%3d  %5d  %4d  %6d  %6d"):format(
        i,
        b.start,
        b.stop,
        b.indent,
        b.max_col
      )
    )
  end

  -- Create a scratch buffer and show it
  local out_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(out_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "blockdebug", { buf = out_buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = out_buf })

  vim.cmd.vsplit()
  vim.api.nvim_win_set_buf(0, out_buf)
end, {})

return M
