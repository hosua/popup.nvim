--- :Popup <sub> dispatcher and its completion.
local M = {}

--- @type table<string, fun(args: string[], bang: boolean)>
M.subcommands = {
  -- A sample list menu, to see the borders, colours and key legend.
  demo = function()
    require("popup.list_menu").open {
      title = "popup.nvim demo",
      header = { "Sample list menu", { text = "colours follow the theme", level = "info" } },
      groups = {
        {
          title = "Installed",
          items = {
            { id = 1, label = "stylua", hint = "keywords: lua", mark = true, level = "ok" },
            { id = 2, label = "prettier", hint = "keywords: js, css" },
          },
        },
        { title = "Available", items = { { id = 3, label = "shfmt", hint = "keywords: sh", level = "warn" } } },
      },
      keys = { { key = "<C-q>", desc = "never ask again", fn = function() end } },
      footer = { { text = "nothing here is saved", level = "warn" } },
      on_select = function(item, close)
        close()
        vim.notify("popup demo: picked " .. item.label)
      end,
    }
  end,
}

--- @param fargs string[]
--- @param bang boolean
function M.dispatch(fargs, bang)
  local sub = fargs[1]
  local fn = sub and M.subcommands[sub]
  if not fn then
    local names = vim.tbl_keys(M.subcommands)
    table.sort(names)
    vim.notify(
      ("popup: unknown subcommand %q (have: %s)"):format(tostring(sub), table.concat(names, ", ")),
      vim.log.levels.ERROR
    )
    return
  end
  fn(vim.list_slice(fargs, 2), bang)
end

--- @return string[]
function M.complete(arglead, cmdline, _)
  local words = vim.split(cmdline, "%s+")
  if #words > 2 then
    return {}
  end
  local names = vim.tbl_keys(M.subcommands)
  table.sort(names)
  return vim.tbl_filter(function(n)
    return vim.startswith(n, arglead)
  end, names)
end

return M
