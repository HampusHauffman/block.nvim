--- @class BlockIndentConfig
--- @field priority integer
--- @field enabled boolean
--- @field hl string|string[]

--- @class BlockConfig
--- @field indent BlockIndentConfig
--- @field filter fun(buf: integer): boolean

local M = {}

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
--- @field content_indent integer
--- @field highlight_indent integer
--- @field max_col integer

--- @class BlockCacheEntry
--- @field changedtick integer
--- @field blocks BlockRange[]

local block_cache = {} --- @type table<integer, BlockCacheEntry>

local function get_block_hl(indent, shiftwidth)
  local level = math.floor(indent / shiftwidth)
  return "Block" .. (level % 4)
end

--- @param line string
--- @param tabstop number
--- @return number indent_width
--- @return boolean is_all_whitespace
local function get_indent_width(line, tabstop)
  local whitespace = line:match("^%s*")
  if not whitespace then
    return 0, line == ""
  end

  local width = 0
  for char in string.gmatch(whitespace, ".") do
    if char == " " then
      width = width + 1
    elseif char == "	" then
      width = width + tabstop - (width % tabstop)
    end
  end
  return width, line:match("%S") == nil
end

local function virtcol_to_byte(line, vcol, tabstop)
  local byte_count = 0
  local current_vcol = 0
  -- This is a simple implementation that assumes single-byte characters for non-tabs.
  -- It may not be accurate for all multi-byte characters (e.g., emojis).
  for i = 1, #line do
    if current_vcol >= vcol then
      return byte_count
    end
    local c = line:sub(i, i)
    if c == "	" then
      current_vcol = current_vcol + (tabstop - (current_vcol % tabstop))
    else
      current_vcol = current_vcol + 1
    end
    byte_count = byte_count + 1
  end
  return byte_count
end

local function set_virtual_highlight(
  buf,
  lnum,
  col,
  padding_len,
  content_indent,
  highlight_indent,
  shiftwidth,
  hl_base
)
  if padding_len <= 0 then
    return
  end

  local line = vim.fn.getline(lnum + 1)
  local is_blank = line == ""

  local priority = config.indent.priority
    + math.floor(content_indent / shiftwidth)
  local hl = hl_base or get_block_hl(content_indent, shiftwidth)

  local virt_text = {}

  if is_blank then
    col = 0
    table.insert(virt_text, { string.rep(" ", highlight_indent), nil })
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
  })
end

local function draw_blocks(_, buf, top, bottom)
  local shiftwidth = vim.bo[buf].shiftwidth > 0 and vim.bo[buf].shiftwidth
    or vim.bo[buf].tabstop
  local tabstop = vim.bo[buf].tabstop
  local cache_entry = block_cache[buf]
  if not cache_entry then
    return
  end
  local blocks = cache_entry.blocks

  vim.api.nvim_buf_call(buf, function()
    table.sort(blocks, function(a, b)
      return a.content_indent > b.content_indent
    end)

    for _, block in ipairs(blocks) do
      -- Skip the root block (indentation level 0)
      if block.content_indent > 0 then
        local start_lnum = math.max(block.start, top)
        local stop_lnum = math.min(block.stop, bottom - 1)
        local hl = get_block_hl(block.content_indent, shiftwidth)
        local priority = config.indent.priority
          + math.floor(block.content_indent / shiftwidth)

        for lnum = start_lnum, stop_lnum do
          local line = vim.fn.getline(lnum + 1)

          -- Highlight from block's highlight_indent to end of line
          local start_byte =
            virtcol_to_byte(line, block.highlight_indent, tabstop)
          if #line > start_byte then
            vim.api.nvim_buf_set_extmark(buf, ns, lnum, start_byte, {
              end_col = #line,
              hl_group = hl,
              ephemeral = true,
              priority = priority,
              strict = false,
            })
          end

          -- Padding highlight
          local display_len = vim.fn.strdisplaywidth(line)
          local virt_start = math.max(block.highlight_indent, display_len)
          local padding_len = block.max_col - virt_start
          local col = #line

          set_virtual_highlight(
            buf,
            lnum,
            col,
            padding_len,
            block.content_indent,
            block.highlight_indent,
            shiftwidth,
            hl
          )
        end
      end
    end
  end)
