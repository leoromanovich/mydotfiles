-- Установка leader key
vim.g.mapleader = " "


vim.keymap.set("n", "<leader>d", function()
  vim.diagnostic.open_float(nil, { scope = "line" })
end, { desc = "Show diagnostics for the current line" })

-- Установка lazy.nvim, если он не установлен
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "--single-branch",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Определение списка плагинов
local plugins = {
  -- Plenary
  { 'nvim-lua/plenary.nvim' },

  -- Telescope
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local actions = require('telescope.actions')
      local actions_layout = require('telescope.actions.layout')
      require('telescope').setup{
      defaults = {
        layout_strategy = 'horizontal',
        layout_config = {
          preview_width = 0.7,
        },
        -- Настройка прокрутки превью
        preview = {
          -- Стратегия прокрутки: 'limit', 'cycle', 'unlimited'
          scroll_strategy = 'limit',
        },
        mappings = {
          i = {  -- Режим вставки
            -- Прокрутка превью
            ["<C-j>"] = actions.preview_scrolling_down,
            ["<C-k>"] = actions.preview_scrolling_up,
            -- Дополнительные полезные маппинги
            ["<C-n>"] = actions.cycle_history_next,
            ["<C-p>"] = actions.cycle_history_prev,
            ["<C-c>"] = actions.close,
          },
          n = {  -- Нормальный режим
            -- Прокрутка превью
            ["<C-j>"] = actions.preview_scrolling_down,
            ["<C-k>"] = actions.preview_scrolling_up,
            -- Дополнительные полезные маппинги
            ["j"] = actions.move_selection_next,
            ["k"] = actions.move_selection_previous,
            ["<C-c>"] = actions.close,
          },
        },
        -- Добавляем опцию для отображения номеров строк
        set_env = { ['LESS'] = '-N' },
      },
      }
      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
      vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
      vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
    end
  },

  -- telescope-fzf-native (ускоряет и улучшает fuzzy-поиск)
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'make',  -- для компиляции
    dependencies = { 'nvim-telescope/telescope.nvim' },
    config = function()
      require('telescope').load_extension('fzf')
    end
  },

  -- nvim-web-devicons
  { 'nvim-tree/nvim-web-devicons' },

  -- Nightfox тема
  {
    'EdenEast/nightfox.nvim',
    config = function()
      require('nightfox').setup()
      vim.cmd("colorscheme nightfox")
    end
  },

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

  -- nvim-treesitter
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      require'nvim-treesitter.configs'.setup {
        ensure_installed = { "c", "cpp", "python", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline" },
        sync_install = false,
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
      }
    end
  },

  -- Настройка LSP
  {
    'neovim/nvim-lspconfig',
    config = function()
      local lspconfig = require('lspconfig')
      -- Pyright настройка
      local function get_python_path(workspace)
        local conda_env = os.getenv('CONDA_PREFIX')
        if conda_env then
          return conda_env .. '/bin/python'
        end
        return 'python'
      end

      local function get_pyright_path()
        return 'pyright-langserver'
      end

      lspconfig.pyright.setup {
        cmd = { get_pyright_path(), "--stdio" },
        settings = {
          python = {
            pythonPath = get_python_path(vim.fn.getcwd())
          }
        }
      }

      -- Clangd настройка
      lspconfig.clangd.setup {}

      -- Настройки LSP
      vim.opt.signcolumn = 'yes'

      -- Добавление capabilities для nvim-cmp
      local lspconfig_defaults = lspconfig.util.default_config
      lspconfig_defaults.capabilities = vim.tbl_deep_extend(
        'force',
        lspconfig_defaults.capabilities,
        require('cmp_nvim_lsp').default_capabilities()
      )

      -- Маппинги LSP
      vim.api.nvim_create_autocmd('LspAttach', {
        desc = 'LSP actions',
        callback = function(event)
          local opts = {buffer = event.buf}
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
          vim.keymap.set('n', 'go', vim.lsp.buf.type_definition, opts)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
          vim.keymap.set('n', 'gs', vim.lsp.buf.signature_help, opts)
          vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, opts)
          vim.keymap.set({'n', 'x'}, '<F3>', function() vim.lsp.buf.format { async = true } end, opts)
          vim.keymap.set('n', '<F4>', vim.lsp.buf.code_action, opts)
        end,
      })
    end
  },


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

  -- nvim-cmp и LuaSnip
{
  'hrsh7th/nvim-cmp',
  dependencies = {
    'hrsh7th/cmp-nvim-lsp',
    'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-path',
    'saadparwaiz1/cmp_luasnip',
    'L3MON4D3/LuaSnip',
    'folke/lazydev.nvim',  -- Добавляем lazydev.nvim в зависимости
  },
  config = function()
    local cmp = require'cmp'

    -- Ваш текущий конфиг nvim-cmp
    cmp.setup({
      snippet = {
        expand = function(args)
          require('luasnip').lsp_expand(args.body)
        end,
      },
      mapping = {
        ['<C-y>'] = cmp.mapping.scroll_docs(-4),
        ['<C-e>'] = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<C-x>'] = cmp.mapping.close(),
        ['<CR>'] = cmp.mapping.confirm({ select = true }),
        ['<C-n>'] = cmp.mapping.select_next_item(),
        ['<C-p>'] = cmp.mapping.select_prev_item(),
      },
      sources = cmp.config.sources({
        { name = 'nvim_lsp' },
        { name = 'buffer' },
        { name = 'path' },
        { name = 'luasnip' },
        { name = 'vim_tabby' },
        -- Добавляем источник lazydev
        { name = 'lazydev', group_index = 0 },
      }),
    })
  end
},


