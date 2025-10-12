return {
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
}