end

---@param lines string[]
---@param tabstop number
local function get_indent_blocks(lines, tabstop)
  ---@type BlockRange[]
  local stack = {}
  ---@type BlockRange[]
  local result = {}
  local last_lnum_with_text = -1
  local last_indent_with_text = 0
  local last_len_with_text = 0

  for lnum = 0, #lines - 1 do
    local line = lines[lnum + 1]
    local indent, is_blank = get_indent_width(line, tabstop)
    local len = vim.fn.strdisplaywidth(line)

    if not is_blank then
      -- End blocks that are more indented than the current line.
      while #stack > 0 and indent < stack[#stack].content_indent do
        local block = table.remove(stack)
        block.stop = lnum
        block.max_col = block.max_col + 1 -- Add padding
        table.insert(result, block)
      end

      -- Start a new block if indentation increases.
      if #stack == 0 or indent > stack[#stack].content_indent then
        local start_lnum = lnum
        local initial_max_col = len
        local highlight_indent = (#stack > 0) and stack[#stack].content_indent
          or 0

        if #stack > 0 and indent > last_indent_with_text then
          start_lnum = last_lnum_with_text
          -- The block spans from the previous line to the current one,
          -- so max_col should consider both lines from the start.
          initial_max_col = math.max(len, last_len_with_text)
        end

        table.insert(stack, {
          start = start_lnum,
          stop = lnum,
          content_indent = indent,
          highlight_indent = highlight_indent,
          max_col = initial_max_col,
        })
      end
      last_lnum_with_text = lnum
      last_indent_with_text = indent
      last_len_with_text = len
    end

    -- Update max_col for all active blocks.
    for _, block in ipairs(stack) do
      block.max_col = math.max(block.max_col, len)
    end
  end

  -- Close all remaining blocks.
  while #stack > 0 do
    local block = table.remove(stack)
    block.stop = #lines - 1
    block.max_col = block.max_col + 1 -- Add padding
    table.insert(result, block)
  end

  return result
end

local function compute_all_blocks(buf)
  if
    not M.enabled
    or not vim.api.nvim_buf_is_valid(buf)
    or not vim.api.nvim_buf_is_loaded(buf)
    or not config.filter(buf)
  then
    return
  end

  local changedtick = vim.b[buf].changedtick
  if block_cache[buf] and block_cache[buf].changedtick == changedtick then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local tabstop = vim.bo[buf].tabstop
  local blocks = get_indent_blocks(lines, tabstop)
  block_cache[buf] = {
    changedtick = changedtick,
    blocks = blocks,
  }
end

function M.enable()
  M.enabled = true
  vim.print("block.nvim: enabled")

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    compute_all_blocks(buf)
  end

  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, win, buf, top, bottom)
      if M.enabled and config.filter(buf) then
        draw_blocks(win, buf, top, bottom)
      end
    end,
  })

  local group = vim.api.nvim_create_augroup("block.nvim", { clear = true })
  vim.api.nvim_create_autocmd(
    { "BufWritePost", "TextChanged", "TextChangedI", "InsertLeave" },
    {
      group = group,
      pattern = "*",
      callback = function(args)
        if config.filter(args.buf) then
          compute_all_blocks(args.buf)
        end
      end,
    }
  )
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    pattern = "*",
    callback = function(args)
      block_cache[args.buf] = nil
    end,
  })
end

function M.disable()
  M.enabled = false
  vim.print("block.nvim: disabled")

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end

  block_cache = {}
  vim.api.nvim_set_decoration_provider(ns, {})
  pcall(vim.api.nvim_del_augroup_by_name, "block.nvim")
end

return M
