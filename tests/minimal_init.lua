-- Init for `make test`: this checkout and plenary.nvim on the runtimepath,
-- nothing else. `-u NONE` still leaves ~/.config/nvim on the runtimepath and
-- the rtp loader beats package.path, so prove which copy got loaded.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:gsub("^@", ""), ":p:h:h")
vim.opt.runtimepath:prepend(root)

local candidates = {
  vim.env.PLENARY_DIR,
  vim.fn.stdpath "data" .. "/lazy/plenary.nvim",
  root .. "/.tests/plenary.nvim",
}
local plenary
for _, p in ipairs(candidates) do
  if p and p ~= "" and vim.uv.fs_stat(p) then
    plenary = p
    break
  end
end
if not plenary then
  -- Fresh machine or CI: fetch it once into the (git-ignored) .tests dir.
  plenary = root .. "/.tests/plenary.nvim"
  vim.fn.system { "git", "clone", "--depth=1", "https://github.com/nvim-lua/plenary.nvim", plenary }
end
vim.opt.runtimepath:append(plenary)
vim.cmd "runtime plugin/plenary.vim"

local src = debug.getinfo(require("popup").setup, "S").source:gsub("^@", "")
if vim.fn.fnamemodify(src, ":p"):sub(1, #root) ~= root then
  io.stderr:write(("FATAL: testing %s, not this checkout (%s)\n"):format(src, root))
  os.exit(2)
end
