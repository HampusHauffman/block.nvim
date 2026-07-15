---@class Block.Config
---@field automatic? boolean Enable blocks in eligible buffers by default.
---@field colors? string[] Explicit background colors, one per depth.
---@field levels? integer Number of generated colors when `colors` is not set.
---@field shade? number Percentage of the theme accent mixed into each background.
---@field padding? integer Columns added to the right edge of every block.
---@field priority? integer Base extmark priority.
---@field debounce_ms? integer Delay before re-analyzing changed text.
---@field filter? fun(buf: integer): boolean Return whether a buffer can be rendered.

---@class Block.ResolvedConfig
---@field automatic boolean
---@field colors? string[]
---@field levels integer
---@field shade number
---@field padding integer
---@field priority integer
---@field debounce_ms integer
---@field filter fun(buf: integer): boolean

local M = {}

---@type Block.ResolvedConfig
local defaults = {
  automatic = true,
  colors = nil,
  levels = 4,
  shade = 12,
  padding = 1,
  priority = 110,
  debounce_ms = 20,
  filter = function(buf)
    return vim.bo[buf].buftype == ""
  end,
}

local valid_keys = {
  automatic = true,
  colors = true,
  levels = true,
  shade = true,
  padding = true,
  priority = true,
  debounce_ms = true,
  filter = true,
}

---@param name string
---@param value number
local function validate_integer(name, value)
  vim.validate(name, value, "number")
  if value % 1 ~= 0 then
    error(("block.nvim: %s must be an integer"):format(name), 3)
  end
end

---@param opts? Block.Config
---@return Block.ResolvedConfig
function M.resolve(opts)
  opts = opts or {}
  vim.validate("opts", opts, "table")

  for key in pairs(opts) do
    if not valid_keys[key] then
      error(("block.nvim: unknown option %q"):format(key), 2)
    end
  end

  local config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)

  vim.validate("automatic", config.automatic, "boolean")
  vim.validate("filter", config.filter, "function")
  validate_integer("levels", config.levels)
  validate_integer("padding", config.padding)
  validate_integer("priority", config.priority)
  validate_integer("debounce_ms", config.debounce_ms)
  vim.validate("shade", config.shade, "number")

  if config.levels < 1 then
    error("block.nvim: levels must be at least 1", 2)
  end
  if config.padding < 0 then
    error("block.nvim: padding cannot be negative", 2)
  end
  if config.debounce_ms < 0 then
    error("block.nvim: debounce_ms cannot be negative", 2)
  end
  if config.shade < 0 or config.shade > 100 then
    error("block.nvim: shade must be between 0 and 100", 2)
  end

  if config.colors ~= nil then
    vim.validate("colors", config.colors, "table")
    if #config.colors == 0 then
      error("block.nvim: colors cannot be empty", 2)
    end
    for index, color in ipairs(config.colors) do
      vim.validate(("colors[%d]"):format(index), color, "string")
      if not color:match("^#%x%x%x%x%x%x$") then
        error(
          ("block.nvim: colors[%d] must use #RRGGBB format"):format(index),
          2
        )
      end
    end
  end

  return config
end

return M
