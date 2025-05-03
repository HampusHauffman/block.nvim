--- @class BlockIndentConfig
--- @field priority integer # Priority for extmarks
--- @field enabled boolean # Whether to show indent guides
--- @field char string # Character used for virtual indent guides
--- @field hl string|string[] # Highlight group(s) for indent levels

--- @class BlockConfig
--- @field indent BlockIndentConfig
--- @field filter fun(buf: integer): boolean

local M = {}

--- Whether indent guides are currently enabled
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
    return vim.g.snacks_indent ~= false
      and vim.b[buf].snacks_indent ~= false
      and vim.bo[buf].buftype == ""
  end,
}

--- Active configuration (will be extended later)
--- @type BlockConfig
local config = defaults

--- Namespace for extmarks
--- @type integer
local ns = vim.api.nvim_create_namespace("block")

return M
