# popup.nvim

Vim-style popup API (port of nvim-lua/popup.nvim) plus shared float, key-legend and list-menu components.

## Install

Private repo: lazy.nvim loads the local checkout, and only clones from
GitHub (which needs `gh auth setup-git`) when the checkout is missing.

```lua
-- lua/configs/lazy.lua
dev = { path = "~/dev", fallback = true },

-- lua/plugins/popup.lua
return { { "hosua/popup.nvim", dev = true, cmd = { "Popup" }, opts = {} } }
```

## Commands

| Command | What it does |
|---|---|

## Default keymaps

None are installed unless `keymaps = true`. Suggested:

| Key | Command |
|---|---|

## Configuration

Every option, with its default:

```lua
require("popup").setup {
  notify = true,
}
```

## Health

`:checkhealth popup`

## Development

```bash
make test         # headless unit tests, no dependencies
make integration  # against a throwaway XDG tree
make check        # stylua --check
```
