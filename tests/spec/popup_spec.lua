local popup = require "popup"

describe("popup.create / move / close", function()
  after_each(function()
    popup.clear()
  end)

  it("opens a float with the text and returns the win id", function()
    local win, info = popup.create({ "hello", "world" }, { line = 3, col = 4, border = {}, title = "T" })
    assert.is_true(vim.api.nvim_win_is_valid(win))
    assert.are.same({ "hello", "world" }, vim.api.nvim_buf_get_lines(info.bufnr, 0, -1, false))
    local cfg = vim.api.nvim_win_get_config(win)
    assert.are.same({ 5, 2 }, { cfg.width, cfg.height })
    assert.are.equal("editor", cfg.relative)
    assert.are.same({ 2, 3 }, { cfg.row, cfg.col })
  end)

  it("does not steal focus unless enter = true", function()
    local before = vim.api.nvim_get_current_win()
    local win = popup.create("x", {})
    assert.are.equal(before, vim.api.nvim_get_current_win())
    popup.close(win)
    local w2 = popup.create("x", { enter = true })
    assert.are.equal(w2, vim.api.nvim_get_current_win())
  end)

  it("moves and resizes with Vim option names", function()
    local win = popup.create("abc", { line = 2, col = 2 })
    popup.move(win, { line = 10, col = 12, minwidth = 8 })
    local cfg = vim.api.nvim_win_get_config(win)
    assert.are.same({ 9, 11, 8 }, { cfg.row, cfg.col, cfg.width })
  end)

  it("refuses to move a window it did not create", function()
    assert.has_error(function()
      popup.move(vim.api.nvim_get_current_win(), {})
    end)
  end)

  it("runs callback and finalize_callback once with the result", function()
    local calls = {}
    local win = popup.create("x", {
      callback = function(id, r)
        calls[#calls + 1] = { "cb", id, r }
      end,
      finalize_callback = function(id, r)
        calls[#calls + 1] = { "fin", id, r }
      end,
    })
    popup.close(win, 7)
    popup.close(win, 8)
    assert.are.same({ { "cb", win, 7 }, { "fin", win, 7 } }, calls)
    assert.is_false(vim.api.nvim_win_is_valid(win))
  end)

  it("pads inside the border and settext keeps the padding", function()
    local win, info = popup.create("a", { padding = { 1, 1, 1, 1 } })
    assert.are.same({ "", " a ", "" }, vim.api.nvim_buf_get_lines(info.bufnr, 0, -1, false))
    popup.settext(win, { "bb" })
    assert.are.same({ "", " bb ", "" }, vim.api.nvim_buf_get_lines(info.bufnr, 0, -1, false))
    assert.are.equal(4, popup.getpos(win).width)
  end)

  it("hides and shows", function()
    local win = popup.create("x", {})
    popup.hide(win)
    assert.is_false(popup.getpos(win).visible)
    popup.show(win)
    assert.is_true(popup.getpos(win).visible)
  end)

  it("closes after `time` ms", function()
    local win = popup.create("x", { time = 20 })
    vim.wait(500, function()
      return not vim.api.nvim_win_is_valid(win)
    end)
    assert.is_false(vim.api.nvim_win_is_valid(win))
  end)

  it("accepts a buffer number", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "three" })
    local win = popup.create(buf, {})
    assert.are.equal(buf, vim.api.nvim_win_get_buf(win))
    assert.are.equal(5, vim.api.nvim_win_get_config(win).width)
  end)

  it("warns once about options Neovim cannot do", function()
    local seen = {}
    local notify_once = vim.notify_once
    vim.notify_once = function(msg)
      seen[#seen + 1] = msg
    end
    popup.create("x", { drag = true })
    vim.notify_once = notify_once
    assert.are.equal(1, #seen)
    assert.is_truthy(seen[1]:find("drag", 1, true))
  end)
end)

describe("popup lazy components", function()
  it("loads components on first use", function()
    assert.is_function(popup.list_menu.open)
    assert.is_function(popup.float.open)
    assert.is_function(popup.legend.rows)
  end)
end)
