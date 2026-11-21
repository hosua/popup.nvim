--- popup: public API.
---
--- Vim-style popups (port of nvim-lua/popup.nvim):
---   popup.create(what, vim_options) -> win_id, { win_id, bufnr }
---   popup.move(win_id, vim_options)
---   popup.close(win_id [, result]), popup.clear(), popup.hide(id), popup.show(id)
---   popup.settext(id, text), popup.getpos(id), popup.getoptions(id)
---
--- Shared UI components, loaded on first use:
---   popup.float, popup.list_menu, popup.confirm, popup.legend, popup.hints,
---   popup.borders, popup.geometry, popup.highlights
---
--- setup() is optional: every entry point resolves the config on first use.
local create = require "popup.create"

local M = {
  create = create.create,
  move = create.move,
  close = create.close,
  clear = create.clear,
  hide = create.hide,
  show = create.show,
  settext = create.settext,
  getpos = create.getpos,
  getoptions = create.getoptions,
}

--- @param opts table|nil user overrides, merged over config.defaults
function M.setup(opts)
  require("popup.config").resolve(opts)
end

local LAZY = {
  float = true,
  list_menu = true,
  confirm = true,
  legend = true,
  hints = true,
  borders = true,
  geometry = true,
  highlights = true,
}

return setmetatable(M, {
  __index = function(t, k)
    if LAZY[k] then
      local m = require("popup." .. k)
      rawset(t, k, m)
      return m
    end
  end,
})
