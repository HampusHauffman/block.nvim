" Title:        Bionic
" Description:  A plugin for Bionic Reading

" Exposes the plugin's functions for use as commands in Neovim.
command! -nargs=0 Bionic lua require("block").toggle()
command! -nargs=0 BionicOff lua require("block").off()
command! -nargs=0 BionicOn lua require("block").on()
