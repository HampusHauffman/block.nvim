local M = {}

local core = require("block.block")
local util = require("block.util")

--- @class BlockOpts
--- @field percent number # Brightness multiplier per depth level (e.g., 0.8 = darker)
--- @field depth number # Number of nested highlight levels to generate
--- @field automatic boolean # Whether to enable the plugin automatically on file open
--- @field colors? string[] # Optional custom colors for highlights; overrides percent/depth
--- @field bg? string # Optional override for background color (hex)

--- @type BlockOpts
local defaults = {
  percent = 0.8,
  depth = 4,
  automatic = false,
  colors = nil,
  bg = nil,
}

--- Stores merged configuration after setup
--- @type BlockOpts
M.options = vim.deepcopy(defaults)

--- Setup the plugin
--- @param opts BlockOpts?
function M.setup(opts)
  -- Merge user options with defaults
  M.options = vim.tbl_deep_extend("force", defaults, opts or {}) --[[@as BlockOpts]]

  -- Create or clear the plugin's autocmd group
  vim.api.nvim_create_augroup("block.nvim", { clear = true })

  -- If custom colors are given, use them directly and skip color generation
  if M.options.colors then
    M.options.depth = #M.options.colors
    for i, color in ipairs(M.options.colors) do
      util.hl(i - 1, color)
    end
  else
    -- Defer highlight generation until UI is ready
    vim.defer_fn(function()
      local bg = M.options.bg or util.get_bg_color()
      if not bg then
        vim.notify_once(
          "block.nvim: Could not detect background color.",
          vim.log.levels.ERROR
        )
        return
      end
      util.create_highlights_from_depth(M.options.depth, M.options.percent, bg)
    end, 0)
  end

  -- Auto-enable the plugin on supported filetypes if 'automatic' is true
  if M.options.automatic then
    vim.api.nvim_create_autocmd("FileType", {
      group = "block.nvim",
      pattern = "*",
      callback = function()
        core.enable()
      end,
    })
  end

  -- Add a user command to enable the plugin manually
  vim.api.nvim_create_user_command("BlockOn", core.enable, {})
end

return M
