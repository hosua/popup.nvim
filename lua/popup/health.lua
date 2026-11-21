--- :checkhealth popup
local M = {}

function M.check()
  local h = vim.health
  h.start "popup"
  if vim.fn.has "nvim-0.11" == 1 then
    h.ok("Neovim " .. tostring(vim.version()))
  else
    h.error "Neovim >= 0.11 is required (native float borders, 'winborder')"
  end
  local src = debug.getinfo(require("popup").setup, "S").source:gsub("^@", "")
  h.info("loaded from " .. vim.fn.fnamemodify(src, ":~"))
  if pcall(require, "plenary") then
    h.ok "plenary.nvim found (needed to run the tests)"
  else
    h.warn "plenary.nvim not found: only needed for `make test`"
  end
  require("popup.highlights").apply()
  for name in pairs(require("popup.highlights").LINKS) do
    local hl = vim.api.nvim_get_hl(0, { name = name })
    if hl.link == nil and next(hl) == nil then
      h.warn("highlight group " .. name .. " is not defined")
    end
  end
  h.ok "Popup* highlight groups defined"
end

return M
