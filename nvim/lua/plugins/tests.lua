return {
  --------------------------------------------------------------------------------
  -- vim-test (запуск тестов)
  --------------------------------------------------------------------------------
  {
    'vim-test/vim-test',
    config = function()
      vim.cmd([[
        let test#python#runner = 'pytest'
      ]])

      -- Хоткеи для тестов
      vim.keymap.set("n", "<leader>tn", ":TestNearest<CR>", { silent = true })
      vim.keymap.set("n", "<leader>tf", ":TestFile<CR>", { silent = true })
      vim.keymap.set("n", "<leader>ts", ":TestSuite<CR>", { silent = true })
      vim.keymap.set("n", "<leader>tv", ":TestVisit<CR>", { silent = true })
    end
  },
}
