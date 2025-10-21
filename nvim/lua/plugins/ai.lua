return {
  {
    'yetone/avante.nvim',
    build = 'make',  -- у плагина есть сборочный шаг
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      -- avante рекомендует markdown-рендерер
      'MeanderingProgrammer/render-markdown.nvim',
      -- иконки (для UI панелей)
      'echasnovski/mini.icons',
    },
    config = function()
      -- базовый рендерер Markdown, чтобы чат красиво отображался
      require('render-markdown').setup({})

      -- Минимальная настройка Avante под OpenAI-совместимую точку на 30000
      require('avante').setup({
        -- используем кастомного провайдера, наследованного от openai
        provider = 'sglang',
        providers = {
          sglang = {
            __inherited_from = 'openai',
            endpoint = 'http://localhost:30000/v1', -- база (не /chat/completions)
            api_key_name = 'TERM',                  -- подставит Authorization: Bearer $TERM
            model = 'qwen2.5-coder:7b',
            timeout = 30000,                        -- мс
            -- ВАЖНО: если твой сервер не поддерживает OpenAI tools/function-calling,
            -- раскомментируй следующую строку (тогда файлы будут передаваться простым текстом):
            -- disable_tools = true,
          },
        },

        -- поведение по умолчанию: чат в боковой панели, можно читать файлы/глобить и т.д.
        -- оставляем дефолты максимально «минимальными»
      })

      -- Быстрые хоткеи (минимум для старта)
      vim.keymap.set('n', '<leader>aa', function()
        require('avante').toggle()  -- открыть/закрыть чат (sidebar)
      end, { desc = 'Avante: Chat sidebar' })

      vim.keymap.set({ 'n', 'x' }, '<leader>ae', function()
        require('avante.api').edit()    -- режим правок по выделению (кратко: «сделай вот это с этим кодом»)
      end, { desc = 'Avante: Edit selection' })
    end,
  },
 
  {
  'milanglacier/minuet-ai.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    -- 1) Основная настройка minuet + два пресета
    require('minuet').setup {
      -- твои хоткеи и авто-триггер
      virtualtext = {
        auto_trigger_ft = { 'python' },
        keymap = {
          accept = '<A-A>',
          accept_line = '<A-a>',
          accept_n_lines = '<A-z>',
          prev = '<A-[>',
          next = '<A-]>',
          dismiss = '<A-e>',
        },
        debounce = 250,
        context = { max_prefix_lines = 600, max_suffix_lines = 200, max_buffer_size_kb = 2048 },
      },

      provider = 'openai_fim_compatible',
      n_completions = 1,
      context_window = 2048,
      notify = false, -- ТИШИНА при ошибках

      -- два пресета: локальный на 31313 и запасной Ollama на 11434
      presets = {
        sglang_coder = {
          provider = 'openai_fim_compatible',
          provider_options = {
            openai_fim_compatible = {
              name = 'sglang_coder',
              end_point = 'http://localhost:31313/v1/completions',
              api_key = function() return 'dummy' end, -- гарантированно непустой
              model = 'coder',
              stream = true,
              optional = { max_tokens = 150, top_p = 0.9, temperature = 0.1 },
            },
          },
        },
        ollama = {
          provider = 'openai_fim_compatible',
          provider_options = {
            openai_fim_compatible = {
              name = 'ollama',
              end_point = 'http://localhost:11434/v1/completions',
              api_key = function() return 'dummy' end,
              model = 'qwen2.5-coder:3b',
              stream = true,
              optional = { max_tokens = 50, top_p = 0.9, temperature = 0.1 },
            },
          },
        },
      },
    }

    -- 2) «Тихие» хоткеи (не всплывают ошибки, если сервер мёртв)
    vim.keymap.set('i', '<C-;>', function() pcall(function() require('minuet').complete() end) end,
      { desc = 'Minuet: complete (silent)' })
    vim.keymap.set('i', '<A-;>', function() pcall(function() require('minuet').accept_or_complete() end) end,
      { desc = 'Minuet: accept/continue (silent)' })

    -- 3) Тихий health-check: чистый TCP-пинг порта (без curl и ошибок в :messages)
    local function port_open(host, port, timeout_ms)
      local uv = vim.loop
      local sock = uv.new_tcp()
      local done, ok = false, false
      sock:connect(host, port, function(err)
        ok = (err == nil)
        pcall(function() sock:shutdown() end)
        pcall(function() sock:close() end)
        done = true
      end)
      vim.wait(timeout_ms or 800, function() return done end, 50)
      if not done then pcall(function() sock:close() end) end
      return ok
    end

    -- 4) На старте: если 31313 закрыт — переключаемся на пресет Ollama
    vim.api.nvim_create_autocmd('VimEnter', {
      once = true,
      callback = function()
        if port_open('127.0.0.1', 31313, 800) then
          vim.cmd('Minuet change_preset sglang_coder')
        else
          vim.cmd('Minuet change_preset ollama')
        end
      end,
    })
  end,
} 
}
