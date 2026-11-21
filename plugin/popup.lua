-- Defines :Popup at startup without loading the plugin's Lua modules.
-- Everything heavy is required inside the callbacks, so a lazy.nvim
-- `cmd = { "Popup" }` stub and this file agree on the same entry point.
if vim.g.loaded_popup then
  return
end
vim.g.loaded_popup = true

vim.api.nvim_create_user_command("Popup", function(args)
  require("popup.commands").dispatch(args.fargs, args.bang)
end, {
  nargs = "*",
  bang = true,
  desc = "popup",
  complete = function(arglead, cmdline, pos)
    return require("popup.commands").complete(arglead, cmdline, pos)
  end,
})
