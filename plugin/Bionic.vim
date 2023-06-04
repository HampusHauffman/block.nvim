" Title:       block plugin 
" Description:  

" Exposes the plugin's functions for use as commands in Neovim.
command! -nargs=0 Block lua require("block").toggle()
command! -nargs=0 BlockOff lua require("block").off()
command! -nargs=0 BlockOn lua require("block").on()
