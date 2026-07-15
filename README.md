# block.nvim

`block.nvim` gives nested code scopes distinct background colors. Every block
starts at its header, includes its content and closing delimiter, and expands to
the display width of everything nested inside it.

The analyzer is indentation-based rather than language-specific, so it works in
normal buffers of any filetype without requiring a Tree-sitter parser. Tabs,
Unicode display widths, blank lines, closing delimiters, and common branch
continuations are handled.

## Requirements

- Neovim 0.12 or newer

## Installation

```lua
{
  "HampusHauffman/block.nvim",
  opts = {},
}
```

## Commands

| Command | Action |
| --- | --- |
| `:Block` | Toggle the current buffer |
| `:BlockOn` | Enable the current buffer |
| `:BlockOff` | Disable the current buffer |

## Configuration

```lua
require("block").setup({
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
})
```

When `colors` is unset, backgrounds are generated from the active colorscheme.
The plugin regenerates them after `:colorscheme` changes. To use fixed colors:

```lua
require("block").setup({
  colors = {
    "#1a1a2e",
    "#2f1a2e",
    "#1a2e1a",
    "#2e261a",
  },
})
```

Analysis is cached by buffer change tick and debounced while typing. The
decoration provider creates only ephemeral highlights for lines Neovim is
currently drawing.
