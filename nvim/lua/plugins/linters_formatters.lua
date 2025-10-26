return {
  {
    "stevearc/conform.nvim",
    event = "VeryLazy",
    config = function()
      require("conform").setup({
        -- Последовательность для Python: сначала импорты Ruff, затем формат от Black
        formatters_by_ft = {
          lua = { "stylua" },
          python = { "isort", "black" },
        },
        formatters = {
          black = { prepend_args = { "--fast" } },
          stylua = {
            prepend_args = {
              "--indent-type",
              "Spaces",
              "--indent-width",
              "2", -- ширина логическая (для выравниваний), при Tabs почти не важна
              "--column-width",
              "100", -- чуть компактнее переносы
            },
          },
        },
        notify_on_error = true,
      })
    end,
  },
}
