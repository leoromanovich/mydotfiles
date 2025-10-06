
-- Отключение netrw в начале файла
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Установка leader key
vim.g.mapleader = " "

-- CUDA: filetype mapping
vim.filetype.add({
  extension = { cu = "cuda", cuh = "cuda" },
})

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

  -- Telescope
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('telescope').setup{
        defaults = {
          layout_strategy = 'horizontal',
          layout_config = {
            preview_width = 0.7,
          },
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
    -- CUDA: внешний парсер tree-sitter
    local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
    parser_config.cuda = {
      install_info = {
        url = "https://github.com/tree-sitter-grammars/tree-sitter-cuda",
        files = { "src/parser.c"},
      },
      filetype = "cuda",
    }
     require'nvim-treesitter.configs'.setup {
      ensure_installed = { "c", "cpp", "python", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "cuda" },

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
      -- ==== helpers (без lspconfig.util) ====
      local function path_exists(p) return vim.fn.executable(p) == 1 end
      local function join(a, b) return a .. '/' .. b end
      local function python_bin(dir) return join(join(dir, "bin"), "python") end
      -- выбрать бинарь из Mason, если он установлен
      local function mason_exe(exe)
        local bin = vim.fn.stdpath("data") .. "/mason/bin/" .. exe
        return (vim.fn.executable(bin) == 1) and bin or exe
       end

      -- корень проекта через vim.fs.find
      local function get_project_root(start_dir)
        local start = start_dir or vim.loop.cwd()
        local markers = {
          'pyproject.toml', 'poetry.lock', 'uv.lock',
          'requirements.txt', 'setup.py', 'setup.cfg',
          '.git'
        }
        local found = vim.fs.find(markers, { path = start, upward = true })[1]
        return found and vim.fs.dirname(found) or start
      end

      local function get_python_for(dir)
        local venv = os.getenv('VIRTUAL_ENV')
        if venv and path_exists(python_bin(venv)) then
          return python_bin(venv)
        end
        local conda = os.getenv('CONDA_PREFIX')
        if conda and path_exists(python_bin(conda)) then
          return python_bin(conda)
        end
        local root = get_project_root(dir)
        for _, name in ipairs({'.venv', 'venv', '.env'}) do
          local cand = python_bin(join(root, name))
          if path_exists(cand) then
            return cand
          end
        end
        local exepath = vim.fn.exepath('python3')
        if exepath ~= '' then return exepath end
        exepath = vim.fn.exepath('python')
        if exepath ~= '' then return exepath end
        return 'python'
      end


      -- capabilities от nvim-cmp (вкладываем в конкретные сервера)
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      ----------------------------------------------------------------------
      -- Pyright: динамически подставляем интерпретатор
      ----------------------------------------------------------------------

      vim.lsp.config('pyright', {
          cmd = { mason_exe("pyright-langserver"), "--stdio" },
          filetypes = { "python" },
          capabilities = capabilities,
          on_new_config = function(config, root_dir)
            local py = get_python_for(root_dir or vim.loop.cwd())
            config.settings = config.settings or {}
            config.settings.python = vim.tbl_deep_extend('force', config.settings.python or {}, {
              defaultInterpreterPath = py,
              pythonPath = py,
              analysis = { autoImportCompletions = true },
            })
          end,
      })
      ----------------------------------------------------------------------
      -- Clangd: CUDA-aware (filetypes + удобные флаги)
      ----------------------------------------------------------------------
      vim.lsp.config('clangd', {
        capabilities = capabilities,
        filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
        cmd = { 'clangd', '--clang-tidy', '--completion-style=detailed', '--header-insertion=never' },
      })

      -- при желании сразу включи Lua LS (раз уже ставишь через mason)
      vim.lsp.config('lua_ls', { capabilities = capabilities })

      -- включаем настроенные конфиги (активируются по их filetypes)
      vim.lsp.enable({ 'pyright', 'clangd', 'lua_ls' })

      -- Остальная часть твоих LSP-настроек (signcolumn, LspAttach) — без изменений
      vim.opt.signcolumn = 'yes'

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
      'folke/lazydev.nvim',
    },
    config = function()
      local cmp = require'cmp'

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
          { name = 'lazydev', group_index = 0 },
        }),
      })
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

      -- Настройка Python DAP (Unix)
      local function path_exists(p) return vim.fn.executable(p) == 1 end
      local function join(a, b) return a .. '/' .. b end
      local function python_bin(dir) return join(join(dir, "bin"), "python") end

      local function get_python_for(dir)
        local venv = os.getenv('VIRTUAL_ENV')
        if venv and path_exists(python_bin(venv)) then
          return python_bin(venv)
        end
        local conda = os.getenv('CONDA_PREFIX')
        if conda and path_exists(python_bin(conda)) then
          return python_bin(conda)
        end
        local exepath = vim.fn.exepath('python3')
        if exepath ~= '' then return exepath end
        exepath = vim.fn.exepath('python')
        if exepath ~= '' then return exepath end
        return 'python'
      end

      dap.adapters.python = {
        type = 'executable',
        command = get_python_for(vim.loop.cwd()),
        args = { '-m', 'debugpy.adapter' },
      }

      dap.configurations.python = {
        {
          type = 'python',
          request = 'launch',
          name = 'Launch with arguments',
          program = "${file}",
          cwd = "${workspaceFolder}",
          args = {},
          pythonPath = function()
            return get_python_for(vim.loop.cwd())
          end,
        },
      }
            -- CUDA DAP через cpptools + cuda-gdb
      dap.adapters.cppdbg = {
        id = "cppdbg",
        type = "executable",
        command = vim.fn.stdpath("data") .. "/mason/bin/OpenDebugAD7",
      }

      local function cuda_gdb_path()
        local p = os.getenv("CUDA_GDB") or "/usr/local/cuda/bin/cuda-gdb"
        return vim.fn.executable(p) == 1 and p or "cuda-gdb"
      end

      dap.configurations.cpp = {
        {
          name = "Launch (cuda-gdb)",
          type = "cppdbg",
          request = "launch",
          program = function()
            return vim.fn.input("Path to exe: ", vim.loop.cwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopAtEntry = false,
          MIMode = "gdb",
          miDebuggerPath = cuda_gdb_path(),
          setupCommands = {
            { text = "-enable-pretty-printing", description = "enable pretty printing", ignoreFailures = true },
          },
        },
      }
      dap.configurations.cuda = dap.configurations.cpp

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
  "jay-babu/mason-nvim-dap.nvim",
  dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
  config = function()
    require("mason-nvim-dap").setup({
      ensure_installed = { "cpptools" }, -- поставит OpenDebugAD7
      automatic_setup = true,
    })
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

  -- llm autocomplete --
  {
  'milanglacier/minuet-ai.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('minuet').setup {
      virtualtext = {
        auto_trigger_ft = { 'python' }, -- автоподсказки в .py
        keymap = {
          accept = '<A-A>',
          accept_line = '<A-a>',
          accept_n_lines = '<A-z>',
          prev = '<A-[>',     -- также вручную вызывает подсказку
          next = '<A-]>',     -- также вручную вызывает подсказку
          dismiss = '<A-e>',
        },
      },
      provider = 'openai_fim_compatible',
      n_completions = 1,
      context_window = 512,
      provider_options = {
        openai_fim_compatible = {
          api_key = 'TERM',  -- для Ollama можно любой непустой env var
          name = 'Ollama',
          end_point = 'http://localhost:11434/v1/completions',
          model = 'qwen2.5-coder:3b', -- при желании поставьте 7b
          stream = true,
          optional = {
            max_tokens = 64,
            top_p = 0.9,
          },
        },
      },
    }
  end,
},
    { 'nvim-lua/plenary.nvim' },
    -- optional, if you are using virtual-text frontend, nvim-cmp is not
    -- required.
    { 'hrsh7th/nvim-cmp' },
    -- optional, if you are using virtual-text frontend, blink is not required.
    { 'Saghen/blink.cmp' },
}

