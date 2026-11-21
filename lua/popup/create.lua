--- Vim popup_* API on top of nvim_open_win. Port of the API of
--- nvim-lua/popup.nvim (MIT): option names follow Vim's `popup_create()`.
---
--- Differences from upstream, on purpose: borders are the native ones
--- (nvim_open_win `border`), not extra windows, so `borderchars`, `border`
--- widths and `borderhighlight` are mapped onto them, and the title lives in
--- the top border. Options without a Neovim equivalent are listed in
--- M.UNSUPPORTED and warn once.
local borders = require "popup.borders"
local geometry = require "popup.geometry"

local M = {}

--- Vim options accepted and ignored (warned once each).
M.UNSUPPORTED = {
  "drag",
  "dragall",
  "resize",
  "close",
  "mask",
  "filter",
  "filtermode",
  "mapping",
  "textprop",
  "textpropid",
  "tabpage",
  "scrollbar",
  "scrollbarhighlight",
  "thumbhighlight",
  "posinvert",
  "flip",
  "cursorline_hl",
}

--- @class PopupState
--- @field opts table merged Vim options
--- @field lines string[] text as stored (without padding)
--- @field own_buf boolean
--- @field done boolean callbacks already ran

--- @type table<integer, PopupState>
local registry = {}

--- Lines of `what`: a string (split on newlines) or a list of strings.
--- @param what string|string[]
--- @return string[]
function M.to_lines(what)
  if type(what) == "string" then
    return vim.split(what, "\n", { plain = true })
  end
  return vim.deepcopy(what)
end

