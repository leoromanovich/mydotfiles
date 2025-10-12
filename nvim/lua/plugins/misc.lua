return {
  -- nvim-web-devicons
  { 'nvim-tree/nvim-web-devicons' },

   -- Установка lazydev.nvim для автодополнения при редактировании конфигов Neovim
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        -- Настройки библиотеки (опционально)
        { path = "luvit-meta/library", words = { "vim%.uv" } },
      },
    },
  },


  {
    'windwp/nvim-autopairs',
    config = function()
      require('nvim-autopairs').setup({})
    end
  },

  -- nvim-nio
  { 'nvim-neotest/nvim-nio' },

  -- Comment.nvim
  {
    'numToStr/Comment.nvim',
    config = function()
      require('Comment').setup({
        toggler = {
          line = 'gcc',
          block = 'gbc',
        },
        opleader = {
          line = 'gc',
          block = 'gb',
        },
        mappings = {
          basic = true,
          extra = true,
        },
      })
    end
  },


    { 'nvim-lua/plenary.nvim' },
    -- optional, if you are using virtual-text frontend, nvim-cmp is not
    -- required.
    { 'hrsh7th/nvim-cmp' },
    -- optional, if you are using virtual-text frontend, blink is not required.
    { 'Saghen/blink.cmp' },
}
