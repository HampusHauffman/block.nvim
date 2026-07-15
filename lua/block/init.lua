local config = require("block.config")
local highlight = require("block.highlight")
local renderer = require("block.renderer")

local M = {}

local did_setup = false

local function assert_setup()
  if not did_setup then
    error("block.nvim: call setup() first", 3)
  end
end

local function notify(enabled)
  local state = enabled and "enabled" or "disabled"
  vim.notify("block.nvim: " .. state .. " for current buffer")
end

---@param opts? Block.Config
function M.setup(opts)
  local resolved = config.resolve(opts)
  highlight.setup(resolved)
  renderer.setup(resolved)

  vim.api.nvim_create_user_command("Block", function()
    notify(renderer.toggle())
  end, { desc = "Toggle block backgrounds in the current buffer", force = true })

  vim.api.nvim_create_user_command("BlockOn", function()
    renderer.enable()
    notify(true)
  end, { desc = "Enable block backgrounds in the current buffer", force = true })

  vim.api.nvim_create_user_command("BlockOff", function()
    renderer.disable()
    notify(false)
  end, { desc = "Disable block backgrounds in the current buffer", force = true })

  did_setup = true
end

---@param buf? integer
function M.enable(buf)
  assert_setup()
  renderer.enable(buf)
end

---@param buf? integer
function M.disable(buf)
  assert_setup()
  renderer.disable(buf)
end

---@param buf? integer
---@return boolean enabled
function M.toggle(buf)
  assert_setup()
  return renderer.toggle(buf)
end

---@param buf? integer
function M.refresh(buf)
  assert_setup()
  renderer.refresh(buf)
end

return M
