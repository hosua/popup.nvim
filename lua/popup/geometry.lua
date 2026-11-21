--- Window rectangles. Everything takes an `env` table instead of reading
--- vim.o, so it is testable without a UI. `M.env()` builds the live one.
---
--- @class PopupEnv
--- @field columns integer
--- @field lines integer
--- @field cmdheight integer
--- @field laststatus integer
--- @field showtabline integer
--- @field tabpages integer
local M = {}

--- @return PopupEnv
function M.env()
  return {
    columns = vim.o.columns,
    lines = vim.o.lines,
    cmdheight = vim.o.cmdheight,
    laststatus = vim.o.laststatus,
    showtabline = vim.o.showtabline,
    tabpages = #vim.api.nvim_list_tabpages(),
  }
end

--- Usable area: the editor minus cmdline, statusline and tabline.
--- @param env PopupEnv
--- @return { width: integer, height: integer }
function M.editor(env)
  local status = env.laststatus > 0 and 1 or 0
  local tabline = (env.showtabline == 2 or (env.showtabline == 1 and env.tabpages > 1)) and 1 or 0
  return { width = env.columns, height = math.max(3, env.lines - env.cmdheight - status - tabline) }
end

--- Box centred in the usable area, leaving room for a 2-cell border.
--- @param env PopupEnv
--- @return { row: integer, col: integer, width: integer, height: integer }
function M.centered(env, width, height)
  local e = M.editor(env)
  width, height = math.min(width, e.width - 4), math.min(height, e.height - 2)
  return {
    row = math.max(0, math.floor((e.height - height - 2) / 2)),
    col = math.max(0, math.floor((e.width - width - 2) / 2)),
    width = width,
    height = height,
  }
end

--- Centred float sized by fractions (<= 1) or cells (> 1).
--- @param env PopupEnv
--- @return { width: integer, height: integer, row: integer, col: integer }
function M.fractional(env, width, height)
  local cols, lines = env.columns, env.lines - env.cmdheight - 1
  local w = width <= 1 and math.floor(cols * width) or width
  local h = height <= 1 and math.floor(lines * height) or height
  w = math.max(20, math.min(w, cols - 2))
  h = math.max(5, math.min(h, lines - 2))
  return { width = w, height = h, row = math.floor((lines - h) / 2), col = math.floor((cols - w) / 2) }
end

--- A scrolling list: capped width, height `n` lines but at least 8 rows of
--- margin, one row above centre.
--- @param env PopupEnv
--- @param max_width integer
--- @param n integer content lines
function M.list(env, max_width, n)
  local width = math.max(20, math.min(max_width, env.columns - 6))
  local height = math.max(1, math.min(n, env.lines - 8))
  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((env.lines - height) / 2) - 1),
    col = math.max(0, math.floor((env.columns - width) / 2)),
  }
end

--- Menu box for `list_menu`: content width + 2, at most columns - 4 wide,
--- at most `ratio` of the screen tall, centred on the whole screen.
--- @param env PopupEnv
--- @return { row: integer, col: integer, width: integer, height: integer }
function M.menu(env, content_width, content_lines, ratio)
  local width = math.min(content_width + 2, env.columns - 4)
  local height = math.min(content_lines, math.floor(env.lines * ratio))
  return {
    row = math.floor((env.lines - height) / 2),
    col = math.floor((env.columns - width) / 2),
    width = width,
    height = height,
  }
end

local BORDER = 2
local MARGIN = 4

--- Small hint toast, centred or bottom right.
--- @param position "center"|"bottom_right"|nil
function M.toast(content_width, content_height, env, position)
  local width = math.min(content_width, math.max(env.columns - MARGIN, 1))
  local height = math.min(content_height, math.max(env.lines - MARGIN, 1))
  local row, col
  if position == "bottom_right" then
    row = env.lines - height - 4
    col = env.columns - width - 3
  else
    row = math.floor((env.lines - height - BORDER) / 2)
    col = math.floor((env.columns - width - BORDER) / 2)
  end
  return { row = math.max(0, row), col = math.max(0, col), width = width, height = height }
end

--- Cut the middle of `s` with an ellipsis so it fits `width` cells.
--- @param s string
--- @param width integer
--- @return string
function M.fit(s, width)
  local w = vim.fn.strdisplaywidth(s)
  if w <= width then
    return s
  end
  local keep = math.max(0, math.floor((width - 1) / 2))
  return vim.fn.strcharpart(s, 0, keep) .. "…" .. vim.fn.strcharpart(s, vim.fn.strchars(s) - keep, keep)
end

return M
