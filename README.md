# ❐block.nvim
![Neovim](https://img.shields.io/badge/NeoVim-%2357A143.svg?&style=for-the-badge&logo=neovim&logoColor=white)
![GitHub repo stars](https://img.shields.io/github/stars/HampusHauffman/block.nvim?style=flat&logo=github&logoColor=whitesmoke&label=Stars⭐️ )

![image](https://user-images.githubusercontent.com/3845743/245099616-f6259c1d-3901-4860-8b4a-21e63f2f00db.png)
Screenshot is taken on `Kitty` terminal with `font_family FiraCode Nerd Font` and `dracula` as colortheme.
## ⚡️ Requirements
Neovim Stable release and up (Have not tested how far back this works).
## 🚀 Usage
#### `:Block` Toggle current buffer
#### `:BlockOn` On current buffer
#### `:BlockOff` Off current buffer

## 📦 Installation
### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "HampusHauffman/block.nvim",
    config = function()
        require("block").setup({})
    end
},
```
## ⚙️ Configuration / Setup
To change the defaults you can change any of the following values: 
```lua
---@field percent number  -- The change in color. 0.8 would change each box to be 20% darker than the last and 1.2 would be 20% brighter.
---@field depth number -- De depths of changing colors. Defaults to 4. After this the colors reset. Note that the first color is taken from your "Normal" highlight so a 4 is 3 new colors.
---@field automatic boolean -- Automatically turns this on when treesitter finds a parser for the current file.
---@field colors string [] | nil -- A list of colors to use instead. If this is set percent and depth are not taken into account.
---@field bg string? -- Set this if block.nvim cannot automatically find your background color.

    require("block").setup({
        percent = 0.8,
        depth = 4,
        colors = nil,
        automatic = false,
--        colors = {
--            "#ff0000"
--            "#00ff00"
--            "#0000ff"
--        },
        bg = nil,
    })
```

### 🔧 Troubleshooting
If block.nvim cannot determine your background color, for instance if you're using a transparent colorscheme, you must manually
supply `bg` in the config. To figure out which value you should use for `bg`, temporarily turn off transparency and run the
following command:

```vim
lua vim.notify(vim.inspect(vim.api.nvim_get_hl(0, { name = "Normal" }).bg))
```

## 🤔 Motivation
This plugin is something i've wanted for a while but havent found any previous implementation of in neovim. 
My hope is it will help with legibility in deeply nested code.

## 📝 Todo
* Bug test and fix any community found issues
* Add vim docs for usage
* Handle multi character characters such as emojis
* Potentially add virtual lines as a means to improve visibility even more

![image](https://user-images.githubusercontent.com/3845743/245100148-f392affa-4d5b-4c46-8bcb-56d9356a53e8.png)
This is an example of manually set colors.

### Contribution
I will try to fix any issues found and welcome any PR for improvment of the plugin!
