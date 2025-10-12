return {
    {
      "stevearc/conform.nvim",
      event = "VeryLazy",
      config = function()
        require("conform").setup({
          -- Запускаем сначала autofix (импорты и пр.), затем форматтер
          formatters_by_ft = {
            python = { "ruff_fix", "ruff_format" },
          },
          notify_on_error = true,
        })

        -- Форматировать файл или выделение Ruff-ом
        vim.keymap.set({ "n", "v" }, "<leader>rf", function()
          require("conform").format({
            async = true,
            lsp_format = "never", -- не дергать LSP-форматирование, только Ruff
            timeout_ms = 2000,
          })
        end, { desc = "Ruff: форматировать файл/выделение" })

        -- (необязательно) сделать gq умным — будет использовать conform для range-format
        -- vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
      end,
    },
}
