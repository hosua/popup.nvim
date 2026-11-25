--- Reusable read-only list popup (Mason-style): grouped rows of
--- `name (hint)`, a key legend under the list, vim-like navigation.
--- Ported from ~/.config/nvim/lua/configs/list_menu.lua.
---
---   require("popup.list_menu").open {
---     title  = "Pick a formatter",
---     header = { "line shown above the list",            -- plain = grey,
---                { text = "careful", level = "warn" } }, -- or coloured: error|warn|ok|info
---     groups = {
---       { title = "Installed", hide_count = false, items = {
---           { id = "stylua", label = "stylua", hint = "keywords: lua", mark = true },
---       } },
---     },
---     keys   = {                                          -- extra keys, listed in the legend
---       { key = "<C-q>", desc = "never ask again", fn = function(item, close) end },
---     },
---     footer = { "free text under the key legend" },      -- optional, same shape as header
---     on_select  = function(item, close) end,             -- <CR>
---     select_desc = "open",                               -- legend text for <CR>, default "select"
---     on_dismiss = function() end,                        -- q / <Esc>
---     dismiss_keys = {},                                  -- default { "q", "<Esc>" }; {} frees both
---     border_legend = true,                               -- legend as one line in the bottom border, not rows
---     hl = { key = "MyKey" },                             -- rename any group, see HL_KEYS
---   }
---
--- Item fields: id (any), label, hint (dim text after the label), mark (shows
--- the "current" check icon and starts the cursor there), level (error|warn|ok|info
--- colours the label), and anything else you want back.
--- `close()` closes the popup. Neither callback closes it for you, so a handler
--- can chain into a second menu after closing.
local float = require "popup.float"
local geometry = require "popup.geometry"
local highlights = require "popup.highlights"
local legend = require "popup.legend"

local M = {}

local NS = vim.api.nvim_create_namespace "popup_list_menu"

M.MARK_ICON = "\u{f058}" -- nf-fa-check_circle, Mason's installed icon
M.BLANK_ICON = "  "
M.BULLET = "•"

--- Default group per role. `spec.hl` overrides any of them by role name.
M.HL = {
  title = "PopupTitle",
  group = "PopupGroup",
  label = "PopupLabel",
  hint = "PopupHint",
  mark = "PopupMark",
  bullet = "PopupBullet",
  error = "PopupError",
  warn = "PopupWarn",
  ok = "PopupOk",
  info = "PopupInfo",
  key = "PopupKey",
  key_desc = "PopupKeyDesc",
  border = "PopupBorder",
}

--- @param spec table
--- @return table<string, string>
local function groups_for(spec)
  return vim.tbl_extend("force", M.HL, spec.hl or {})
end

