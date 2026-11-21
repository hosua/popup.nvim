--- Small modal floats. `open` is non-blocking (a few lines, keys that answer
--- it, ported from session-mgr's ui/confirm.lua). `choose` blocks on keys
--- like confirm() does (ported from devdocs' float.choose).
---
---   confirm.open {
---     title = "2 unsaved buffers", danger = true,
---     lines = { { { "  M  ", "PopupWarn" }, { "init.lua" } }, ... },   -- chunks per line
---     choices = { { key = "w", label = "write all & load", value = "write" }, ... },
---     on_choice = function(value) end,   -- value is nil when cancelled (q / <Esc> / <C-c>)
---     hl = { key = "PopupKey", danger = "PopupError", footer = "PopupFooter" },
---     winhl = "...",                     -- default highlights.WINHL
---   }
local float = require "popup.float"
local geometry = require "popup.geometry"
local highlights = require "popup.highlights"

local M = {}

local HL = { key = "PopupKey", danger = "PopupError", footer = "PopupFooter" }

--- Pure: chunks -> lines + spans, plus the choice rows and the width wanted.
--- @param opts table see the file header
--- @return { lines: string[], spans: table[], line_hl: table, width: integer }
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
  if #lines > 0 then
    push {}
  end
  for _, c in ipairs(opts.choices) do
    push { { "  " }, { c.key, c.danger and hl.danger or hl.key }, { "  " .. c.label } }
  end
  local width = vim.fn.strdisplaywidth(opts.title or "") + 4
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l) + 2)
  end
  return { lines = lines, spans = spans, line_hl = {}, width = width }
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
    footer = { { " q", hl.key }, { " cancel ", hl.footer } },
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
  vim.api.nvim_win_set_cursor(f.win, { #out.lines, 0 })

  local answered = false
  local function answer(value)
    if answered then
      return
    end
    answered = true
    float.close(f)
    vim.schedule(function()
      opts.on_choice(value)
    end)
  end
  local function map(lhs, value)
    vim.keymap.set("n", lhs, function()
      answer(value)
    end, { buffer = f.buf, nowait = true })
  end
  for _, c in ipairs(opts.choices) do
    map(c.key, c.value)
  end
  for _, lhs in ipairs { "q", "<Esc>", "<C-c>" } do
    map(lhs, nil)
  end
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = f.buf,
    once = true,
    callback = function()
      answer(nil)
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
