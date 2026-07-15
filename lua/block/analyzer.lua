---@class Block.Range
---@field id integer
---@field first integer First row, zero-based and inclusive.
---@field last integer Last row, zero-based and inclusive.
---@field indent integer Left edge in display columns.
---@field content_indent integer Body indentation in display columns.
---@field width integer Right edge in display columns.
---@field depth integer
---@field parent? integer
---@field _max_width integer

---@class Block.Analysis
---@field blocks Block.Range[]
---@field line_blocks (integer|false)[]
---@field line_widths integer[]
---@field line_indents string[]
---@field line_byte_lengths integer[]
---@field tabstop integer

local M = {}

local continuations = {
  ["catch"] = true,
  ["elif"] = true,
  ["else"] = true,
  ["elseif"] = true,
  ["except"] = true,
  ["finally"] = true,
  ["rescue"] = true,
}

local closing_words = {
  ["done"] = true,
  ["end"] = true,
  ["esac"] = true,
  ["fi"] = true,
  ["until"] = true,
}

local opening_words = {
  ["begin"] = true,
  ["do"] = true,
  ["then"] = true,
}

---@param line string
---@param tabstop integer
---@return integer
local function display_width(line, tabstop)
  local width = 0
  local offset = 1

  while true do
    local tab = line:find("\t", offset, true)
    if tab == nil then
      return width + vim.api.nvim_strwidth(line:sub(offset))
    end

    width = width + vim.api.nvim_strwidth(line:sub(offset, tab - 1))
    width = width + tabstop - (width % tabstop)
    offset = tab + 1
  end
end

---@param whitespace string
---@param tabstop integer
---@return integer
local function indent_width(whitespace, tabstop)
  local width = 0

  for index = 1, #whitespace do
    if whitespace:byte(index) == 9 then
      width = width + tabstop - (width % tabstop)
    else
      width = width + 1
    end
  end

  return width
end

---@param text string
---@return string?
local function control_word(text)
  return text:match("^[}%])]*%s*([%a_][%w_]*)")
end

---@param text string
---@return boolean
local function is_continuation(text)
  return continuations[control_word(text) or ""] == true
end

---@param text string
---@return boolean
local function is_closer(text)
  if text:match("^[}%])]") then
    return true
  end
  return closing_words[control_word(text) or ""] == true
end

---@param text string
---@return boolean
local function is_standalone_opener(text)
  if text:match("^[{([]+%s*$") then
    return true
  end
  return opening_words[control_word(text) or ""] == true
end

---@param lines string[]
---@param tabstop integer
---@param padding integer
---@return Block.Analysis
function M.analyze(lines, tabstop, padding)
  vim.validate("lines", lines, "table")
  vim.validate("tabstop", tabstop, "number")
  vim.validate("padding", padding, "number")

  ---@type Block.Range[]
  local blocks = {}
  ---@type Block.Range[]
  local stack = {}
  ---@type (integer|false)[]
  local line_blocks = {}
  ---@type integer[]
  local line_widths = {}
  ---@type string[]
  local line_indents = {}
  ---@type integer[]
  local line_byte_lengths = {}

  local previous_text_row ---@type integer?
  local previous_indent = 0
  local previous_was_continuation = false
  local previous_text = ""
  local earlier_text_row ---@type integer?
  local earlier_indent = 0

  ---@param block Block.Range
  ---@param last integer
  local function close_block(block, last)
    block.last = math.max(block.first, last)
    block.width = math.max(block._max_width, block.indent) + padding

    if block.parent ~= nil then
      local parent = blocks[block.parent]
      parent._max_width = math.max(parent._max_width, block.width)
    end
  end

  for row = 0, #lines - 1 do
    local line = lines[row + 1]
    local whitespace = line:match("^[ \t]*") or ""
    local text = line:sub(#whitespace + 1)
    local blank = text == ""
    local width = display_width(line, tabstop)
    local indent = indent_width(whitespace, tabstop)

    line_widths[row + 1] = width
    line_indents[row + 1] = whitespace
    line_byte_lengths[row + 1] = #line

    if blank then
      line_blocks[row + 1] = stack[#stack] and stack[#stack].id or false
    else
      local continuation = is_continuation(text)
      local closer = is_closer(text)
      local closing_owner ---@type integer?

      while #stack > 0 and indent < stack[#stack].content_indent do
        local block = stack[#stack]
        if continuation and indent == block.indent then
          break
        end

        table.remove(stack)
        if closer and indent == block.indent then
          block._max_width = math.max(block._max_width, width)
          close_block(block, row)
          closing_owner = block.id
        else
          close_block(block, previous_text_row)
        end
      end

      local top = stack[#stack]
      local gap_owner = closing_owner or (top and top.id) or false
      if previous_text_row ~= nil then
        for gap_row = previous_text_row + 1, row - 1 do
          line_blocks[gap_row + 1] = gap_owner
        end
      end

      local resumes_branch = top ~= nil
        and previous_was_continuation
        and previous_indent == top.indent
        and indent == top.content_indent

      if
        previous_text_row ~= nil
        and indent > previous_indent
        and not resumes_branch
      then
        local parent = stack[#stack]
        local id = #blocks + 1
        local first = previous_text_row
        local block_indent = previous_indent

        if
          earlier_text_row ~= nil
          and earlier_indent == previous_indent
          and is_standalone_opener(previous_text)
        then
          first = earlier_text_row
          block_indent = earlier_indent
        end

        local max_width = width
        for owned_row = first, row do
          max_width = math.max(max_width, line_widths[owned_row + 1])
        end

        local block = {
          id = id,
          first = first,
          last = row,
          indent = block_indent,
          content_indent = indent,
          width = 0,
          depth = parent and parent.depth + 1 or 1,
          parent = parent and parent.id or nil,
          _max_width = max_width,
        }

        blocks[id] = block
        stack[#stack + 1] = block
        for owned_row = first, row do
          line_blocks[owned_row + 1] = id
        end
        top = block
        closing_owner = nil
      end

      if closing_owner ~= nil then
        line_blocks[row + 1] = closing_owner
      elseif top ~= nil then
        top._max_width = math.max(top._max_width, width)
        line_blocks[row + 1] = top.id
      else
        line_blocks[row + 1] = false
      end

      earlier_text_row = previous_text_row
      earlier_indent = previous_indent
      previous_text_row = row
      previous_indent = indent
      previous_was_continuation = continuation
      previous_text = text
    end
  end

  if previous_text_row ~= nil then
    for row = previous_text_row + 1, #lines - 1 do
      line_blocks[row + 1] = false
    end
  end

  local last_row = previous_text_row or 0
  while #stack > 0 do
    local block = table.remove(stack)
    close_block(block, last_row)
  end

  return {
    blocks = blocks,
    line_blocks = line_blocks,
    line_widths = line_widths,
    line_indents = line_indents,
    line_byte_lengths = line_byte_lengths,
    tabstop = tabstop,
  }
end

return M
