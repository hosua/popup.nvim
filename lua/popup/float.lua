--- The window layer for plain floats: a scratch buffer in a float, with
--- painting, retitling, resize hooks, a toast and a cursor note. Everything it
--- shows is computed elsewhere (legend, hints, geometry); it only puts lines,
--- highlights and geometry on screen.
local borders = require "popup.borders"
local geometry = require "popup.geometry"
local highlights = require "popup.highlights"

local M = {}

--- @class PopupFloat
--- @field buf integer
--- @field win integer
--- @field ns integer
--- @field on_close fun()|nil

--- @class PopupFloatOpts
--- @field rect { row: integer, col: integer, width: integer, height: integer }
--- @field lines string[]|nil initial content (buffer becomes read-only)
--- @field spans table[]|nil { row, col_start, col_end, hl } for `lines`
--- @field line_hl table<integer, string>|nil row (0-based) -> group
--- @field title string|nil
--- @field title_pos "left"|"center"|"right"|nil default "center"
--- @field footer string|table[]|nil text or { text, hl } chunks
--- @field footer_pos "left"|"center"|"right"|nil default "left"
--- @field border any nil resolves through borders.default
--- @field none_is_rounded boolean|nil treat winborder=none as unset
--- @field enter boolean|nil default true
--- @field zindex integer|nil
--- @field focusable boolean|nil
--- @field noautocmd boolean|nil
--- @field style string|nil default "minimal"
--- @field relative_win integer|nil place relative to this window
--- @field filetype string|nil
--- @field winhl string|nil default highlights.WINHL
--- @field wo table<string, any>|nil window options, applied after the defaults
--- @field keys table<string, fun()>|nil normal-mode buffer-local keys
--- @field close_on_leave boolean|nil close on WinLeave
--- @field on_close fun()|nil
--- @field ns integer|nil extmark namespace for paint
--- @field paint table|nil options handed to M.paint

--- @param opts PopupFloatOpts
--- @return PopupFloat
function M.open(opts)
  highlights.apply()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  if opts.filetype then
    vim.bo[buf].filetype = opts.filetype
  end
  local border = borders.default(opts.border, { none_is_rounded = opts.none_is_rounded })
  local has_border = borders.visible(border)
  local cfg = {
    relative = opts.relative_win and "win" or "editor",
    win = opts.relative_win,
    row = opts.rect.row,
    col = opts.rect.col,
    width = math.max(1, opts.rect.width),
    height = math.max(1, opts.rect.height),
    style = opts.style or "minimal",
    border = border,
    title = has_border and opts.title or nil,
    title_pos = has_border and opts.title and (opts.title_pos or "center") or nil,
    footer = has_border and opts.footer or nil,
    footer_pos = has_border and opts.footer and (opts.footer_pos or "left") or nil,
    zindex = opts.zindex,
    focusable = opts.focusable,
    noautocmd = opts.noautocmd,
  }
  local win = vim.api.nvim_open_win(buf, opts.enter ~= false, cfg)
  vim.wo[win].winhighlight = opts.winhl or highlights.WINHL
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  for k, v in pairs(opts.wo or {}) do
    vim.wo[win][k] = v
  end

  local f = { buf = buf, win = win, ns = opts.ns or vim.api.nvim_create_namespace "popup" }
  if opts.lines then
    M.paint(f, { lines = opts.lines, spans = opts.spans, line_hl = opts.line_hl }, opts.paint)
  end
  for lhs, fn in pairs(opts.keys or {}) do
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
  end
  if opts.close_on_leave then
    vim.api.nvim_create_autocmd("WinLeave", {
      buffer = buf,
      once = true,
      callback = function()
        M.close(f)
      end,
    })
  end
  if opts.on_close then
    -- WinClosed is not delivered when a window is closed from its own
    -- WinLeave, so M.close calls this too. It runs once.
    local called = false
    f.on_close = function()
      if not called then
        called = true
        pcall(opts.on_close)
      end
    end
    vim.api.nvim_create_autocmd("WinClosed", { pattern = tostring(win), once = true, callback = f.on_close })
  end
  return f
end

--- @param f PopupFloat|nil
--- @return boolean
function M.is_open(f)
  return f ~= nil and vim.api.nvim_win_is_valid(f.win) and vim.api.nvim_buf_is_valid(f.buf)
end

--- Move, resize or retitle without recreating the window.
--- @param f PopupFloat
--- @param rect table|nil
--- @param title string|nil
--- @param footer string|table[]|nil
--- @param opts { title_pos?: string, footer_pos?: string }|nil
function M.configure(f, rect, title, footer, opts)
  if not M.is_open(f) then
    return
  end
  opts = opts or {}
  local cfg = { relative = "editor" }
  if rect then
    cfg.row, cfg.col = rect.row, rect.col
    cfg.width, cfg.height = math.max(1, rect.width), math.max(1, rect.height)
  end
  if borders.visible(vim.api.nvim_win_get_config(f.win).border) then
    cfg.title, cfg.title_pos = title, title and (opts.title_pos or "center") or nil
    cfg.footer, cfg.footer_pos = footer, footer and (opts.footer_pos or "left") or nil
  end
  vim.api.nvim_win_set_config(f.win, cfg)
