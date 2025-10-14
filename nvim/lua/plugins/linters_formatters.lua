return {
  {
    "stevearc/conform.nvim",
    event = "VeryLazy",
    config = function()
      require("conform").setup({
        -- Последовательность для Python: сначала импорты Ruff, затем формат от Black
        formatters_by_ft = {
          python = { "ruff_fix", "black" },
        },
        -- Настройка самих форматтеров
        formatters = {
          -- Ограничим ruff_fix правилами импорта (I*)
          ruff_fix = { prepend_args = { "--select", "I" } },
          -- Добавь/убери --fast по вкусу
          black = { prepend_args = { "--fast" } },
        },
        notify_on_error = true,
      })

      -- Горячая клавиша: форматировать файл/выделение (Ruff импорты → Black)
      vim.keymap.set({ "n", "v" }, "<leader>rf", function()
        require("conform").format({
          async = true,
          lsp_format = "never",
          timeout_ms = 2000,
        })
      end, { desc = "Ruff+Black: форматировать файл/выделение" })

      -- По желанию: включить умный gq через conform
      -- vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

      -- По желанию: автоформат при сохранении
      -- vim.api.nvim_create_autocmd("BufWritePre", {
      --   pattern = "*.py",
      --   callback = function()
      --     require("conform").format({ lsp_format = "never", timeout_ms = 2000 })
      --   end,
      -- })
    end,
  },
}
