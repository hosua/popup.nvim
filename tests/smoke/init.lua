local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:gsub("^@", ""), ":p:h:h:h")
vim.opt.runtimepath:prepend(root)
vim.cmd "runtime plugin/popup.lua"
require("popup").setup {}
