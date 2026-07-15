local analyzer = require("block.analyzer")
local highlight = require("block.highlight")

local M = {}

local namespace = vim.api.nvim_create_namespace("block.nvim")

---@class Block.BufferState
---@field analysis? Block.Analysis
---@field changedtick? integer
---@field enabled? boolean
---@field generation integer

---@type table<integer, Block.BufferState>
local states = {}

local config ---@type Block.ResolvedConfig

---@param buf integer
---@return Block.BufferState
local function state_for(buf)
  local state = states[buf]
  if state == nil then
    state = { generation = 0 }
    states[buf] = state
  end
  return state
end

---@param buf integer
---@return boolean
local function is_enabled(buf)
  local state = states[buf]
  if state ~= nil and state.enabled ~= nil then
    return state.enabled
  end
  return config.automatic
end

---@param buf integer
---@return boolean
local function is_eligible(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.api.nvim_buf_is_loaded(buf)
    and is_enabled(buf)
    and config.filter(buf)
end

---@param buf integer
local function redraw(buf)
  vim.api.nvim__redraw({ buf = buf, valid = false })
end

---@param buf integer
local function analyze_buffer(buf)
  if not is_eligible(buf) then
    return
  end

  local state = state_for(buf)
  local changedtick = vim.api.nvim_buf_get_changedtick(buf)
  if state.analysis ~= nil and state.changedtick == changedtick then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  state.analysis = analyzer.analyze(lines, vim.bo[buf].tabstop, config.padding)
  state.changedtick = changedtick
  redraw(buf)
end

---@param buf integer
local function invalidate(buf)
  local state = state_for(buf)
  state.analysis = nil
  state.changedtick = nil
end

---@param buf integer
local function schedule(buf)
  local state = state_for(buf)
  state.generation = state.generation + 1
  local generation = state.generation

  vim.defer_fn(function()
    local current = states[buf]
    if current ~= nil and current.generation == generation then
      analyze_buffer(buf)
    end
  end, config.debounce_ms)
end

---@param whitespace string
---@param target integer
---@param tabstop integer
---@return integer
local function byte_for_column(whitespace, target, tabstop)
  local column = 0

  for index = 1, #whitespace do
    if column >= target then
      return index - 1
    end

    if whitespace:byte(index) == 9 then
      column = column + tabstop - (column % tabstop)
    else
      column = column + 1
    end
  end

  return #whitespace
end

---@param analysis Block.Analysis
---@param owner integer
---@return Block.Range[]
local function block_chain(analysis, owner)
  ---@type Block.Range[]
  local chain = {}
  local current ---@type integer?
  current = owner

  while current ~= nil do
    local block = analysis.blocks[current]
    chain[#chain + 1] = block
    current = block.parent
  end

  local first = 1
  local last = #chain
  while first < last do
    chain[first], chain[last] = chain[last], chain[first]
    first = first + 1
    last = last - 1
  end

  return chain
end

---@param chain Block.Range[]
---@param line_width integer
---@return [string, string][]
local function padding_chunks(chain, line_width)
  local boundaries = { line_width }

  for _, block in ipairs(chain) do
    if block.indent > line_width then
      boundaries[#boundaries + 1] = block.indent
    end
    if block.width > line_width then
      boundaries[#boundaries + 1] = block.width
    end
  end

  table.sort(boundaries)

  ---@type integer[]
  local unique = {}
  for _, boundary in ipairs(boundaries) do
    if unique[#unique] ~= boundary then
      unique[#unique + 1] = boundary
    end
  end

  ---@type [string, string][]
  local chunks = {}
  for index = 1, #unique - 1 do
    local first = unique[index]
    local last = unique[index + 1]
    local group ---@type string?

    for block_index = #chain, 1, -1 do
      local block = chain[block_index]
      if first >= block.indent and first < block.width then
        group = highlight.group(block.depth)
        break
      end
    end

    if group ~= nil and last > first then
      local previous = chunks[#chunks]
      if previous ~= nil and previous[2] == group then
        previous[1] = previous[1] .. string.rep(" ", last - first)
      else
        chunks[#chunks + 1] = { string.rep(" ", last - first), group }
      end
    end
  end

  return chunks
end

---@param buf integer
---@param row integer
---@param analysis Block.Analysis
local function draw_line(buf, row, analysis)
  local owner = analysis.line_blocks[row + 1]
  if owner == nil or owner == false then
    return
  end

  local chain = block_chain(analysis, owner)
  local whitespace = analysis.line_indents[row + 1]
  local byte_length = analysis.line_byte_lengths[row + 1]

  for _, block in ipairs(chain) do
    local start_byte = byte_for_column(
      whitespace,
      block.indent,
      analysis.tabstop
    )
    if start_byte < byte_length then
      vim.api.nvim_buf_set_extmark(buf, namespace, row, start_byte, {
        end_col = byte_length,
        ephemeral = true,
        hl_group = highlight.group(block.depth),
        hl_mode = "combine",
        priority = config.priority + block.depth,
        strict = false,
      })
    end
  end

  local chunks = padding_chunks(chain, analysis.line_widths[row + 1])
  if #chunks > 0 then
    vim.api.nvim_buf_set_extmark(buf, namespace, row, byte_length, {
      ephemeral = true,
      virt_text = chunks,
      virt_text_pos = "overlay",
      hl_mode = "combine",
      priority = config.priority + #chain,
    })
  end
end

---@param resolved Block.ResolvedConfig
function M.setup(resolved)
  config = resolved
  states = {}

  local group = vim.api.nvim_create_augroup("block.nvim", { clear = true })

  vim.api.nvim_set_decoration_provider(namespace, {
    on_win = function(_, _, buf)
      local state = states[buf]
      return is_eligible(buf) and state ~= nil and state.analysis ~= nil
    end,
    on_line = function(_, _, buf, row)
      local state = states[buf]
      if state ~= nil and state.analysis ~= nil then
        draw_line(buf, row, state.analysis)
      end
    end,
  })

  vim.api.nvim_create_autocmd(
    { "BufReadPost", "BufNewFile", "BufWinEnter" },
    {
      group = group,
      callback = function(args)
        analyze_buffer(args.buf)
      end,
    }
  )

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(args)
      schedule(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = "tabstop",
    callback = function()
      schedule(vim.api.nvim_get_current_buf())
    end,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      highlight.setup(config)
      vim.api.nvim__redraw({ valid = false })
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(args)
      states[args.buf] = nil
    end,
  })

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    analyze_buffer(buf)
  end
end

---@param buf? integer
function M.enable(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  state_for(buf).enabled = true
  analyze_buffer(buf)
  redraw(buf)
end

---@param buf? integer
function M.disable(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local state = state_for(buf)
  state.enabled = false
  invalidate(buf)
  redraw(buf)
end

---@param buf? integer
---@return boolean enabled
function M.toggle(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if is_enabled(buf) then
    M.disable(buf)
    return false
  end

  M.enable(buf)
  return true
end

---@param buf? integer
function M.refresh(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  invalidate(buf)
  analyze_buffer(buf)
end

return M
