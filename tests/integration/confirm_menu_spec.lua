-- confirm.open in menu mode, driven with real keys. Nothing touches disk.
local confirm = require "popup.confirm"
local float = require "popup.float"

local CHOICES = {
  { key = "y", label = "Load it", value = "yes", remember_key = "Y" },
  { key = "n", label = "Start empty", value = "no", remember_key = "N" },
  { key = "m", label = "Maybe", value = "maybe" },
}

local function run(keys, extra)
  local got, info
  local opts = vim.tbl_extend("force", {
    title = "t",
    menu = true,
    default = 2,
    choices = CHOICES,
    remember_keys = { "<S-CR>" },
    on_choice = function(v, i)
      got, info = v, i
    end,
  }, extra or {})
  local f = confirm.open(opts)
  vim.api.nvim_feedkeys(vim.keycode(keys), "x", false)
  vim.wait(300, function()
    return info ~= nil
  end)
  return got, info, f
end

local function selected_row(f)
  return vim.api.nvim_win_get_cursor(f.win)[1]
end

describe("confirm menu", function()
  after_each(function()
    vim.cmd "only"
  end)

  it("starts on opts.default and marks the row", function()
    local f = confirm.open { title = "t", menu = true, default = 2, choices = CHOICES, on_choice = function() end }
    assert.are.equal(2, selected_row(f))
    local marks = vim.api.nvim_buf_get_extmarks(
      f.buf,
      vim.api.nvim_create_namespace "popup_confirm_select",
      0,
      -1,
      { details = true }
    )
    assert.are.equal(1, #marks)
    assert.are.equal(1, marks[1][2])
    assert.are.equal("PopupSelect", marks[1][4].line_hl_group)
    float.close(f)
  end)

  it("moves with j and k, clamped at the ends", function()
    local f = confirm.open { title = "t", menu = true, default = 1, choices = CHOICES, on_choice = function() end }
    vim.api.nvim_feedkeys("jj", "x", false)
    assert.are.equal(3, selected_row(f))
    vim.api.nvim_feedkeys("j", "x", false)
    assert.are.equal(3, selected_row(f))
    vim.api.nvim_feedkeys("kkk", "x", false)
    assert.are.equal(1, selected_row(f))
    float.close(f)
  end)

  it("puts the cursor back after any other motion", function()
    local f = confirm.open { title = "t", menu = true, default = 2, choices = CHOICES, on_choice = function() end }
    for _, motion in ipairs { "gg", "G", "<Down>", "<Up>", "$", "2G" } do
      vim.api.nvim_feedkeys(vim.keycode(motion), "x", false)
      vim.api.nvim_exec_autocmds("CursorMoved", { buffer = f.buf })
      assert.are.equal(2, selected_row(f), motion)
    end
    float.close(f)
  end)

  it("ignores every other motion", function()
    for _, motion in ipairs { "gg", "G", "<Down>", "<Up>", "w", "$", "<C-d>", "2G" } do
      local got, info = run(motion .. "<CR>", { default = 2 })
      assert.are.equal("no", got, motion)
      assert.is_false(info.remember, motion)
    end
  end)

  it("answers <CR> with the selected row, j/k included", function()
    local got = run("j<CR>", { default = 1 })
    assert.are.equal("no", got)
    got = run("jk<CR>", { default = 2 })
    assert.are.equal("no", got)
    got = run("<CR>", { default = 3 })
    assert.are.equal("maybe", got)
  end)

  it("answers a choice key directly and does not remember", function()
    local got, info = run("y", { default = 2 })
    assert.are.equal("yes", got)
    assert.is_false(info.remember)
  end)

  it("remembers on a choice's remember_key", function()
    local got, info = run "Y"
    assert.are.equal("yes", got)
    assert.is_true(info.remember)
    got, info = run "N"
    assert.are.equal("no", got)
    assert.is_true(info.remember)
  end)

  it("remembers the selected row on opts.remember_keys", function()
    local got, info = run("k<S-CR>", { default = 2 })
    assert.are.equal("yes", got)
    assert.is_true(info.remember)
  end)

  it("cancels with nil and no remember", function()
    for _, key in ipairs { "q", "<Esc>" } do
      local got, info = run(key)
      assert.is_nil(got)
      assert.is_false(info.remember)
    end
  end)

  it("shows the given footer at footer_pos and fits the window to it", function()
    local legend = require "popup.legend"
    local footer, width = legend.footer { { "a", "one" }, { "b", "an unusually long description of b to force width" } }
    local f = confirm.open {
      title = "t",
      menu = true,
      choices = CHOICES,
      footer = footer,
      footer_pos = "right",
      on_choice = function() end,
    }
    local cfg = vim.api.nvim_win_get_config(f.win)
    assert.are.equal("right", cfg.footer_pos)
    assert.is_true(cfg.width >= width)
    float.close(f)
  end)

  it("still answers in plain mode and passes remember = false", function()
    local got, info
    confirm.open {
      title = "t",
      choices = CHOICES,
      on_choice = function(v, i)
        got, info = v, i
      end,
    }
    vim.api.nvim_feedkeys("m", "x", false)
    vim.wait(300, function()
      return info ~= nil
    end)
    assert.are.equal("maybe", got)
    assert.is_false(info.remember)
  end)
end)
