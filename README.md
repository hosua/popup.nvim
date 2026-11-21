# popup.nvim

Vim-style `popup.create()` for Neovim, plus the float, key-legend and list-menu code that the other plugins here (devdocs, keymap-helper, session-mgr) used to copy into themselves. Every plugin opens its windows through this one.

The `popup.create` API is a port of [nvim-lua/popup.nvim](https://github.com/nvim-lua/popup.nvim) (MIT, Copyright (c) 2021 TJ DeVries). The notice is kept in `LICENSE`.

## Install

Private repo: lazy.nvim loads the local checkout, and only clones from GitHub (which needs `gh auth setup-git`) when the checkout is missing. Needs Neovim >= 0.11. `plenary.nvim` is only needed to run the tests.

```lua
-- lua/configs/lazy.lua
dev = { path = "~/dev", fallback = true },

-- lua/plugins/popup.lua
return { { "hosua/popup.nvim", dev = true, lazy = true, dependencies = { "nvim-lua/plenary.nvim" } } }
```

Other plugins `require("popup...")` it, so list it in their `dependencies`.

## Commands

| Command | What it does |
|---|---|
| `:Popup demo` | Opens a sample list menu. Use it to check borders, colours and the key legend in your theme. |

## Vim popups

```lua
local popup = require "popup"
local win, info = popup.create({ "hello", "world" }, {
  line = "cursor+1", col = "cursor", pos = "topleft",
  border = {}, title = "Greeting", padding = { 0, 1, 0, 1 },
  highlight = "NormalFloat", time = 3000, moved = "any",
  callback = function(id, result) end,
})
popup.move(win, { line = 5, col = 10, minwidth = 20 })
popup.close(win, 1)
```

| Function | Notes |
|---|---|
| `popup.create(what, opts)` | `what` is a string, a list of lines, or a buffer number. Returns `win_id, { win_id, bufnr }`. |
| `popup.move(win, opts)` | Options merge over the ones the popup was created with. Errors for a window not made by `create`. |
| `popup.close(win, result)` | Runs `callback(win, result)` then `finalize_callback`. `result` is 0 when omitted, -1 when closed by `time`, `moved` or from outside. |
| `popup.clear()`, `popup.hide(win)`, `popup.show(win)` | As in Vim. |
| `popup.settext(win, text)` | Only for popups that own their buffer. Keeps the padding. |
| `popup.getpos(win)`, `popup.getoptions(win)` | `getpos` gives `line, col, width, height, visible`. |

Supported options: `line`, `col` (numbers, `"cursor"`, `"cursor+N"`, `"cursor-N"`), `pos` (`topleft`, `topright`, `botleft`, `botright`, `center`), `fixed`, `width`, `minwidth`, `maxwidth`, `height`, `minheight`, `maxheight`, `title`, `border` (CSS-style box, `{}` is 1 all round), `borderchars`, `borderhighlight`, `padding`, `highlight`, `zindex`, `wrap`, `cursorline`, `firstline`, `hidden`, `enter`, `focusable`, `time`, `moved` (`"any"`, `"word"`, `"WORD"`, `{ min, max }`), `callback`, `finalize_callback`.

Ignored with a one-time warning: `drag`, `dragall`, `resize`, `close`, `mask`, `filter`, `filtermode`, `mapping`, `textprop`, `textpropid`, `tabpage`, `scrollbar`, `scrollbarhighlight`, `thumbhighlight`, `posinvert`, `flip`.

Differences from upstream: borders are Neovim's native ones, not extra windows, so the title sits in the top border and `line`/`col` place the outer box. A popup does not take focus unless `enter = true`.

## Shared components

| Module | What it is |
|---|---|
| `popup.float` | `open(opts)`, `paint(f, out, opts)`, `configure`, `close`, `is_open`, `on_resize`, `toast`, `note`. The one place that opens plain floats. |
| `popup.list_menu` | `open(spec)` and the pure `build(spec)`. Grouped read-only list with a key legend. |
| `popup.confirm` | `open(opts)` (non-blocking modal with keyed choices) and `choose(opts)` (blocking yes/no). |
| `popup.legend` | Pure: `rows`, `help`, `key_label`, `width`. Aligned key legends. |
| `popup.hints` | Pure: `text`, `line`, `chunks`, `wrap`, `table`, `help`. Key hints and footers. |
| `popup.borders` | `box`, `expand_chars`, `to_native`, `resolve`, `default`, `visible`. |
| `popup.geometry` | `env`, `editor`, `centered`, `fractional`, `list`, `menu`, `toast`, `fit`. Pure given an `env`. |
| `popup.highlights` | `define(groups)`, `apply()`, `winhl(pairs)`, `LINKS`, `WINHL`. |

List menu, as in the old `configs/list_menu.lua`:

```lua
require("popup.list_menu").open {
  title = "Pick a formatter",
  groups = { { title = "Installed", items = { { id = "stylua", label = "stylua", hint = "keywords: lua", mark = true } } } },
  keys = { { key = "<C-q>", desc = "never ask again", fn = function(item, close) end } },
  on_select = function(item, close) close() end,
}
```

Keys inside the menu: `j`/`k`/arrows move, `gg`/`G` jump, `<CR>` selects, `q`/`<Esc>` dismiss (`dismiss_keys = {}` frees both).

## Highlight groups

Every group is a `default` link, so a theme or your own `:hi` wins. Importance colours use the Diagnostic groups.

| Group | Links to |
|---|---|
| `PopupError`, `PopupWarn`, `PopupOk`, `PopupInfo` | `DiagnosticError`, `DiagnosticWarn`, `DiagnosticOk`, `DiagnosticInfo` |
| `PopupKey`, `PopupBullet` | `Special` |
| `PopupKeyDesc`, `PopupHint`, `PopupFooter` | `Comment` |
| `PopupTitle`, `PopupGroup` | `Title` |
| `PopupNormal`, `PopupBorder`, `PopupLabel`, `PopupMark` | `NormalFloat`, `FloatBorder`, `Normal`, `DiagnosticOk` |

A plugin that keeps its own group names passes them per call (`hl = { key = "MyKey" }` for the list menu, `key_hl`/`action_hl` for hints, `winhl` for floats).

## Configuration

Every option, with its default:

```lua
require("popup").setup {
  -- "auto" follows 'winborder', else "rounded". Any nvim_open_win border works.
  border = "auto",
  -- Share of the screen height a list menu may use.
  menu_max_height = 0.7,
  -- Warn once when a Vim popup option has no Neovim equivalent.
  warn_unsupported = true,
}
```

## Health

`:checkhealth popup`

## Development

```bash
make test    # plenary busted specs, headless
make smoke   # tmux screen capture of :Popup demo
make check   # stylua --check
```
