#!/usr/bin/env bash
# :Popup demo in a real TUI: bordered title, grouped list, key legend,
# navigation, resize, and a Vim-style popup with a title.
set -euo pipefail
cd "$(dirname "$0")/../.."
source tests/smoke/lib.sh
data=$(mktemp -d)
smoke_start 100 30 env XDG_DATA_HOME="$data" XDG_STATE_HOME="$data" XDG_CACHE_HOME="$data" nvim --clean -u tests/smoke/init.lua
smoke_keys ':Popup demo' Enter
smoke_expect 'popup.nvim demo'
smoke_expect 'Installed \(2\)'
smoke_expect 'stylua \(keywords: lua\)'
smoke_expect '• Ctrl\+q  +never ask again'
smoke_expect '• q/<Esc> +dismiss'
smoke_expect '╭'
smoke_reject 'E[0-9]+:'
smoke_resize 60 20
smoke_expect 'popup.nvim demo'
smoke_keys j Enter
smoke_expect 'popup demo: picked prettier'
smoke_keys ':lua require("popup").create({"hello popup", "second"}, { line = 3, col = 5, border = {}, title = "Vim title", padding = {} })' Enter
smoke_expect 'Vim title'
smoke_expect 'hello popup'
smoke_reject 'E[0-9]+:'
smoke_stop
rm -rf "$data"
