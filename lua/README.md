# block.nvim 
![image](https://github.com/HampusHauffman/bionic.nvim/assets/3845743/8ebb44af-9a59-43f6-b80a-4ea24c452f1a)
Screenshot is taken on `Kitty` terminal with `font_family FiraCode Nerd Font` and `dracula`as colortheme
## ⚡️ Requirements
Neovim Stable release
## 🚀 Usage
#### `:Bloc` Toggle current buffer
#### `:BlockOn` On current buffer
#### `:BlockOff` Off current buffer

## 📦 Installation
### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
"HampusHauffman/bloc.nvim",
```
### [Packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use "HampusHauffman/bloc.nvim",
```
## ⚙️ Configuration
Defaults: 
```lua
---@class Opts
---@field percent number  -- The change in color. 0.8 would change each box to be 20% darker than the last and 1.2 would be 20% brighter
---@field depth number -- De depths of changing colors. Defaults to 3
---@field colors string [] | nil -- A list of colors to use instead. if this is not nil depth and percent are not used

    require("block").setup({
        percent = 0.8,
        depth = 3,
        colors = nil
        
    })
```
## ⁉️ Motivation
I feel this helps with my dylexia, especially in dense texts such as the vim doc / help files
![image](https://github.com/HampusHauffman/bionic.nvim/assets/3845743/ef7be9fe-c91c-4c01-bb61-2e0b261bdffb)

## 📝 Todo
* Add Configuration option
* Add vim docs for usage
