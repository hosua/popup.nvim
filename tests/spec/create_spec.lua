local create = require "popup.create"

local env = {
  columns = 100,
  lines = 40,
  cmdheight = 1,
  laststatus = 3,
  showtabline = 1,
  tabpages = 1,
  cursor_row = 10,
  cursor_col = 20,
}

describe("create.config", function()
  it("centres when no line/col is given", function()
    local c = create.config({ width = 20, height = 4 }, {}, env)
    assert.are.same({ 40, 18, 20, 4 }, { c.col, c.row, c.width, c.height })
  end)

  it("anchors by pos at line/col (1-based screen cells)", function()
    local tl = create.config({ width = 10, height = 2 }, { line = 5, col = 5 }, env)
    assert.are.same({ 4, 4 }, { tl.row, tl.col })
    local br = create.config({ width = 10, height = 2 }, { line = 20, col = 30, pos = "botright" }, env)
    assert.are.same({ 18, 20 }, { br.row, br.col })
  end)

  it("counts the border cells in the outer box", function()
    local c = create.config({ width = 10, height = 2 }, { line = 20, col = 30, pos = "botright", border = {} }, env)
    assert.are.same({ 16, 18 }, { c.row, c.col })
    assert.are.equal(10, c.width)
  end)

  it("resolves cursor, cursor+N and cursor-N", function()
    local c = create.config({ width = 5, height = 1 }, { line = "cursor+2", col = "cursor-3" }, env)
    assert.are.same({ 11, 16 }, { c.row, c.col })
  end)

  it("clamps size with min/max and wraps height", function()
    local c = create.config(
      { width = 30, height = 1 },
      { maxwidth = 10, minheight = 2, lines = { string.rep("x", 30) } },
      env
    )
    assert.are.same({ 10, 3 }, { c.width, c.height })
  end)

  it("keeps the popup on screen unless fixed", function()
    local c = create.config({ width = 10, height = 2 }, { line = 100, col = 100 }, env)
    assert.are.same({ 38, 90 }, { c.row, c.col })
    local f = create.config({ width = 10, height = 2 }, { line = 100, col = 100, fixed = true }, env)
    assert.are.same({ 99, 99 }, { f.row, f.col })
  end)

  it("puts the title in the border, only when there is one", function()
    assert.are.equal("Hi", create.config({ width = 5, height = 1 }, { title = "Hi", border = {} }, env).title)
    assert.is_nil(create.config({ width = 5, height = 1 }, { title = "Hi" }, env).title)
  end)
end)

describe("create helpers", function()
  it("pads text", function()
    assert.are.same({ "", " a ", "" }, create.pad({ "a" }, { 1, 1, 1, 1 }))
    assert.are.same({ "a" }, create.pad({ "a" }, nil))
  end)

  it("finds the word under the cursor", function()
    assert.are.same({ 5, 7 }, { create.word_range("foo bar.baz", 5, false) })
    assert.are.same({ 5, 11 }, { create.word_range("foo bar.baz", 5, true) })
  end)

  it("counts wrapped rows", function()
    assert.are.equal(3, create.wrapped_height({ "aaaa", "bb" }, 2))
  end)
end)
