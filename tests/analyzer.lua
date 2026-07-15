local root = vim.fn.getcwd()
package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  package.path,
}, ";")

local analyzer = require("block.analyzer")

local function equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(("%s\nexpected: %s\nactual: %s"):format(
      message,
      vim.inspect(expected),
      vim.inspect(actual)
    ))
  end
end

local lua = analyzer.analyze({
  "local function outer(count)",
  "  for index = 1, count do",
  "    print(index)",
  "  end",
  "end",
}, 2, 1)

equal(#lua.blocks, 2, "finds function and loop blocks")
equal(
  { lua.blocks[1].first, lua.blocks[1].last, lua.blocks[1].indent },
  { 0, 4, 0 },
  "function includes its signature and closing delimiter"
)
equal(
  { lua.blocks[2].first, lua.blocks[2].last, lua.blocks[2].indent },
  { 1, 3, 2 },
  "loop includes its header and closing delimiter"
)
equal(
  lua.line_blocks,
  { 1, 2, 2, 2, 1 },
  "each line belongs to its innermost block"
)
assert(
  lua.blocks[1].width > lua.blocks[2].width,
  "outer block must enclose the nested block"
)

local python = analyzer.analyze({
  "def one():",
  "    return 1",
  "def two():",
  "    return 2",
}, 4, 1)

equal(#python.blocks, 2, "finds sibling definitions")
equal(
  { python.blocks[1].first, python.blocks[1].last },
  { 0, 1 },
  "a dedented sibling does not enter the previous block"
)
equal(
  { python.blocks[2].first, python.blocks[2].last },
  { 2, 3 },
  "the sibling owns its signature and content"
)

local separated = analyzer.analyze({
  "def one():",
  "    return 1",
  "",
  "def two():",
  "    return 2",
  "",
}, 4, 1)

equal(
  separated.line_blocks,
  { 1, 1, false, 2, 2, false },
  "top-level separator lines remain outside sibling blocks"
)

local branches = analyzer.analyze({
  "if ready:",
  "  start()",
  "else:",
  "  stop()",
}, 2, 1)

equal(#branches.blocks, 1, "branch continuations remain one block")
equal(
  { branches.blocks[1].first, branches.blocks[1].last },
  { 0, 3 },
  "the branch block includes every branch"
)

local tabs = analyzer.analyze({
  "function tabbed()",
  "\treturn '界'",
  "end",
}, 4, 1)

equal(tabs.line_widths[2], 15, "tabs and wide characters use display columns")

local allman = analyzer.analyze({
  "void example()",
  "{",
  "  run();",
  "}",
}, 2, 1)

equal(
  { allman.blocks[1].first, allman.blocks[1].last },
  { 0, 3 },
  "a standalone opener keeps the definition signature in its block"
)

print("block.nvim analyzer tests passed")
