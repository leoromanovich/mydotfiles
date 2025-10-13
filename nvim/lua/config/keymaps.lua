
-- Маппинги
local keymap = vim.keymap.set
local opts = { silent = true }

-- Навигация между окнами
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

-- Изменение размеров окон
keymap("n", "<C-Up>", ":resize -2<CR>", opts)
keymap("n", "<C-Down>", ":resize +2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

vim.keymap.set('n', '<Tab>', ':bnext<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<S-Tab>', ':bprevious<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>bb', ':ls<CR>:b ', { noremap = true })
vim.keymap.set("n", "<leader>d", function()
  vim.diagnostic.open_float(nil, { scope = "line" })
end, { desc = "Show diagnostics for the current line" })

vim.api.nvim_create_user_command('RmDebugLines', function(opts)
  -- если выделен диапазон — работает по выделению; иначе по всему файлу
  local range = (opts.range == 0) and '%' or ([[%d,%d]]):format(opts.line1, opts.line2)
  vim.cmd(range .. [[g/\v#\s*DEBUG/d]])
end, { range = true, desc = 'Удалить строки с "# DEBUG"' })

vim.keymap.set('n', '<leader>rmd', function()
  vim.cmd('RmDebugLines')                -- по всему файлу
end, { desc = 'Удалить строки с "# DEBUG" во всём файле' })

vim.keymap.set('v', '<leader>rmd', [[:'<,'>RmDebugLines<CR>]],
  { desc = 'Удалить строки с "# DEBUG" в выделении' })