--- The legend entries for a spec: every key the menu maps (j/k, the arrows,
--- gg/G, Enter), spec.keys, the dismiss keys.
--- @param spec table
--- @return { key: string, desc: string }[]
local function legend_entries(spec)
  local entries = {
    { key = "j/k/↑/↓", desc = "move" },
    { key = "gg/G", desc = "first/last" },
    { key = "<CR>", desc = spec.select_desc or "select" },
  }
  for _, k in ipairs(spec.keys or {}) do
    entries[#entries + 1] = k
  end
  local dismiss_keys = spec.dismiss_keys or { "q", "<Esc>" }
  if #dismiss_keys > 0 then
    entries[#entries + 1] = { key = table.concat(dismiss_keys, "/"), desc = "dismiss" }
  end
  return entries
end

--- The legend as border footer chunks plus the width it needs. Pure.
--- @param spec table
--- @return table[] chunks, integer width
function M.border_footer(spec)
  local hl = groups_for(spec)
  local entries = {}
  for i, e in ipairs(legend_entries(spec)) do
    entries[i] = { key = legend.key_label(e.key), desc = e.desc }
  end
  return legend.footer(entries, { key_hl = hl.key, desc_hl = hl.key_desc })
end

--- Build buffer lines plus what is needed to highlight and navigate them.
--- Pure. Marks are { row (0-based), hl, from, to } with to == -1 for end of line.
--- @param spec table see the file header
--- @return string[] lines, table[] marks, integer[] item_rows (1-based), table[] items
function M.build(spec)
  local hl = groups_for(spec)
  local lines, marks, item_rows, items = {}, {}, {}, {}

  local function add(text, group, from, to)
    lines[#lines + 1] = text
    if group then
      marks[#marks + 1] = { row = #lines - 1, hl = group, from = from or 0, to = to or -1 }
    end
  end
  local function add_note(line)
    if type(line) == "table" then
      add(line.text, hl[line.level] or hl.hint)
    else
      add(line, hl.hint)
    end
  end

  for _, line in ipairs(spec.header or {}) do
    add_note(line)
  end
  if spec.header and #spec.header > 0 then
    add ""
  end

  for _, group in ipairs(spec.groups) do
    add(group.hide_count and group.title or ("%s (%d)"):format(group.title, #group.items), hl.group)
    for _, item in ipairs(group.items) do
      local icon = item.mark and M.MARK_ICON or M.BLANK_ICON
      local bullet_prefix = "  " .. M.BULLET .. " "
      local prefix = bullet_prefix .. icon .. " "
      local text = prefix .. item.label
      local label_end = #text
      if item.hint and item.hint ~= "" then
        text = text .. " (" .. item.hint .. ")"
      end
      add(text)
      local row = #lines - 1
      if item.mark then
        marks[#marks + 1] = { row = row, hl = hl.mark, from = #bullet_prefix, to = #bullet_prefix + #icon }
      end
      marks[#marks + 1] = { row = row, hl = hl.bullet, from = 2, to = #bullet_prefix - 1 }
      marks[#marks + 1] = { row = row, hl = hl[item.level] or hl.label, from = #prefix, to = label_end }
      if #text > label_end then
        marks[#marks + 1] = { row = row, hl = hl.hint, from = label_end, to = -1 }
      end
      items[#items + 1] = item
      item_rows[#item_rows + 1] = row + 1
    end
    add ""
  end

  if not spec.border_legend then
    local l, spans = legend.rows(legend_entries(spec), {
      indent = 2,
      bullet = M.BULLET,
      gap = 2,
      key_hl = hl.key,
      desc_hl = hl.key_desc,
      bullet_hl = hl.bullet,
      row = #lines,
    })
    for _, text in ipairs(l) do
      lines[#lines + 1] = text
    end
    for _, s in ipairs(spans) do
      marks[#marks + 1] = { row = s.row, hl = s.hl, from = s.col_start, to = s.col_end }
    end
  end
  if spec.footer and #spec.footer > 0 then
    add ""
    for _, line in ipairs(spec.footer) do
      add_note(line)
    end
  end
  return lines, marks, item_rows, items
end

--- Open the popup. Returns a handle with `close()` and `win`/`buf`, or nil
--- (with a warning) when there is nothing to show.
--- @param spec table see the file header
--- @return { close: fun(), win: integer, buf: integer }|nil
function M.open(spec)
  assert(type(spec) == "table" and type(spec.groups) == "table", "list_menu.open: spec.groups required")
  local hl = groups_for(spec)
  local lines, marks, item_rows, items = M.build(spec)
  if #items == 0 then
    vim.notify("list_menu: nothing to show", vim.log.levels.WARN)
    return nil
  end

  local spans = {}
  for _, m in ipairs(marks) do
    spans[#spans + 1] =
      { row = m.row, col_start = m.from, col_end = m.to >= 0 and m.to or #lines[m.row + 1], hl = m.hl }
  end
  local footer, footer_w
  if spec.border_legend then
    footer, footer_w = M.border_footer(spec)
  end
  -- The legend lives in the border, so the window is at least as wide as it.
  local rect = geometry.menu(
    geometry.env(),
    math.max(legend.width(lines), (footer_w or 2) - 2),
    #lines,
    require("popup.config").get().menu_max_height
  )
  local f = float.open {
    rect = rect,
    lines = lines,
    spans = spans,
    ns = NS,
    border = spec.border or "rounded",
    title = " " .. (spec.title or "") .. " ",
    footer = footer,
    winhl = highlights.winhl {
      { "FloatBorder", hl.border },
      { "FloatTitle", hl.title },
      { "CursorLine", "Visual" },
    },
    wo = { cursorline = true, wrap = false },
    close_on_leave = true,
  }
  local win, buf = f.win, f.buf

  local handle = { win = win, buf = buf }
  function handle.close()
    float.close(f)
  end

  local function current_index()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    for i, r in ipairs(item_rows) do
      if r == row then
        return i
      end
    end
  end
  local function goto_index(i)
    i = math.max(1, math.min(#items, i))
    vim.api.nvim_win_set_cursor(win, { item_rows[i], 0 })
  end
  local function nearest_index(row)
    for i, r in ipairs(item_rows) do
      if r >= row then
        return i
      end
    end
    return #items
  end

  local start = 1
  for i, item in ipairs(items) do
    if item.mark then
      start = i
      break
    end
  end
  goto_index(start)

  -- Keep the cursor on item rows even when scrolled with <C-d>, search or mouse.
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      if not current_index() then
        goto_index(nearest_index(vim.api.nvim_win_get_cursor(win)[1]))
      end
    end,
  })

  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
  end
  local function step(delta)
    return function()
      goto_index((current_index() or 1) + delta * vim.v.count1)
    end
  end
  map("j", step(1), "next item")
  map("k", step(-1), "previous item")
  map("<Down>", step(1), "next item")
  map("<Up>", step(-1), "previous item")
  map("gg", function()
    goto_index(1)
  end, "first item")
  map("G", function()
    goto_index(#items)
  end, "last item")
  map("<CR>", function()
    local i = current_index()
    if i and spec.on_select then
      spec.on_select(items[i], handle.close)
    end
  end, "select")

  local function dismiss()
    handle.close()
    if spec.on_dismiss then
      spec.on_dismiss()
    end
  end
  for _, key in ipairs(spec.dismiss_keys or { "q", "<Esc>" }) do
    map(key, dismiss, "dismiss")
  end
  for _, k in ipairs(spec.keys or {}) do
    map(k.key, function()
      k.fn(items[current_index() or 1], handle.close)
    end, k.desc)
  end
  return handle
end

return M