--- Add Vim `padding` (CSS-style box) around text lines.
--- @param lines string[]
--- @param padding integer[]|nil
--- @return string[]
function M.pad(lines, padding)
  if padding == nil then
    return lines
  end
  local p = borders.box(padding)
  local left, right = string.rep(" ", p[4]), string.rep(" ", p[2])
  local out = {}
  for _ = 1, p[1] do
    out[#out + 1] = ""
  end
  for _, l in ipairs(lines) do
    out[#out + 1] = left .. l .. right
  end
  for _ = 1, p[3] do
    out[#out + 1] = ""
  end
  return out
end

--- Rows `lines` need when each line wraps at `width` cells.
--- @param lines string[]
--- @param width integer
--- @return integer
function M.wrapped_height(lines, width)
  local h = 0
  for _, l in ipairs(lines) do
    h = h + math.max(1, math.ceil(vim.fn.strdisplaywidth(l) / math.max(width, 1)))
  end
  return h
end

--- Column range of the word (or WORD) under `col` (1-based), for `moved`.
--- @param line string
--- @param col integer
--- @param big boolean WORD: anything not blank
--- @return integer start, integer stop 1-based, inclusive
function M.word_range(line, col, big)
  local pat = big and "%S" or "[%w_]"
  local ch = line:sub(col, col)
  if ch == "" or not ch:match(pat) then
    return col, col
  end
  local s, e = col, col
  while s > 1 and line:sub(s - 1, s - 1):match(pat) do
    s = s - 1
  end
  while line:sub(e + 1, e + 1):match(pat) do
    e = e + 1
  end
  return s, e
end

--- Resolve "cursor", "cursor+N", "cursor-N" or a number against a cursor position.
--- @param v string|integer|nil
--- @param cursor integer 1-based screen coordinate of the cursor
--- @return integer|nil
local function resolve_axis(v, cursor)
  if type(v) == "number" then
    return v
  end
  if type(v) == "string" then
    local off = v:match "^cursor([+-]%d+)$"
    if v == "cursor" then
      return cursor
    elseif off then
      return cursor + tonumber(off)
    end
  end
end

--- Pure: nvim_open_win config for content of `size` and Vim options `o`.
--- `env` is a PopupEnv plus `cursor_row`, `cursor_col` (1-based screen cells).
--- @param size { width: integer, height: integer } content incl. padding
--- @param o table Vim options
--- @param env table
--- @return table cfg
function M.config(size, o, env)
  local bw = borders.box(o.border)
  local border = borders.to_native(o.borderchars, bw, o.borderhighlight)
  local side_w = (bw[2] > 0 and 1 or 0) + (bw[4] > 0 and 1 or 0)
  local side_h = (bw[1] > 0 and 1 or 0) + (bw[3] > 0 and 1 or 0)

  local w = o.width or size.width
  w = math.max(w, o.minwidth or 0)
  if o.maxwidth then
    w = math.min(w, o.maxwidth)
  end
  w = math.max(w, 1)
  local h = o.height or size.height
  if o.wrap ~= false and w < size.width and not o.height and o.lines then
    h = M.wrapped_height(o.lines, w)
  end
  h = math.max(h, o.minheight or 0)
  if o.maxheight then
    h = math.min(h, o.maxheight)
  end
  h = math.max(h, 1)

  local ow, oh = w + side_w, h + side_h
  local line = resolve_axis(o.line, env.cursor_row)
  local col = resolve_axis(o.col, env.cursor_col)
  local pos = o.pos or "topleft"

  local function axis(v, outer, total, near, far)
    if v == nil or pos == "center" then
      return math.floor((total - outer) / 2)
    end
    return (pos:find(far, 1, true) and v - outer) or (v - 1)
  end
  local row = axis(line, oh, env.lines, "top", "bot")
  local c0 = axis(col, ow, env.columns, "left", "right")
  if not o.fixed then
    row = math.max(0, math.min(row, env.lines - oh))
    c0 = math.max(0, math.min(c0, env.columns - ow))
  end

  local cfg = {
    relative = "editor",
    row = row,
    col = c0,
    width = w,
    height = h,
    style = "minimal",
    border = border,
    zindex = o.zindex,
    focusable = o.focusable,
    hide = o.hidden or nil,
  }
  if o.title and o.title ~= "" and border ~= "none" then
    cfg.title, cfg.title_pos = o.title, "left"
  end
  return cfg
end

local function live_env()
  local env = geometry.env()
  env.cursor_row, env.cursor_col = vim.fn.screenrow(), vim.fn.screencol()
  return env
end

local function content_size(lines)
  local w = 0
  for _, l in ipairs(lines) do
    w = math.max(w, vim.fn.strdisplaywidth(l))
  end
  return { width = w, height = #lines }
end

local function warn_unsupported(o)
  if not require("popup.config").get().warn_unsupported then
    return
  end
  for _, k in ipairs(M.UNSUPPORTED) do
    if o[k] ~= nil then
      vim.notify_once(("popup: option %q has no Neovim equivalent and is ignored"):format(k), vim.log.levels.WARN)
    end
  end
end

--- Run callbacks once, then close the window.
local function finish(win, result)
  local st = registry[win]
  if st and not st.done then
    st.done = true
    if st.opts.callback then
      pcall(st.opts.callback, win, result)
    end
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    if st.opts.finalize_callback then
      pcall(st.opts.finalize_callback, win, result)
    end
    registry[win] = nil
  end
end

--- Close a popup. `result` is handed to its callback (0 when omitted).
--- @param win integer
--- @param result any
function M.close(win, result)
  if registry[win] then
    finish(win, result == nil and 0 or result)
  elseif vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
end

--- Close every popup made through `create`.
function M.clear()
  for win in pairs(vim.deepcopy(registry)) do
    M.close(win, -1)
  end
end

local function watch_moved(win, moved)
  local cur = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local lo, hi
  if moved == "word" or moved == "WORD" then
    lo, hi = M.word_range(line, cur[2] + 1, moved == "WORD")
  elseif type(moved) == "table" then
    lo, hi = moved[1], moved[2]
  end
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
    buffer = buf,
    callback = function()
      if not registry[win] then
        return true
      end
      local now = vim.api.nvim_win_get_cursor(0)
      local leave = (moved == "any" and (now[1] ~= cur[1] or now[2] ~= cur[2]))
        or (lo and (now[1] ~= cur[1] or now[2] + 1 < lo or now[2] + 1 > hi))
        or vim.api.nvim_get_current_buf() ~= buf
      if leave then
        finish(win, -1)
        return true
      end
    end,
  })
end

--- Create a popup. `what` is a string, a list of lines, or a buffer number.
--- @param what string|string[]|integer
--- @param vim_options table Vim popup options (see README)
--- @return integer win_id, { win_id: integer, bufnr: integer }
function M.create(what, vim_options)
  local o = vim.deepcopy(vim_options or {})
  warn_unsupported(o)

  local buf, lines, own = nil, nil, false
  if type(what) == "number" then
    assert(vim.api.nvim_buf_is_valid(what), "popup.create: invalid buffer " .. what)
    buf = what
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  else
    lines = M.to_lines(what)
    buf, own = vim.api.nvim_create_buf(false, true), true
  end
  local shown = own and M.pad(lines, o.padding) or lines
  o.lines = shown
  if own then
    vim.bo[buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, shown)
    vim.bo[buf].modifiable = false
  end

  local cfg = M.config(content_size(shown), o, live_env())
  local win = vim.api.nvim_open_win(buf, o.enter == true, cfg)
  vim.wo[win].wrap = o.wrap ~= false
  vim.wo[win].cursorline = o.cursorline == true
  if o.highlight then
    vim.wo[win].winhighlight = "NormalFloat:" .. o.highlight
  end
  if o.firstline and o.firstline > 1 then
    vim.api.nvim_win_call(win, function()
      vim.fn.winrestview { topline = o.firstline }
    end)
  end

  registry[win] = { opts = o, lines = lines, own_buf = own, done = false }
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      finish(win, -1)
    end,
  })
  if o.time then
    vim.defer_fn(function()
      if registry[win] then
        finish(win, -1)
      end
    end, o.time)
  end
  if o.moved then
    watch_moved(win, o.moved)
  end
  return win, { win_id = win, bufnr = buf }