end

--- Replace the buffer content with `out`.
--- Options: `ns`, `base` (row of the first line in `spans`, default 0),
--- `safe` (pcall every extmark), `line_priority`, `span_priority`.
--- A span with col_end == -1 runs to the end of its line.
--- @param f PopupFloat
--- @param out { lines: string[], spans: table[]|nil, line_hl: table<integer, string>|nil }
--- @param opts { ns?: integer, base?: integer, safe?: boolean, line_priority?: integer, span_priority?: integer }|nil
function M.paint(f, out, opts)
  if not M.is_open(f) then
    return
  end
  opts = opts or {}
  local ns = opts.ns or f.ns
  local base = opts.base or 0
  local set = opts.safe and function(...)
    pcall(vim.api.nvim_buf_set_extmark, ...)
  end or vim.api.nvim_buf_set_extmark
  vim.bo[f.buf].modifiable = true
  vim.api.nvim_buf_set_lines(f.buf, 0, -1, false, out.lines)
  vim.bo[f.buf].modifiable = false
  vim.bo[f.buf].modified = false
  vim.api.nvim_buf_clear_namespace(f.buf, ns, 0, -1)
  for row, group in pairs(out.line_hl or {}) do
    if out.lines[row + 1] then
      set(f.buf, ns, row, 0, { line_hl_group = group, priority = opts.line_priority })
    end
  end
  for _, s in ipairs(out.spans or {}) do
    local row = s.row - base
    local e = { hl_group = s.hl, priority = opts.span_priority }
    if s.col_end == -1 then
      e.end_row = row + 1
    else
      e.end_col = s.col_end
    end
    set(f.buf, ns, row, s.col_start, e)
  end
end

--- @param f PopupFloat|nil
function M.close(f)
  if f and vim.api.nvim_win_is_valid(f.win) then
    pcall(vim.api.nvim_win_close, f.win, true)
  end
  if f and f.on_close then
    f.on_close()
  end
end

--- Run `fn` on VimResized while the float lives (fn re-lays it out).
--- @param f PopupFloat
--- @param fn fun()
function M.on_resize(f, fn)
  local group = vim.api.nvim_create_augroup("popup_float_" .. f.buf, { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if M.is_open(f) then
        fn()
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(f.win),
    once = true,
    callback = function()
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
end

--- Non-focusable, self-closing hint. Closes on the first cursor movement,
--- insert or buffer switch, so `nvim some-file` is never interrupted. Text is
--- framed by a blank line above and below and two spaces either side.
--- @param lines string[]
--- @param opts { timeout_ms: integer, position?: "center"|"bottom_right", winhl?: string, border?: any }
--- @return integer win
function M.toast(lines, opts)
  highlights.apply()
  local text = { "" }
  for _, line in ipairs(lines) do
    text[#text + 1] = "  " .. line .. "  "
  end
  text[#text + 1] = ""
  local width = 0
  for _, l in ipairs(text) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  local geo = geometry.toast(width, #text, geometry.env(), opts.position)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = geo.width,
    height = geo.height,
    row = geo.row,
    col = geo.col,
    style = "minimal",
    border = borders.default(opts.border or "rounded"),
    focusable = false,
    noautocmd = true,
    zindex = 60,
  })
  vim.wo[win].winhighlight = opts.winhl or "FloatBorder:PopupInfo"
  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave", "WinScrolled" }, {
    once = true,
    callback = close,
  })
  vim.defer_fn(close, opts.timeout_ms)
  return win
end

--- A small non-focusable popup at the cursor. Uses
--- vim.lsp.util.open_floating_preview, so it replaces an LSP hover on the same
--- buffer and closes when the cursor moves. `opts.subject` = { row, start_col,
--- end_col } (0-based, bytes) is highlighted with `opts.subject_hl`.
--- @param lines string[]
--- @param opts { subject?: integer[], subject_hl?: string, winhl?: string, border?: any, focus_id?: string, max_width?: integer }|nil
--- @return integer buf, integer win
function M.note(lines, opts)
  opts = opts or {}
  highlights.apply()
  local buf, win = vim.lsp.util.open_floating_preview(lines, "plaintext", {
    border = borders.default(opts.border, { none_is_rounded = false }),
    focusable = false,
    focus = false,
    focus_id = opts.focus_id or "popup_note",
    close_events = { "CursorMoved", "CursorMovedI", "InsertCharPre", "BufHidden" },
    max_width = opts.max_width or 80,
    wrap = true,
  })
  vim.wo[win].winhighlight = opts.winhl or "NormalFloat:PopupNormal,FloatBorder:PopupBorder"
  if opts.subject then
    local r, s, e = unpack(opts.subject)
    vim.api.nvim_buf_set_extmark(buf, vim.api.nvim_create_namespace "popup_note", r, s, {
      end_col = e,
      hl_group = opts.subject_hl or "PopupKey",
    })
  end
  return buf, win
end

return M
