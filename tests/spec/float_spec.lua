local float = require "popup.float"
local legend = require "popup.legend"
local confirm = require "popup.confirm"
local list_menu = require "popup.list_menu"

describe("float.open", function()
  it("matches the session-mgr window: title, footer, zindex, winhighlight", function()
    local f = float.open {
      rect = { row = 2, col = 3, width = 20, height = 4 },
      title = " t ",
      footer = " f ",
      border = "rounded",
      zindex = 60,
      noautocmd = true,
      lines = { "a", "b" },
      spans = { { row = 0, col_start = 0, col_end = 1, hl = "PopupKey" } },
    }
    local cfg = vim.api.nvim_win_get_config(f.win)
    assert.are.equal(60, cfg.zindex)
    assert.are.equal("center", cfg.title_pos)
    assert.are.equal("left", cfg.footer_pos)
    assert.are.equal(
      "NormalFloat:PopupNormal,FloatBorder:PopupBorder,FloatTitle:PopupTitle,FloatFooter:PopupFooter",
      vim.wo[f.win].winhighlight
    )
    assert.is_false(vim.bo[f.buf].modifiable)
    local marks = vim.api.nvim_buf_get_extmarks(f.buf, f.ns, 0, -1, { details = true })
    assert.are.equal("PopupKey", marks[1][4].hl_group)
    float.close(f)
    assert.is_false(float.is_open(f))
  end)

  it("drops title and footer when there is no border", function()
    local f = float.open { rect = { row = 0, col = 0, width = 5, height = 1 }, title = "t", border = "none" }
    assert.is_nil(vim.api.nvim_win_get_config(f.win).title)
    float.close(f)
  end)

  it("paints 1-based rows and end-of-line spans", function()
    local f = float.open { rect = { row = 0, col = 0, width = 10, height = 2 } }
    float.paint(
      f,
      { lines = { "abc", "def" }, spans = { { row = 2, col_start = 1, col_end = -1, hl = "PopupKey" } } },
      { base = 1 }
    )
    local m = vim.api.nvim_buf_get_extmarks(f.buf, f.ns, 0, -1, { details = true })
    assert.are.same({ 1, 1 }, { m[1][2], m[1][3] })
    assert.are.equal(2, m[1][4].end_row)
    float.close(f)
  end)

  it("closes on leave and calls on_close", function()
    local closed = false
    local f = float.open {
      rect = { row = 0, col = 0, width = 5, height = 1 },
      close_on_leave = true,
      on_close = function()
        closed = true
      end,
    }
    vim.cmd "wincmd p"
    vim.cmd "split"
    vim.wait(200, function()
      return closed
    end)
    assert.is_false(float.is_open(f))
    assert.is_true(closed)
    vim.cmd "only"
  end)
end)

