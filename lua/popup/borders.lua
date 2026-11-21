--- Border helpers. Pure except `default`, which reads 'winborder'.
--- Vim popup border options (CSS-style boxes, borderchars, borderhighlight)
--- become the native `border` argument of nvim_open_win.
local M = {}

--- Vim order: top, right, bottom, left, topleft, topright, botright, botleft.
M.DEFAULT_CHARS = { "─", "│", "─", "│", "┌", "┐", "┘", "└" }

--- CSS-style box: {} = 1 all round, {a} = all, {v,h}, {t,h,b}, {t,r,b,l}.
--- nil gives all zeros. Returns { top, right, bottom, left }.
--- @param list integer[]|nil
--- @return integer[]
function M.box(list)
  if list == nil then
    return { 0, 0, 0, 0 }
  end
  local n = #list
  if n == 0 then
    return { 1, 1, 1, 1 }
  elseif n == 1 then
    return { list[1], list[1], list[1], list[1] }
  elseif n == 2 then
    return { list[1], list[2], list[1], list[2] }
  elseif n == 3 then
    return { list[1], list[2], list[3], list[2] }
  end
  return { list[1], list[2], list[3], list[4] }
end

--- Vim `borderchars` (1, 2, 4 or 8 entries) to the full 8. One entry fills
--- everything, two are horizontal and vertical, four are the sides. Missing
--- corners come from DEFAULT_CHARS.
--- @param chars string[]|nil
--- @return string[]
function M.expand_chars(chars)
  if chars == nil or #chars == 0 then
    return vim.deepcopy(M.DEFAULT_CHARS)
  end
  local n = #chars
  if n == 1 then
    return { chars[1], chars[1], chars[1], chars[1], chars[1], chars[1], chars[1], chars[1] }
  end
  local out = n == 2 and { chars[1], chars[2], chars[1], chars[2] } or { chars[1], chars[2], chars[3], chars[4] }
  for i = 5, 8 do
    out[i] = chars[i] or M.DEFAULT_CHARS[i]
  end
  return out
end

--- Native border for nvim_open_win from Vim-style parts.
--- A side with width 0 is dropped; a corner shows only when both its sides do.
--- `hls` is { top, right, bottom, left } group names (or one name for all).
--- @param chars string[]|nil Vim borderchars
--- @param widths integer[] from `box`
--- @param hls string[]|string|nil
--- @return table|string "none" when every side is 0
function M.to_native(chars, widths, hls)
  if widths[1] + widths[2] + widths[3] + widths[4] == 0 then
    return "none"
  end
  local c = M.expand_chars(chars)
  local t, r, b, l = widths[1] > 0, widths[2] > 0, widths[3] > 0, widths[4] > 0
  local function pick(show, ch)
    return show and ch or ""
  end
  local h = hls
  if type(h) == "string" then
    h = { h, h, h, h }
  end
  local function with(ch, side)
    local group = h and h[side]
    if ch == "" or not group or group == "" then
      return ch
    end
    return { ch, group }
  end
  return {
    with(pick(t and l, c[5]), 1),
    with(pick(t, c[1]), 1),
    with(pick(t and r, c[6]), 1),
    with(pick(r, c[2]), 2),
    with(pick(b and r, c[7]), 3),
    with(pick(b, c[3]), 3),
    with(pick(b and l, c[8]), 3),
    with(pick(l, c[4]), 4),
  }
end

--- Which border wins: an explicit one, else the configured one, else
--- 'winborder', else "rounded". `none_is_rounded` treats winborder=none as unset.
--- @param o { explicit: any, configured: any, winborder: string|nil, none_is_rounded: boolean|nil }
--- @return any
function M.resolve(o)
  if o.explicit ~= nil then
    return o.explicit
  end
  if o.configured ~= nil and o.configured ~= "auto" then
    return o.configured
  end
  local wb = o.winborder
  if wb == nil or wb == "" then
    return "rounded"
  end
  if wb == "none" and o.none_is_rounded then
    return "rounded"
  end
  return wb
end

--- `resolve` with the live 'winborder' and the plugin config.
--- @param explicit any
--- @param opts { none_is_rounded: boolean|nil }|nil
--- @return any
function M.default(explicit, opts)
  local ok, wb = pcall(function()
    return vim.o.winborder
  end)
  return M.resolve {
    explicit = explicit,
    configured = require("popup.config").get().border,
    winborder = ok and wb or nil,
    none_is_rounded = opts and opts.none_is_rounded,
  }
end

--- True when a native border argument draws something.
--- @param border any
--- @return boolean
function M.visible(border)
  return border ~= nil and border ~= "none" and border ~= ""
end

return M
