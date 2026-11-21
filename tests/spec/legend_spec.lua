local legend = require "popup.legend"
local hints = require "popup.hints"

describe("legend.key_label", function()
  it("spells keys out", function()
    assert.are.equal("Ctrl+q", legend.key_label "<C-q>")
    assert.are.equal("Enter", legend.key_label "<CR>")
    assert.are.equal("j", legend.key_label "j")
    assert.are.equal("q/<Esc>", legend.key_label "q/<Esc>")
  end)
end)

describe("legend.rows", function()
  it("lays out the list-menu footer with a bullet and spans", function()
    local lines, spans, width = legend.rows {
      { key = "j/k", desc = "move" },
      { key = "<C-q>", desc = "never ask again" },
    }
    assert.are.equal(6, width)
    assert.are.same({ "  • j/k     move", "  • Ctrl+q  never ask again" }, lines)
    assert.are.same({ row = 0, col_start = 2, col_end = 5, hl = "PopupBullet" }, spans[1])
    assert.are.same({ row = 0, col_start = 6, col_end = 9, hl = "PopupKey" }, spans[2])
    assert.are.same({ row = 0, col_start = 14, col_end = 18, hl = "PopupKeyDesc" }, spans[3])
  end)

  it("pads by display width, so wide glyphs still align", function()
    local lines = legend.rows(
      { { key = "⏎", desc = "a" }, { key = "ab", desc = "b" } },
      { bullet = false, indent = 0 }
    )
    assert.are.same({ "⏎   a", "ab  b" }, lines)
  end)
end)

describe("legend.help", function()
  it("builds titled sections with one key column", function()
    local lines, spans = legend.help {
      { "Move", { { "j k", "down / up" } } },
      { "Quit", { { "q", "close" } } },
    }
    assert.are.same({ " Move", "   j k   down / up", "", " Quit", "   q     close" }, lines)
    assert.are.same({ row = 0, col_start = 1, col_end = 5, hl = "PopupGroup" }, spans[1])
    assert.are.same({ row = 1, col_start = 3, col_end = 6, hl = "PopupKey" }, spans[2])
  end)
end)

describe("hints", function()
  it("turns hints into a line whose spans tile it", function()
    local line, spans = hints.line { { "o", "browser" }, { "y", "url" } }
    assert.are.equal("o browser  y url", line)
    assert.are.same({
      { col_start = 0, col_end = 1, hl = "PopupKey" },
      { col_start = 1, col_end = 11, hl = "PopupKeyDesc" },
      { col_start = 11, col_end = 12, hl = "PopupKey" },
      { col_start = 12, col_end = 16, hl = "PopupKeyDesc" },
    }, spans)
  end)

  it("uses the caller's groups", function()
    local _, spans = hints.line({ { "o", "x" } }, { key_hl = "K", action_hl = "A" })
    assert.are.equal("K", spans[1].hl)
    assert.are.equal("A", spans[2].hl)
  end)

  it("drops trailing hints from a narrow footer but keeps `keep` ones", function()
    local chunks = hints.chunks({ { "a", "one" }, { "b", "two" }, { "?", "help", keep = true } }, 14)
    local text = ""
    for _, c in ipairs(chunks) do
      text = text .. c[1]
    end
    assert.is_truthy(text:find("? help", 1, true))
    assert.is_nil(text:find("b two", 1, true))
  end)

  it("wraps by words", function()
    assert.are.same({ "aaa bbb", "ccc" }, hints.wrap("aaa bbb ccc", 8))
  end)

  it("aligns a table and wraps under the action column", function()
    local lines = hints.table({ rows = { { "j", "down" }, { "gg", "first" } } }, { indent = 1, gap = 2 })
    assert.are.same({ " j   down", " gg  first" }, lines)
  end)
end)
