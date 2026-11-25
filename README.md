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
| `popup.list_menu` | `open(spec)`, the pure `build(spec)` and `border_footer(spec)`. Grouped read-only list with a key legend (rows, or one line in the border). |
| `popup.confirm` | `open(opts)` (non-blocking modal with keyed choices, or a selectable menu with `menu = true`) and `choose(opts)` (blocking yes/no). |
| `popup.legend` | Pure: `rows`, `help`, `key_label`, `width`, `footer`. Aligned key legends, and the one-line legend for a window's bottom border. |
| `popup.hints` | Pure: `text`, `line`, `chunks`, `wrap`, `table`, `help`. Key hints and footers. |
| `popup.borders` | `box`, `expand_chars`, `to_native`, `resolve`, `default`, `visible`. |
| `popup.geometry` | `env`, `editor`, `centered`, `fractional`, `list`, `menu`, `toast`, `fit`. Pure given an `env`. |
| `popup.highlights` | `define(groups)`, `apply()`, `winhl(pairs)`, `LINKS`, `WINHL`. |

Confirm menu. With `menu = true` the choices are rows you move over:

```lua
local legend = require "popup.legend"
require("popup.confirm").open {
  title = "Load your last autosaved session?",
  menu = true,
  default = 2, -- index of the starting row
  lines = { { { "  Project  ~/dev/app" } }, { { "" } } },
  choices = {
    { key = "y", label = "Load it", value = "yes", remember_key = "Y" },
    { key = "n", label = "Start empty", value = "no", remember_key = "N" },
  },
  remember_keys = { "<S-CR>" },
  footer = (legend.footer {
    { "j/k", "move" }, { "⏎", "pick" }, { "⇧⏎", "pick+remember" },
    { "y", "load" }, { "n", "skip" }, { "Y/N", "always" }, { "q", "cancel" },
  }),
  footer_pos = "right",
  on_choice = function(value, info) -- info.remember is true for Y, N and <S-CR>
  end,
}
```

- `j` / `k` move between the rows and stop at both ends (no wrap). They take a count. Nothing else moves the selection: arrows, `gg`, `G` and the mouse are put back by a `CursorMoved` autocmd.
- `<CR>` answers with the selected row. A choice's `key` answers it directly. `remember_key` and `remember_keys` answer with `info.remember = true`. Every other answer, and a cancel (`q`, `<Esc>`, `<C-c>`), passes `remember = false`.
- The selected row uses `hl.select` (default `PopupSelect`, linked to `PmenuSel`). Menu rows show the label only, and there is no blank line before them, so put one in `lines` if you want it.
- `footer` takes the chunks `legend.footer(entries, opts)` returns (entries are `{ key, desc }`, two spaces between pairs, `opts.key_hl` / `opts.desc_hl`). `footer_pos` is `"left"`, `"center"` or `"right"`. The window is widened to the footer. Without `footer`, a menu lists `j/k`, `⏎`, every choice key and `q`.

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

`border_legend = true` moves the key legend out of the rows into one line in the bottom border (`list_menu.border_footer(spec)` builds it). The window is widened to fit it.

## Highlight groups

Every group is a `default` link, so a theme or your own `:hi` wins. Importance colours use the Diagnostic groups.

| Group | Links to |
|---|---|
| `PopupError`, `PopupWarn`, `PopupOk`, `PopupInfo` | `DiagnosticError`, `DiagnosticWarn`, `DiagnosticOk`, `DiagnosticInfo` |
| `PopupKey`, `PopupBullet` | `Special` |
| `PopupKeyDesc`, `PopupHint`, `PopupFooter` | `Comment` |
| `PopupSelect` | `PmenuSel` |
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