-- lsp-zero
  {
    'VonHeikemen/lsp-zero.nvim',
    branch = 'v4.x',
    dependencies = {
      'neovim/nvim-lspconfig',
      'hrsh7th/nvim-cmp',
      'L3MON4D3/LuaSnip',
    },
    config = function()
      -- Конфигурация lsp-zero (если необходима)
    end
  },

    {
    'windwp/nvim-autopairs',
    config = function()
      require('nvim-autopairs').setup({})
    end
  },

  -- nvim-nio
  { 'nvim-neotest/nvim-nio' },

  -- nvim-dap и dap-ui
  {
    'mfussenegger/nvim-dap',
    config = function()
      local dap = require('dap')

      -- Настройка для Python
      local function get_python_path()
        local conda_env = os.getenv('CONDA_PREFIX')
        if conda_env then
          return conda_env .. '/bin/python'
        end
        return 'python'
      end

      dap.adapters.python = {
        type = 'executable',
        command = get_python_path(),
        args = { '-m', 'debugpy.adapter' },
      }

      dap.configurations.python = {
        {
          type = 'python',
          request = 'launch',
          name = 'Launch with arguments',
          program = "${file}",
          args = {},
          pythonPath = function()
            return get_python_path()
          end,
        },
      }

      -- Маппинги для nvim-dap
      vim.keymap.set('n', '<F5>', function() dap.continue() end, { noremap = true, silent = true })
      vim.keymap.set('n', '<F10>', function() dap.step_over() end, { noremap = true, silent = true })
      vim.keymap.set('n', '<F11>', function() dap.step_into() end, { noremap = true, silent = true })
      vim.keymap.set('n', '<F12>', function() dap.step_out() end, { noremap = true, silent = true })
      vim.keymap.set('n', '<leader>b', function() dap.toggle_breakpoint() end, { noremap = true, silent = true })
      vim.keymap.set('n', '<leader>B', function() dap.set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, { noremap = true, silent = true })
      vim.keymap.set('n', '<leader>lp', function() dap.set_breakpoint(nil, nil, vim.fn.input('Log point message: ')) end, { noremap = true, silent = true })
      vim.keymap.set('n', '<leader>dr', function() dap.repl.open() end, { noremap = true, silent = true })
      vim.keymap.set('n', '<leader>dl', function() dap.run_last() end, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>dt", function() dap.terminate() end, { noremap = true, silent = true })
    end
  },
  {
    'rcarriga/nvim-dap-ui',
    dependencies = { 'mfussenegger/nvim-dap' },
    config = function()
      local dap = require('dap')
      local dapui = require('dapui')
      dapui.setup({
        icons = { expanded = "▾", collapsed = "▸" },
        mappings = {
          expand = { "<CR>", "<2-LeftMouse>" },
          open = "o",
          remove = "d",
          edit = "e",
          repl = "r",
        },
        sidebar = {
          open_on_start = true,
          elements = {
            { id = "scopes", size = 0.25 },
            { id = "breakpoints", size = 0.25 },
            { id = "stacks", size = 0.25 },
            { id = "watches", size = 0.25 },
          },
          size = 40,
          position = "left",
        },
        tray = {
          open_on_start = true,
          elements = { "repl" },
          size = 10,
          position = "bottom",
        },
        floating = {
          max_height = 0.9,
          max_width = 0.5,
          border = "rounded",
          mappings = {
            close = { "q", "<Esc>" },
          },
        },
      })

      -- Автоматическое открытие/закрытие dap-ui
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end
  },

  -- Mason
  {
    'williamboman/mason.nvim',
    config = function()
      require('mason').setup()
    end
  },
  {
    'williamboman/mason-lspconfig.nvim',
    dependencies = { 'williamboman/mason.nvim', 'neovim/nvim-lspconfig' },
    config = function()
      require('mason-lspconfig').setup {
        ensure_installed = { "clangd", "lua_ls", "pyright" },
      }
    end
  },

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
  -- Plenary
  { 'nvim-lua/plenary.nvim' },


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

    -- Harpoon
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    -- config = function()
    --   local harpoon = require("harpoon")
    --   harpoon.setup()
    --   local ui = require("harpoon.ui")
    --   local mark = require("harpoon.mark")
    --
    --   vim.keymap.set("n", "<leader>a", mark.add_file, { noremap = true, silent = true })
    --   vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu, { noremap = true, silent = true })
    --
    --   vim.keymap.set("n", "<C-h>", function() ui.nav_file(1) end, { noremap = true, silent = true })
    --   vim.keymap.set("n", "<C-t>", function() ui.nav_file(2) end, { noremap = true, silent = true })
    --   vim.keymap.set("n", "<C-n>", function() ui.nav_file(3) end, { noremap = true, silent = true })
    --   vim.keymap.set("n", "<C-s>", function() ui.nav_file(4) end, { noremap = true, silent = true })
    --
    --   vim.keymap.set("n", "<C-S-P>", ui.nav_prev, { noremap = true, silent = true })
    --   vim.keymap.set("n", "<C-S-N>", ui.nav_next, { noremap = true, silent = true })
    -- end
  },

  --------------------------------------------------------------------------------
  -- gitsigns (подсветка изменений в гуттере + Git-команды)
  --------------------------------------------------------------------------------
  {
    'lewis6991/gitsigns.nvim',
    config = function()
      require('gitsigns').setup({
        signs = {
          add          = { text = '│' },
          change       = { text = '│' },
          delete       = { text = '_' },
          topdelete    = { text = '‾' },
          changedelete = { text = '~' },
        },
      })
    end
  },


  -- TabbyML/vim-tabby
  {
    'TabbyML/vim-tabby',
    config = function()
      vim.g.tabby_agent_start_command = {"npx", "tabby-agent", "--stdio"}
      vim.g.tabby_inline_completion_trigger = "manual"
      vim.g.tabby_inline_completion_keybinding_accept = "<Tab>"
      vim.g.tabby_inline_completion_keybinding_trigger_or_dismiss = "<C-\\>"
      vim.g.tabby_inline_completion_insertion_leading_key = "<C-R><C-O>="
    end
  },
}

