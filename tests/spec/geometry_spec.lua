local geometry = require "popup.geometry"

local env = { columns = 100, lines = 40, cmdheight = 1, laststatus = 3, showtabline = 1, tabpages = 1 }

describe("geometry", function()
  it("editor subtracts cmdline, statusline and a tabline only when shown", function()
    assert.are.same({ width = 100, height = 38 }, geometry.editor(env))
    local two_tabs = vim.tbl_extend("force", env, { tabpages = 2 })
    assert.are.same({ width = 100, height = 37 }, geometry.editor(two_tabs))
  end)

  it("centered clamps to the area minus border room", function()
    assert.are.same({ row = 17, col = 29, width = 40, height = 2 }, geometry.centered(env, 40, 2))
    local c = geometry.centered(env, 500, 500)
    assert.are.same({ 96, 36 }, { c.width, c.height })
  end)

  it("fractional takes fractions or cells", function()
    local g = geometry.fractional(env, 0.5, 10)
    assert.are.same({ width = 50, height = 10, row = 14, col = 25 }, g)
  end)

  it("menu is content + 2 wide and capped at the height ratio", function()
    assert.are.same({ row = 15, col = 29, width = 42, height = 10 }, geometry.menu(env, 40, 10, 0.7))
    assert.are.equal(28, geometry.menu(env, 40, 100, 0.7).height)
  end)

  it("toast centres or sits bottom right", function()
    assert.are.same({ row = 17, col = 39, width = 20, height = 3 }, geometry.toast(20, 3, env, "center"))
    assert.are.same({ row = 33, col = 77, width = 20, height = 3 }, geometry.toast(20, 3, env, "bottom_right"))
  end)

  it("list sits one row above centre", function()
    local g = geometry.list(env, 60, 10)
    assert.are.same({ 60, 10, 14, 20 }, { g.width, g.height, g.row, g.col })
  end)

  it("fit cuts the middle", function()
    assert.are.equal("abc", geometry.fit("abc", 10))
    assert.are.equal("ab…yz", geometry.fit("abcdefghijklmnopqrstuvwxyz", 5))
  end)
end)
