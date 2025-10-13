
-- Установка leader key
vim.g.mapleader = " "

require("config.options")
require("config.keymaps")
require("config.autocmd")

-- CUDA: filetype mapping
vim.filetype.add({
  extension = { cu = "cuda", cuh = "cuda" },
})

-- Установка lazy.nvim, если он не установлен
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "--single-branch",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)


-- Настройка плагинов с помощью lazy.nvim
require("lazy").setup({{import = "plugins"}})


-- vim.o.background = "dark" -- or "light" for light mode
vim.cmd([[colorscheme slate]])


