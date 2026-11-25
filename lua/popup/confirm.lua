--- Small modal floats. `open` is non-blocking (a few lines, keys that answer
--- it, ported from session-mgr's ui/confirm.lua). `choose` blocks on keys
--- like confirm() does (ported from devdocs' float.choose).
---
---   confirm.open {
---     title = "2 unsaved buffers", danger = true,
---     lines = { { { "  M  ", "PopupWarn" }, { "init.lua" } }, ... },   -- chunks per line
---     choices = { { key = "w", label = "write all & load", value = "write" }, ... },
---     on_choice = function(value, info) end,   -- value is nil when cancelled (q / <Esc> / <C-c>)
---     hl = { key = "PopupKey", danger = "PopupError", footer = "PopupFooter", select = "PopupSelect" },
---     winhl = "...",                     -- default highlights.WINHL
---   }
---
--- `info.remember` is true when the answer came from a remember key, false
--- otherwise (also on cancel).
---
--- Menu mode (`menu = true`) turns the choices into rows you move over:
---   * the current row has the `hl.select` highlight; `opts.default` is the
---     index of the starting row (default 1)
---   * `j` / `k` move between the rows, clamped at both ends (no wrap), and
---     take a count. Nothing else moves the selection: a CursorMoved autocmd
---     snaps the cursor back, so arrows, gg, G and the mouse do nothing
---   * `<CR>` answers with the selected row's value. Each choice's `key`
---     still answers directly, without the row being selected first
---   * `choice.remember_key` (say "Y") answers that choice with
---     `remember = true`. `opts.remember_keys` (say { "<S-CR>" }) answers the
---     selected row with `remember = true`
---   * the rows show the label only. Without `opts.footer` the border lists
---     j/k, Enter, every choice key and q
---
--- `opts.footer` (chunks, see popup.legend.footer) replaces the default
--- ` q cancel ` footer in either mode; `opts.footer_pos` is "left" (default),
--- "center" or "right". The window is at least as wide as its footer.
local float = require "popup.float"
local geometry = require "popup.geometry"
local highlights = require "popup.highlights"
local legend = require "popup.legend"

local M = {}

local HL = { key = "PopupKey", danger = "PopupError", footer = "PopupFooter", select = "PopupSelect" }
local NS = vim.api.nvim_create_namespace "popup_confirm_select"

local function chunks_width(chunks)
  local w = 0
  for _, c in ipairs(chunks or {}) do
    w = w + vim.fn.strdisplaywidth(c[1])
  end
  return w
end

--- Pure: chunks -> lines + spans, plus the choice rows and the width wanted.
--- `choice_rows` holds the 0-based buffer row of each choice (menu mode and
--- plain mode alike). `footer` is the footer chunks that will be shown.
--- @param opts table see the file header
--- @return { lines: string[], spans: table[], line_hl: table, width: integer, choice_rows: integer[], footer: table[], select_hl: string|nil }
function M.build(opts)
  local hl = vim.tbl_extend("force", HL, opts.hl or {})
  local lines, spans = {}, {}
  local function push(chunks)
    local text = ""
    for _, c in ipairs(chunks) do
      if c[2] and c[1] ~= "" then
        spans[#spans + 1] = { row = #lines, col_start = #text, col_end = #text + #c[1], hl = c[2] }
      end
      text = text .. c[1]
    end
    lines[#lines + 1] = text
  end
  for _, l in ipairs(opts.lines or {}) do
    push(l)
  end
  if #lines > 0 and not opts.menu then
    push {}
  end
  local choice_rows = {}
  for _, c in ipairs(opts.choices) do
    choice_rows[#choice_rows + 1] = #lines
    if opts.menu then
      push { { "  " .. c.label .. "  ", c.danger and hl.danger or nil } }
    else
      push { { "  " }, { c.key, c.danger and hl.danger or hl.key }, { "  " .. c.label } }
    end
  end
  local footer = opts.footer
  if not footer then
    if opts.menu then
      local entries = { { "j/k", "move" }, { "⏎", "pick" } }
      for _, c in ipairs(opts.choices) do
        entries[#entries + 1] = { c.key, c.label }
      end
      entries[#entries + 1] = { "q", "cancel" }
      footer = legend.footer(entries, { key_hl = hl.key, desc_hl = hl.footer })
    else
      footer = { { " q", hl.key }, { " cancel ", hl.footer } }
    end
  end
  local width = vim.fn.strdisplaywidth(opts.title or "") + 4
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l) + 2)
  end
  width = math.max(width, chunks_width(footer))
  return {
    lines = lines,
    spans = spans,
    line_hl = {},
    width = width,
    choice_rows = choice_rows,
    footer = footer,
    select_hl = opts.menu and hl.select or nil,
  }
end

--- @param opts table see the file header
--- @return PopupFloat
function M.open(opts)
  local hl = vim.tbl_extend("force", HL, opts.hl or {})
  local out = M.build(opts)
  local winhl = opts.winhl or highlights.WINHL
  if opts.danger then
    winhl = winhl .. ",FloatTitle:" .. hl.danger
  end
  local f = float.open {
    rect = geometry.centered(geometry.env(), math.max(out.width, 34), #out.lines),
    title = (" %s "):format(opts.title),
    footer = out.footer,
    footer_pos = opts.footer_pos,
    zindex = 80,
    noautocmd = true,
    none_is_rounded = true,
    winhl = winhl,
    wo = { sidescrolloff = 0, scrolloff = 0 },
    lines = out.lines,
    spans = out.spans,
    line_hl = out.line_hl,
    paint = { line_priority = 100, span_priority = 200 },
  }

  local selected = math.min(math.max(opts.default or 1, 1), #opts.choices)
  local function show_selection()
    vim.api.nvim_buf_clear_namespace(f.buf, NS, 0, -1)
    local row = out.choice_rows[selected]
    vim.api.nvim_buf_set_extmark(f.buf, NS, row, 0, { line_hl_group = out.select_hl, priority = 300 })
    vim.api.nvim_win_set_cursor(f.win, { row + 1, 0 })
  end
  if opts.menu then
    show_selection()
  else
    vim.api.nvim_win_set_cursor(f.win, { #out.lines, 0 })
  end

  local answered = false
  local function answer(value, remember)
    if answered then
      return
    end
    answered = true
    float.close(f)
    vim.schedule(function()
      opts.on_choice(value, { remember = remember == true })
    end)
  end
  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = f.buf, nowait = true })
  end
  for _, c in ipairs(opts.choices) do
    map(c.key, function()
      answer(c.value, false)
    end)
    if c.remember_key then
      map(c.remember_key, function()
        answer(c.value, true)
      end)
    end
  end
  for _, lhs in ipairs { "q", "<Esc>", "<C-c>" } do
    map(lhs, function()
      answer(nil, false)
    end)
  end
  if opts.menu then
    local function move(step)
      selected = math.min(math.max(selected + step * vim.v.count1, 1), #opts.choices)
      show_selection()
    end
    map("j", function()
      move(1)
    end)
    map("k", function()
      move(-1)
    end)
    map("<CR>", function()
      answer(opts.choices[selected].value, false)
    end)
    for _, lhs in ipairs(opts.remember_keys or {}) do
      map(lhs, function()
        answer(opts.choices[selected].value, true)
      end)
    end
    -- Only j / k change the selection: any other motion lands the cursor
    -- somewhere else and is put back.
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = f.buf,
      callback = function()
        if vim.api.nvim_win_is_valid(f.win) and vim.api.nvim_get_current_win() == f.win then
          local want = out.choice_rows[selected] + 1
          if vim.api.nvim_win_get_cursor(f.win)[1] ~= want then
            vim.api.nvim_win_set_cursor(f.win, { want, 0 })
          end
        end
      end,
    })
  end
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = f.buf,
    once = true,
    callback = function()
      answer(nil, false)
    end,
  })
  return f
end

--- Blocking yes/no menu in a centred float. y / <CR> answer yes; n / q /
--- <Esc> / <C-c> answer no; j / k / <C-d> / <C-u> scroll a tall menu.
--- @param opts { lines: string[], spans?: table[], title?: string, width?: integer, base?: integer }
--- @return boolean
function M.choose(opts)
  local width = opts.width
  if not width then
    width = 20
    for _, l in ipairs(opts.lines) do
      width = math.max(width, vim.fn.strdisplaywidth(l))
    end
  end
  local env = geometry.env()
  local rect = geometry.fractional(env, width, #opts.lines)
  local f = float.open {
    rect = rect,
    title = opts.title and (" " .. geometry.fit(opts.title, rect.width - 4) .. " ") or nil,
    lines = opts.lines,
    spans = opts.spans,
    zindex = 50,
    winhl = "NormalFloat:PopupNormal,FloatBorder:PopupBorder,FloatTitle:PopupTitle",
    paint = { base = opts.base or 1, safe = true },
  }
  local yes = { y = true, Y = true, ["\r"] = true, ["\n"] = true }
  local no = { n = true, N = true, q = true, ["\27"] = true, ["\3"] = true }
  local scroll = {
    j = "\5",
    k = "\25",
    [vim.api.nvim_replace_termcodes("<Down>", true, false, true)] = "\5",
    [vim.api.nvim_replace_termcodes("<Up>", true, false, true)] = "\25",
    ["\4"] = "\4",
    ["\21"] = "\21",
  }
  local answer = false
  while float.is_open(f) do
    vim.cmd.redraw()
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok or no[ch] then
      break
    elseif yes[ch] then
      answer = true
      break
    elseif scroll[ch] then
      vim.api.nvim_win_call(f.win, function()
        vim.cmd("normal! " .. scroll[ch])
      end)
    end
  end
  float.close(f)
  return answer
end

return M
