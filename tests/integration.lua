local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)

local block = require("block")
block.setup({
  automatic = true,
  colors = { "#111111", "#222222" },
  debounce_ms = 50,
})

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "function example()",
  "  if ok then",
  "    run()",
  "  end",
  "end",
})

local set_extmark = vim.api.nvim_buf_set_extmark
local ephemeral_marks = 0
vim.api.nvim_buf_set_extmark = function(...)
  local arguments = { ... }
  local options = arguments[5]
  if options.ephemeral then
    ephemeral_marks = ephemeral_marks + 1
  end
  return set_extmark(...)
end

block.refresh(buf)
vim.cmd("redraw")

assert(ephemeral_marks > 0, "the decoration provider did not render any blocks")

ephemeral_marks = 0
vim.api.nvim_buf_set_lines(buf, 2, 3, false, { "    rerun()" })
vim.cmd("redraw")
vim.api.nvim_buf_set_extmark = set_extmark

assert(
  ephemeral_marks > 0,
  "blocks disappeared while waiting for debounced analysis"
)

block.disable(buf)
block.enable(buf)
block.toggle(buf)
block.toggle(buf)

assert(vim.fn.exists(":Block") == 2, "Block command was not created")
assert(vim.fn.exists(":BlockOn") == 2, "BlockOn command was not created")
assert(vim.fn.exists(":BlockOff") == 2, "BlockOff command was not created")

print("block.nvim integration tests passed")
