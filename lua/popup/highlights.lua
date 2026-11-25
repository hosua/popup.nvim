--- Highlight groups. Every group is a `default = true` link, so a theme or
--- the user wins. Importance colours follow the config rules: error red,
--- warn yellow, ok green, info blue (the Diagnostic groups).
---
--- Call `apply()` whenever a window opens, not only on ColorScheme: NvChad's
--- base46 swaps themes without firing that autocmd.
local M = {}

M.LINKS = {
  PopupNormal = "NormalFloat",
  PopupBorder = "FloatBorder",
  PopupTitle = "Title",
  PopupFooter = "Comment",
  PopupGroup = "Title",
  PopupLabel = "Normal",
  PopupHint = "Comment",
  PopupSelect = "PmenuSel",
  PopupMark = "DiagnosticOk",
  PopupBullet = "Special",
  PopupKey = "Special",
  PopupKeyDesc = "Comment",
  PopupError = "DiagnosticError",
  PopupWarn = "DiagnosticWarn",
  PopupOk = "DiagnosticOk",
  PopupInfo = "DiagnosticInfo",
}

--- Define groups from a name -> link-or-attrs table. A string is a link,
--- a table is a set of attributes (`{ bold = true }`). Always `default`.
--- @param groups table<string, string|table>
function M.define(groups)
  for name, target in pairs(groups) do
    if type(target) == "table" then
      vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", target, { default = true }))
    else
      vim.api.nvim_set_hl(0, name, { link = target, default = true })
    end
  end
end

--- Define the Popup* groups. Idempotent.
function M.apply()
  M.define(M.LINKS)
end

--- 'winhighlight' string from { from, to } pairs, in order.
--- @param pairs_ string[][]
--- @return string
function M.winhl(pairs_)
  local out = {}
  for _, p in ipairs(pairs_) do
    out[#out + 1] = p[1] .. ":" .. p[2]
  end
  return table.concat(out, ",")
end

--- The map every Popup float uses unless the caller gives its own.
M.WINHL = M.winhl {
  { "NormalFloat", "PopupNormal" },
  { "FloatBorder", "PopupBorder" },
  { "FloatTitle", "PopupTitle" },
  { "FloatFooter", "PopupFooter" },
}

return M
