--- Key legends: aligned "key  description" rows with a bright key and a grey
--- description. Pure: returns lines and spans, touches no window.
---
--- Spans are { row (0-based), col_start, col_end (byte columns, exclusive), hl }.
--- Two layouts come out of the same function:
---   * the list-menu footer: `  • Ctrl+q  never ask again` (bullet = "•")
---   * the session-mgr help screen: `   j k  ↑ ↓   up / down` (no bullet)
local M = {}

local dw = vim.fn.strdisplaywidth

local NAMED = { CR = "Enter", Esc = "Esc", BS = "Backspace", Tab = "Tab" }

--- Pretty-print a key (`<C-q>` -> `Ctrl+q`, `<CR>` -> `Enter`). A string
--- holding "/" (like "q/<Esc>") is a list of keys and is shown as written.
--- @param key string
--- @return string
function M.key_label(key)
  if key:find("/", 1, true) then
    return key
  end
  local ctrl = key:match "^<[Cc]%-(.+)>$"
  if ctrl then
    return "Ctrl+" .. ctrl
  end
  local bare = key:match "^<(.+)>$"
  return bare and (NAMED[bare] or bare) or key
end

--- @class PopupLegendEntry
--- @field key string
--- @field desc string

--- @class PopupLegendOpts
--- @field indent integer|nil spaces before the bullet or key (default 2)
--- @field bullet string|false|nil bullet glyph, or false for none (default "•")
--- @field gap integer|nil spaces between key column and description (default 2)
--- @field key_hl string|nil
--- @field desc_hl string|nil
--- @field bullet_hl string|nil
--- @field label (fun(key: string): string)|false|nil key formatter; false shows keys as given
--- @field row integer|nil 0-based row of the first line (default 0)
--- @field key_width integer|nil force the key column width

--- Rows for a list of entries, keys padded to one column.
--- @param entries PopupLegendEntry[]
--- @param opts PopupLegendOpts|nil
--- @return string[] lines, table[] spans, integer key_width
function M.rows(entries, opts)
  opts = opts or {}
  local indent = opts.indent or 2
  local bullet = opts.bullet
  if bullet == nil then
    bullet = "•"
  end
  local gap = opts.gap or 2
  local key_hl, desc_hl, bullet_hl =
    opts.key_hl or "PopupKey", opts.desc_hl or "PopupKeyDesc", opts.bullet_hl or "PopupBullet"
  local label = opts.label
  if label == nil then
    label = M.key_label
  end
  local lead = string.rep(" ", indent) .. (bullet and (bullet .. " ") or "")
  local row0 = opts.row or 0

  local shown = {}
  local width = opts.key_width or 0
  for i, e in ipairs(entries) do
    shown[i] = label and label(e.key) or e.key
    width = math.max(width, dw(shown[i]))
  end

  local lines, spans = {}, {}
  for i, e in ipairs(entries) do
    local pad = string.rep(" ", width - dw(shown[i]) + gap)
    local line = lead .. shown[i] .. pad .. e.desc
    lines[i] = line
    local row = row0 + i - 1
    if bullet then
      spans[#spans + 1] = { row = row, col_start = indent, col_end = #lead - 1, hl = bullet_hl }
    end
    spans[#spans + 1] = { row = row, col_start = #lead, col_end = #lead + #shown[i], hl = key_hl }
    spans[#spans + 1] = { row = row, col_start = #line - #e.desc, col_end = #line, hl = desc_hl }
  end
  return lines, spans, width
end

--- @class PopupLegendSection
--- @field [1] string title
--- @field [2] { [1]: string, [2]: string }[] rows of { key, description }

--- A help screen: titled sections, one shared key column, a blank line
--- between sections.
--- @param sections PopupLegendSection[]
--- @param opts { title_indent?: integer, indent?: integer, gap?: integer, title_hl?: string, key_hl?: string, desc_hl?: string }|nil
--- @return string[] lines, table[] spans
function M.help(sections, opts)
  opts = opts or {}
  local title_indent = opts.title_indent or 1
  local keyw = 0
  for _, s in ipairs(sections) do
    for _, r in ipairs(s[2]) do
      keyw = math.max(keyw, dw(r[1]))
    end
  end
  local lines, spans = {}, {}
  for i, s in ipairs(sections) do
    if i > 1 then
      lines[#lines + 1] = ""
    end
    lines[#lines + 1] = string.rep(" ", title_indent) .. s[1]
    spans[#spans + 1] =
      { row = #lines - 1, col_start = title_indent, col_end = title_indent + #s[1], hl = opts.title_hl or "PopupGroup" }
    local entries = {}
    for k, r in ipairs(s[2]) do
      entries[k] = { key = r[1], desc = r[2] }
    end
    local l, sp = M.rows(entries, {
      indent = opts.indent or 3,
      bullet = false,
      gap = opts.gap or 3,
      label = false,
      key_hl = opts.key_hl,
      desc_hl = opts.desc_hl,
      key_width = keyw,
      row = #lines,
    })
    vim.list_extend(lines, l)
    vim.list_extend(spans, sp)
  end
  return lines, spans
end

--- Widest line in display cells, plus `extra`.
--- @param lines string[]
--- @param extra integer|nil
--- @return integer
function M.width(lines, extra)
  local w = 0
  for _, l in ipairs(lines) do
    w = math.max(w, dw(l))
  end
  return w + (extra or 0)
end

return M