describe("confirm", function()
  it("builds chunks into lines and spans", function()
    local out = confirm.build {
      title = "t",
      lines = { { { "  M  ", "PopupWarn" }, { "init.lua" } } },
      choices = { { key = "w", label = "write", value = "w" }, { key = "n", label = "no", value = "n", danger = true } },
    }
    assert.are.same({ "  M  init.lua", "", "  w  write", "  n  no" }, out.lines)
    assert.are.equal("PopupError", out.spans[#out.spans].hl)
    assert.are.equal(33, out.width) -- the default footer is wider than the body
  end)

  it("answers with the choice value, nil on cancel", function()
    local got = "unset"
    local f = confirm.open {
      title = "t",
      choices = { { key = "w", label = "write", value = "write" } },
      on_choice = function(v)
        got = v
      end,
    }
    vim.api.nvim_feedkeys("w", "x", false)
    vim.wait(200, function()
      return got ~= "unset"
    end)
    assert.are.equal("write", got)
    assert.is_false(float.is_open(f))
  end)
end)

describe("list_menu.open", function()
  it("opens a bordered popup, navigates and selects", function()
    local picked
    local h = list_menu.open {
      title = "Pick",
      groups = { { title = "G", items = { { id = 1, label = "a" }, { id = 2, label = "b" } } } },
      on_select = function(item, close)
        picked = item.id
        close()
      end,
    }
    local cfg = vim.api.nvim_win_get_config(h.win)
    assert.are.equal(" Pick ", cfg.title[1][1])
    assert.are.equal("center", cfg.title_pos)
    assert.are.equal("FloatBorder:PopupBorder,FloatTitle:PopupTitle,CursorLine:Visual", vim.wo[h.win].winhighlight)
    assert.is_true(vim.wo[h.win].cursorline)
    assert.are.equal(2, vim.api.nvim_win_get_cursor(h.win)[1])
    vim.api.nvim_feedkeys("jj\r", "x", false)
    assert.are.equal(2, picked)
    assert.is_false(vim.api.nvim_win_is_valid(h.win))
  end)

  it("warns instead of opening an empty menu", function()
    local warned
    local notify = vim.notify
    vim.notify = function(msg)
      warned = msg
    end
    assert.is_nil(list_menu.open { groups = { { title = "G", items = {} } } })
    vim.notify = notify
    assert.is_truthy(warned:find("nothing to show", 1, true))
  end)
end)

describe("confirm.build in menu mode", function()
  local choices = {
    { key = "y", label = "Load it", value = "yes", remember_key = "Y" },
    { key = "n", label = "Start empty", value = "no", remember_key = "N" },
  }

  it("turns choices into label rows with no blank line before them", function()
    local out = confirm.build {
      title = "t",
      menu = true,
      lines = { { { "  Project  x" } }, { { "" } } },
      choices = choices,
    }
    assert.are.same({ "  Project  x", "", "  Load it  ", "  Start empty  " }, out.lines)
    assert.are.same({ 2, 3 }, out.choice_rows)
    assert.are.equal("PopupSelect", out.select_hl)
  end)

  it("lists j/k, Enter, the choice and remember keys and q/Esc/C-c in the default footer", function()
    local out = confirm.build { title = "t", menu = true, choices = choices, remember_keys = { "<S-CR>" } }
    local text = ""
    for _, c in ipairs(out.footer) do
      text = text .. c[1]
    end
    assert.are.equal(
      " j/k move  ⏎ pick  y Load it  Y Load it + remember  n Start empty  N Start empty + remember  S-CR pick + remember  q/Esc/C-c cancel ",
      text
    )
  end)

  it("takes the given footer and widens the window to it", function()
    local footer = legend.footer { { "a", "one" }, { "b", "a rather long description" } }
    local out = confirm.build { title = "t", menu = true, choices = choices, footer = footer }
    assert.are.same(footer, out.footer)
    assert.are.equal(select(2, legend.footer { { "a", "one" }, { "b", "a rather long description" } }), out.width)
  end)

  it("leaves plain mode as it was", function()
    local out = confirm.build { title = "t", choices = choices }
    assert.are.same({ "  y  Load it", "  n  Start empty" }, out.lines)
    assert.is_nil(out.select_hl)
    local text = ""
    for _, c in ipairs(out.footer) do
      text = text .. c[1]
    end
    assert.are.equal(
      " y Load it  Y Load it + remember  n Start empty  N Start empty + remember  q/Esc/C-c cancel ",
      text
    )
  end)
end)

describe("legend.footer", function()
  it("joins pairs two spaces apart, key bright and desc grey, padded by a space", function()
    local chunks, width = legend.footer { { "j/k", "move" }, { key = "⏎", desc = "pick" } }
    assert.are.same({
      { " ", "PopupFooter" },
      { "j/k", "PopupKey" },
      { " move  ", "PopupFooter" },
      { "⏎", "PopupKey" },
      { " pick ", "PopupFooter" },
    }, chunks)
    assert.are.equal(vim.fn.strdisplaywidth " j/k move  ⏎ pick ", width)
  end)

  it("takes other groups", function()
    local chunks = legend.footer({ { "q", "quit" } }, { key_hl = "K", desc_hl = "D" })
    assert.are.same({ { " ", "D" }, { "q", "K" }, { " quit ", "D" } }, chunks)
  end)
end)