-- Настройка плагинов с помощью lazy.nvim
require("lazy").setup(plugins)

-- Общие настройки
vim.opt.termguicolors = true
vim.opt.scrolloff = 5
vim.opt.mouse = "a"
vim.opt.number = true
vim.opt.backup = false
vim.opt.cmdheight = 1
vim.opt.completeopt = { "menuone", "noselect" }
vim.opt.conceallevel = 0
vim.opt.fileencoding = "utf-8"
vim.opt.hlsearch = true
vim.opt.ignorecase = true
vim.opt.pumheight = 10
vim.opt.showmode = true
vim.opt.showtabline = 0
vim.opt.smartcase = true
vim.opt.smartindent = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.swapfile = false
vim.opt.termguicolors = true
vim.opt.timeoutlen = 1000
vim.opt.undofile = true
vim.opt.updatetime = 300
vim.opt.writebackup = false
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.cursorline = true
vim.opt.number = true
vim.opt.laststatus = 3
vim.opt.showcmd = false
vim.opt.ruler = false
vim.opt.numberwidth = 4
vim.opt.signcolumn = "yes"
vim.opt.wrap = false
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8


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


-- Отключение netrw в начале файла
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1


-- Функция для поиска корня репозитория
local function get_git_root()
  local git_dir = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if vim.v.shell_error == 0 then
    return git_dir
  end
  return nil
end

-- Автокоманда для установки PYTHONPATH при открытии файла/папки
vim.api.nvim_create_autocmd({"BufEnter", "DirChanged"}, {
  callback = function()
    local root = get_git_root()
    if root then
      vim.env.PYTHONPATH = root
      print("PYTHONPATH set to: " .. root)
    else
      print("Could not determine git root.")
    end
  end,
})

