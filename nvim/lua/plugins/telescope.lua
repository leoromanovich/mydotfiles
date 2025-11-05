return {
  -- Telescope
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = {
            preview_width = 0.7,
          },
        },
      })
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
      vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
      vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})
      vim.keymap.set("n", "<leader>fa", function()
        require("telescope.builtin").find_files({
          hidden = true, -- показывать скрытые файлы (.*)
          no_ignore = true, -- игнорировать .gitignore (т.е. показывать игнорируемые)
          file_ignore_patterns = { "^%.git/" }, -- но исключить каталог .git
        })
      end, { desc = "Find all files (incl. ignored), excluding .git" })
    end,
  },

  -- telescope-fzf-native (ускоряет и улучшает fuzzy-поиск)
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make", -- для компиляции
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      require("telescope").load_extension("fzf")
    end,
  },
}
