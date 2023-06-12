# block.nvim 
![image](https://user-images.githubusercontent.com/3845743/245099616-f6259c1d-3901-4860-8b4a-21e63f2f00db.png)
Screenshot is taken on `Kitty` terminal with `font_family FiraCode Nerd Font` and `dracula` as colortheme.
## ⚡️ Requirements
Neovim Stable release
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
        require("block").setup({
            percent = 0.8,
            depth = 3,
        })
    end
},
```
## ⚙️ Configuration / Setup
Defaults: 
```lua
---@field percent number  -- The change in color. 0.8 would change each box to be 20% darker than the last and 1.2 would be 20% brighter
---@field depth number -- De depths of changing colors. Defaults to 3
---@field colors string [] | nil -- A list of colors to use instead. if this is not nil depth and percent are not used

    require("block").setup({
        percent = 0.8,
        depth = 3,
        colors = nil
--        colors = {
--            "#ff0000"
--            "#00ff00"
--            "#0000ff"
--        }
    })
```

## ⁉️ Motivation
This plugin is something i've wanted for a while but havent found any previous implementation of in neovim. 
There is [Blockman](https://marketplace.visualstudio.com/items?itemName=leodevbro.blockman) for VsCode which however.

## 📝 Todo
* Add vim docs for usage

![image](https://user-images.githubusercontent.com/3845743/245100148-f392affa-4d5b-4c46-8bcb-56d9356a53e8.png)
This is an example of manually set colors.
