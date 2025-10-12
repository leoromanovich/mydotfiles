return {
  -- nvim-tree
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    branch = 'master',
    config = function()
      require("nvim-tree").setup({
        view = {
          width = 40,
        },
        filters={
            dotfiles=false,
            custom={},
        },
        git={
            ignore = false,
        },
      })
      vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })
    end
  },
}