end

--- Move or resize a popup. `vim_options` are merged over the ones it was
--- created with (line, col, pos, width, height, minwidth, ..., title, zindex).
--- @param win integer
--- @param vim_options table
function M.move(win, vim_options)
  local st = registry[win]
  if not st then
    error(("popup.move: %d is not a popup made by popup.create"):format(win))
  end
  st.opts = vim.tbl_extend("force", st.opts, vim_options or {})
  local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
  st.opts.lines = lines
  vim.api.nvim_win_set_config(win, M.config(content_size(lines), st.opts, live_env()))
end

--- Replace a popup's text (keeps its padding). Only for popups that own
--- their buffer.
--- @param win integer
--- @param text string|string[]
function M.settext(win, text)
  local st = registry[win]
  if not st or not st.own_buf then
    error "popup.settext: only popups created from text own their buffer"
  end
  st.lines = M.to_lines(text)
  local shown = M.pad(st.lines, st.opts.padding)
  local buf = vim.api.nvim_win_get_buf(win)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, shown)
  vim.bo[buf].modifiable = false
  st.opts.lines = shown
  vim.api.nvim_win_set_config(win, M.config(content_size(shown), st.opts, live_env()))
end

--- @param win integer
function M.hide(win)
  vim.api.nvim_win_set_config(win, { hide = true })
end

--- @param win integer
function M.show(win)
  vim.api.nvim_win_set_config(win, { hide = false })
end

--- Position and size, in Vim's terms (1-based screen cells).
--- @param win integer
--- @return table|nil nil when the window is gone
function M.getpos(win)
  if not vim.api.nvim_win_is_valid(win) then
    return nil
  end
  local pos = vim.api.nvim_win_get_position(win)
  local cfg = vim.api.nvim_win_get_config(win)
  return {
    line = pos[1] + 1,
    col = pos[2] + 1,
    width = cfg.width,
    height = cfg.height,
    visible = not cfg.hide,
  }
end

--- Options a popup is using (merged), or nil.
--- @param win integer
--- @return table|nil
function M.getoptions(win)
  local st = registry[win]
  if not st then
    return nil
  end
  local o = vim.deepcopy(st.opts)
  o.lines = nil
  return o
end

return M
