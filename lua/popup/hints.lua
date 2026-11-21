--- Key hints: "key action" pairs for hint lines, float footers and help
--- screens. A hint is { key, action }. This turns a list of them into text
--- plus highlight spans (byte columns, for extmarks) or into nvim_open_win
--- footer chunks. Pure. Ported from devdocs.nvim's ui/hints.lua; the groups
--- are options (`key_hl`, `action_hl`) so each plugin keeps its own colours.
local M = {}

M.KEY_HL = "PopupKey"
M.ACTION_HL = "PopupKeyDesc"
M.HEADER_HL = "PopupGroup"
M.TITLE_HL = "PopupGroup"
M.SEP = "  "

local dw = vim.fn.strdisplaywidth

--- @alias PopupHint { [1]: string, [2]: string, keep?: boolean } key, action; keep: never dropped from a narrow footer
--- @class PopupHintOpts
--- @field key_hl string|nil
--- @field action_hl string|nil
--- @field header_hl string|nil
--- @field title_hl string|nil

--- "o browser  y url"
--- @param hints PopupHint[]
--- @param sep string|nil
--- @return string
function M.text(hints, sep)
  local parts = {}
  for _, h in ipairs(hints) do
    parts[#parts + 1] = h[1] .. " " .. h[2]
  end
  return table.concat(parts, sep or M.SEP)
end

local function pieces(hints, sep, prefix, key_hl, action_hl)
  local out = {}
  if prefix and prefix ~= "" then
    out[#out + 1] = { prefix, action_hl }
  end
  for i, h in ipairs(hints) do
    out[#out + 1] = { h[1], key_hl }
    out[#out + 1] = { " " .. h[2] .. (i < #hints and sep or ""), action_hl }
  end
  local merged = {}
  for _, p in ipairs(out) do
    local last = merged[#merged]
    if last and last[2] == p[2] then
      last[1] = last[1] .. p[1]
    else
      merged[#merged + 1] = { p[1], p[2] }
    end
  end
  return merged
end

--- One line of hints and its spans { col_start, col_end, hl } (0-based byte
--- columns, end exclusive). The spans tile the line. With opts.width the line
--- is cut to that many cells (with an ellipsis) and the spans are clipped.
--- @param hints PopupHint[]
--- @param opts (PopupHintOpts & { prefix?: string, sep?: string, width?: integer })|nil
--- @return string line, table[] spans
function M.line(hints, opts)
  opts = opts or {}
  local line, spans = "", {}
  for _, p in
    ipairs(pieces(hints, opts.sep or M.SEP, opts.prefix, opts.key_hl or M.KEY_HL, opts.action_hl or M.ACTION_HL))
  do
    spans[#spans + 1] = { col_start = #line, col_end = #line + #p[1], hl = p[2] }
    line = line .. p[1]
  end
  if opts.width and dw(line) > opts.width then
    local n = vim.fn.strchars(line)
    local cut = line
    while n > 0 and dw(cut) > opts.width - 1 do
      n = n - 1
      cut = vim.fn.strcharpart(line, 0, n)
    end
    local kept = {}
    for _, s in ipairs(spans) do
      if s.col_start < #cut then
        kept[#kept + 1] = { col_start = s.col_start, col_end = math.min(s.col_end, #cut), hl = s.hl }
      end
    end
    line, spans = cut .. "…", kept
  end
  return line, spans
end

--- Chunks for nvim_open_win's `footer`, padded with a space each side.
--- Trailing hints are dropped until it fits `width` cells, except hints
--- marked `keep = true`.
--- @param hints PopupHint[]
--- @param width integer
--- @param opts PopupHintOpts|nil
--- @return table[] chunks
function M.chunks(hints, width, opts)
  opts = opts or {}
  local shown = vim.list_slice(hints)
  while #shown > 1 and dw(" " .. M.text(shown) .. " ") > width do
    local drop
    for i = #shown, 1, -1 do
      if not shown[i].keep then
        drop = i
        break
      end
    end
    if not drop then
      break
    end
    table.remove(shown, drop)
  end
  local out = pieces(shown, M.SEP, " ", opts.key_hl or M.KEY_HL, opts.action_hl or M.ACTION_HL)
  if #out > 0 then
    out[#out][1] = out[#out][1] .. " "
  end
  return out
end

--- Word wrap by display width. A word longer than the width stays whole.
--- @param text string
--- @param width integer
--- @return string[]
function M.wrap(text, width)
  local out, cur = {}, ""
  for word in text:gmatch "%S+" do
    if cur == "" then
      cur = word
    elseif dw(cur .. " " .. word) <= width then
      cur = cur .. " " .. word
    else
      out[#out + 1] = cur
      cur = word
    end
  end
  out[#out + 1] = cur
  return out
end

--- @class PopupHintTable
--- @field header { [1]: string, [2]: string }|nil
--- @field rows { [1]: string, [2]: string }[]
--- @field keys boolean|nil first column holds keys (default true)

--- Two-column table as aligned lines. With opts.width, actions wrap under
--- the action column (when at least 20 cells are left). Spans are
--- { row (1-based), col_start, col_end, hl }.
--- @param tbl PopupHintTable
--- @param opts (PopupHintOpts & { indent?: integer, gap?: integer, key_width?: integer, width?: integer })|nil
--- @return string[] lines, table[] spans
function M.table(tbl, opts)
  opts = opts or {}
  local key_hl, header_hl = opts.key_hl or M.KEY_HL, opts.header_hl or M.HEADER_HL
  local indent, gap = opts.indent or 2, opts.gap or 3
  local key_width = opts.key_width
  if not key_width then
    key_width = tbl.header and dw(tbl.header[1]) or 0
    for _, r in ipairs(tbl.rows) do
      key_width = math.max(key_width, dw(r[1]))
    end
  end
  local lead = string.rep(" ", indent)
  local col = indent + key_width + gap
  local avail = opts.width and opts.width - col
  local lines, spans = {}, {}
  local function cells(first, second, first_hl, second_hl, wrap)
    local pad = string.rep(" ", key_width - dw(first) + gap)
    local parts = wrap and avail and avail >= 20 and M.wrap(second, avail) or { second }
    lines[#lines + 1] = lead .. first .. pad .. parts[1]
    local row = #lines
    if first_hl then
      spans[#spans + 1] = { row = row, col_start = indent, col_end = indent + #first, hl = first_hl }
    end
    if second_hl then
      local start = indent + #first + #pad
      spans[#spans + 1] = { row = row, col_start = start, col_end = start + #parts[1], hl = second_hl }
    end
    for k = 2, #parts do
      lines[#lines + 1] = string.rep(" ", col) .. parts[k]
    end
  end
  if tbl.header then
    cells(tbl.header[1], tbl.header[2], header_hl, header_hl, false)
  end
  for _, r in ipairs(tbl.rows) do
    cells(r[1], r[2], tbl.keys ~= false and key_hl or nil, nil, true)
  end
  return lines, spans
end

--- A help screen from blocks: "" (blank), { title = s }, { text = s } (a
--- wrapped paragraph) or a PopupHintTable. Tables share one key column width.
--- @param blocks (string|table)[]
--- @param opts (PopupHintOpts & { indent?: integer, gap?: integer, width?: integer })|nil
--- @return string[] lines, table[] spans
function M.help(blocks, opts)
  opts = opts or {}
  local key_width = 0
  for _, b in ipairs(blocks) do
    if type(b) == "table" and b.rows then
      key_width = math.max(key_width, b.header and dw(b.header[1]) or 0)
      for _, r in ipairs(b.rows) do
        key_width = math.max(key_width, dw(r[1]))
      end
    end
  end
  local lines, spans = {}, {}
  local topt = vim.tbl_extend("force", opts, { key_width = key_width })
  for _, b in ipairs(blocks) do
    if b == "" then
      lines[#lines + 1] = ""
    elseif b.title then
      lines[#lines + 1] = b.title
      spans[#spans + 1] = { row = #lines, col_start = 0, col_end = #b.title, hl = opts.title_hl or M.TITLE_HL }
    elseif b.text then
      local indent = string.rep(" ", opts.indent or 2)
      for _, piece in ipairs(M.wrap(b.text, opts.width and opts.width - #indent or math.huge)) do
        lines[#lines + 1] = indent .. piece
      end
    else
      local tl, ts = M.table(b, topt)
      for _, sp in ipairs(ts) do
        sp.row = sp.row + #lines
        spans[#spans + 1] = sp
      end
      vim.list_extend(lines, tl)
    end
  end
  return lines, spans
end

return M
