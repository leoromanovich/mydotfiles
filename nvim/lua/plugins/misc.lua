return {
  { "nvim-tree/nvim-web-devicons" },
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "luvit-meta/library", words = { "vim%.uv" } },
      },
    },
  },
  {
    "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup({})
    end,
  },

  { "nvim-neotest/nvim-nio" },

  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup({
        toggler = { line = "gcc", block = "gbc" },
        opleader = { line = "gc", block = "gb" },
        mappings = { basic = true, extra = true },
      })
    end,
  },

  { "nvim-lua/plenary.nvim" },
  { "Saghen/blink.cmp" },
  {
    "L3MON4D3/LuaSnip",
    build = "make install_jsregexp",
    config = function()
      local ls = require("luasnip")

      -- базовые опции
      ls.config.set_config({
        history = true,
        updateevents = "TextChanged,TextChangedI",
        enable_autosnippets = true,
      })

      -- грузим сниппеты из папки ~/.config/nvim/lua/snippets
      require("luasnip.loaders.from_lua").lazy_load({
        paths = { vim.fn.stdpath("config") .. "/lua/snippets" },
      })

      -- (опционально) грузим community-варианты из friendly-snippets
      pcall(function()
        require("luasnip.loaders.from_vscode").lazy_load()
      end)

      -- хоткеи: прыжки/выбор
      vim.keymap.set({ "i", "s" }, "<C-j>", function()
        ls.expand_or_jump()
      end, { desc = "LuaSnip expand/jump" })
      vim.keymap.set({ "i", "s" }, "<C-k>", function()
        ls.jump(-1)
      end, { desc = "LuaSnip jump back" })
      vim.keymap.set("i", "<C-l>", function()
        if ls.choice_active() then
          ls.change_choice(1)
        end
      end, { desc = "LuaSnip next choice" })

      -- перезагрузка сниппетов без перезапуска Neovim
      vim.keymap.set("n", "<leader>us", function()
        require("luasnip").cleanup()
        require("luasnip.loaders.from_lua").lazy_load({
          paths = { vim.fn.stdpath("config") .. "/lua/snippets" },
        })
        vim.notify("Snippets reloaded", vim.log.levels.INFO)
      end, { desc = "Reload LuaSnip snippets" })
    end,
  },
}