-- Настройка плагинов с помощью lazy.nvim
require("lazy").setup(plugins)

-- Общие настройки
vim.opt.termguicolors = true
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
vim.opt.timeoutlen = 1000
vim.opt.undofile = true
vim.opt.updatetime = 300
vim.opt.writebackup = false
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.cursorline = true
vim.opt.laststatus = 3
vim.opt.showcmd = false
vim.opt.ruler = false
vim.opt.numberwidth = 4
vim.opt.wrap = false
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8



-- folding --
vim.o.foldcolumn = "1"
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true

vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"


vim.api.nvim_create_autocmd('FileType', {
  pattern = 'qf',
  callback = function()
    local o = { buffer = true, silent = true }
    -- n/p — перейти к след./пред. валидной записи и вернуться в quickfix
    vim.keymap.set('n', 'n', '<Cmd>cnext<CR><C-w>p', o)
    vim.keymap.set('n', 'p', '<Cmd>cprev<CR><C-w>p', o)
  end,
})


-- :make running pytest from project root
local grp = vim.api.nvim_create_augroup('pytest_make_root', { clear = true })

local function project_root(buf)
  local f = vim.api.nvim_buf_get_name(buf)
  local start = (f ~= '' and vim.fs.dirname(f)) or vim.loop.cwd()
  local markers = { 'pyproject.toml', 'pytest.ini', 'setup.cfg', 'tox.ini', '.git' }
  local found = vim.fs.find(markers, { path = start, upward = true })[1]
  return found and vim.fs.dirname(found) or vim.loop.cwd()
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
  group = grp,
  pattern = { '*.py', 'pytest.ini', 'pyproject.toml', 'setup.cfg', 'tox.ini' },
  callback = function(args)
    local root = project_root(args.buf)
    -- Команда: cd в корень и запуск pytest по всему проекту
    vim.opt_local.makeprg = ('cd %s && python3 -m pytest --color=no .'):format(
      vim.fn.shellescape(root)
    )
    -- Парсинг ошибок в quickfix
    vim.opt_local.errorformat = table.concat({
      '%f:%l: %m',
      '%f:%l:%c: %m',
      '%-G%.%#',
    }, ',')
    -- Хоткей: <leader>m -> :make + quickfix
    vim.keymap.set('n', '<leader>m', function()
      vim.cmd('make')
      vim.cmd('copen')
    end, { buffer = true, desc = 'Run pytest from project root' })
  end,
})

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

-- vim.o.background = "dark" -- or "light" for light mode
vim.cmd([[colorscheme slate]])

do
  local ok1, _ = pcall(require, 'dap')
  local ok2, vscode = pcall(require, 'dap.ext.vscode')
  if ok1 and ok2 and vscode then
    -- Map "python" type in launch.json to nvim-dap's python adapter id(s)
    vscode.load_launchjs(nil, { python = { 'python' } })
  end
end
