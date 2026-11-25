local list_menu = require "popup.list_menu"

local spec = {
  header = { "intro", { text = "careful", level = "warn" } },
  groups = {
    { title = "Installed", items = { { label = "stylua", hint = "keywords: lua", mark = true }, { label = "x" } } },
    { title = "Other", hide_count = true, items = { { label = "y", level = "ok" } } },
  },
  keys = { { key = "<C-q>", desc = "never", fn = function() end } },
  footer = { "free text" },
}

describe("list_menu.build", function()
  local lines, marks, item_rows, items = list_menu.build(spec)

  it("lays out header, groups, legend and footer", function()
    assert.are.same({
      "intro",
      "careful",
      "",
      "Installed (2)",
      "  • " .. list_menu.MARK_ICON .. " stylua (keywords: lua)",
      "  •    x",
      "",
      "Other",
      "  •    y",
      "",
      "  • j/k      move",
      "  • Enter    select",
      "  • Ctrl+q   never",
      "  • q/<Esc>  dismiss",
      "",
      "free text",
    }, lines)
  end)

  it("maps items to 1-based rows", function()
    assert.are.same({ 5, 6, 9 }, item_rows)
    assert.are.equal(3, #items)
  end)

  it("colours the header by level and groups by role", function()
    local function find(row, group)
      for _, m in ipairs(marks) do
        if m.row == row and m.hl == group then
          return m
        end
      end
    end
    assert.is_truthy(find(0, "PopupHint"))
    assert.is_truthy(find(1, "PopupWarn"))
    assert.is_truthy(find(3, "PopupGroup"))
    assert.is_truthy(find(8, "PopupOk"))
    assert.is_truthy(find(4, "PopupMark"))
    assert.is_truthy(find(12, "PopupKey"))
  end)

  it("lets the caller rename groups", function()
    local _, m = list_menu.build(vim.tbl_extend("force", spec, { hl = { group = "MyGroup" } }))
    local seen = false
    for _, mark in ipairs(m) do
      seen = seen or mark.hl == "MyGroup"
    end
    assert.is_true(seen)
  end)

  it("frees the dismiss keys when asked", function()
    local l = list_menu.build(vim.tbl_extend("force", spec, { dismiss_keys = {}, footer = {} }))
    assert.are.equal("  • Ctrl+q  never", l[#l])
  end)
end)

describe("list_menu border_legend", function()
  local spec = {
    title = "T",
    border_legend = true,
    groups = { { title = "G", items = { { id = 1, label = "a" } } } },
    keys = { { key = "x", desc = "reset", fn = function() end } },
  }

  it("keeps the legend out of the rows", function()
    local lines = list_menu.build(spec)
    for _, l in ipairs(lines) do
      assert.is_nil(l:find("dismiss", 1, true))
    end
    local plain = list_menu.build(vim.tbl_extend("force", spec, { border_legend = false }))
    assert.is_true(#plain > #lines)
  end)

  it("builds the one-line border legend with every key", function()
    local chunks, width = list_menu.border_footer(spec)
    local text = ""
    for _, c in ipairs(chunks) do
      text = text .. c[1]
    end
    assert.are.equal(" j/k move  Enter select  x reset  q/<Esc> dismiss ", text)
    assert.are.equal(vim.fn.strdisplaywidth(text), width)
  end)

  it("opens a window at least as wide as the legend, footer in the border", function()
    local h = list_menu.open(spec)
    local _, width = list_menu.border_footer(spec)
    local cfg = vim.api.nvim_win_get_config(h.win)
    assert.is_true(cfg.width >= width)
    assert.is_table(cfg.footer)
    h.close()
  end)
end)
