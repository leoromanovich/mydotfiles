-- Установка leader key
vim.g.mapleader = " "

-- Базовая конфигурация
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
    "git",
    "clone",
    "--filter=blob:none",
    "--single-branch",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

-- Настройка плагинов с помощью lazy.nvim
require("lazy").setup({ { import = "plugins" } })

-- Если telescope недоступен — подключаем common.vim
local fn = vim.fn
local has_telescope = pcall(require, "telescope")

if not has_telescope then
  local common = fn.expand("~/.vim/common.vim")
  local common_alt = fn.expand("~/.config/nvim/common.vim")

  if fn.filereadable(common) == 1 then
    vim.cmd("source " .. fn.fnameescape(common))
  elseif fn.filereadable(common_alt) == 1 then
    vim.cmd("source " .. fn.fnameescape(common_alt))
  else
    vim.notify("~/.vim/common.vim not found", vim.log.levels.WARN)
  end
end

-- Цветовая схема
vim.cmd([[colorscheme slate]])
