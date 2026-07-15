local M = {}

local accent_groups = {
  "Function",
  "Conditional",
  "String",
  "Type",
  "Keyword",
  "Constant",
}

local fallback_accents = {
  0x7AA2F7,
  0xBB9AF7,
  0x9ECE6A,
  0xE0AF68,
  0xF7768E,
  0x7DCFFF,
}

local group_count = 0

---@param color integer
---@param fallback integer
---@return integer
local function color_or(color, fallback)
  return type(color) == "number" and color or fallback
end

---@param from integer
---@param to integer
---@param amount number
---@return integer
local function mix(from, to, amount)
  local function channel(shift)
    local base = bit.band(bit.rshift(from, shift), 0xFF)
    local accent = bit.band(bit.rshift(to, shift), 0xFF)
    return math.floor(base + (accent - base) * amount + 0.5)
  end

  return bit.bor(
    bit.lshift(channel(16), 16),
    bit.lshift(channel(8), 8),
    channel(0)
  )
end

---@param config Block.ResolvedConfig
function M.setup(config)
  local count = config.colors and #config.colors or config.levels
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local fallback_bg = vim.o.background == "light" and 0xFFFFFF or 0x000000
  local background = color_or(normal.bg, fallback_bg)

  for index = 1, math.max(group_count, count) do
    local name = "BlockDepth" .. index
    if index <= count then
      local color
      if config.colors then
        color = config.colors[index]
      else
        local accent_name = accent_groups[(index - 1) % #accent_groups + 1]
        local accent = vim.api.nvim_get_hl(
          0,
          { name = accent_name, link = false }
        )
        local fallback = fallback_accents[(index - 1) % #fallback_accents + 1]
        color = mix(background, color_or(accent.fg, fallback), config.shade / 100)
      end
      vim.api.nvim_set_hl(0, name, { bg = color })
    else
      vim.api.nvim_set_hl(0, name, {})
    end
  end

  group_count = count
end

---@param depth integer
---@return string
function M.group(depth)
  return "BlockDepth" .. ((depth - 1) % group_count + 1)
end

return M
