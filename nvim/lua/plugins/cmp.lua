return {
  -- blink.cmp + LuaSnip + lazydev
  {
    "saghen/blink.cmp",
    version = "1.*", -- стабильные релизы
    dependencies = {
      "L3MON4D3/LuaSnip",
      { "folke/lazydev.nvim", ft = "lua", opts = {} },
      { "rafamadriz/friendly-snippets", lazy = true },
    },
    opts = {
      fuzzy = { implementation = "prefer_rust" },
      keymap = {
        preset = "enter", -- включает <CR>, <C-Space>, <C-n>/<C-p>, Tab/S-Tab и т.д.
        ["<C-y>"] = { "scroll_documentation_up", "fallback" },
        ["<C-e>"] = { "scroll_documentation_down", "fallback" },
        ["<C-x>"] = { "hide", "fallback" },
      },

      completion = {
        list = { selection = { preselect = true, auto_insert = false } }, -- чтобы <CR> подтверждал выбранное, как раньше
        documentation = { auto_show = true, auto_show_delay_ms = 100 },
        ghost_text = { enabled = true },
      },

      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        per_filetype = {
          lua = { inherit_defaults = true, "lazydev" },
        },
        providers = {
          lazydev = {
            name = "LazyDev",
            module = "lazydev.integrations.blink",
            score_offset = 100, -- поднимаем приоритет
          },
        },
      },

      signature = { enabled = true },
      snippets = {
        preset = "luasnip",
      },
    },
  },
}
