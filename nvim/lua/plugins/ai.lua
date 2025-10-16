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
    require('minuet').setup {
      provider = 'openai_compatible',
      openai_compatible = {
        endpoint = 'http://localhost:31313/v1/completions', -- оставляем completions
        model = 'coder',

        -- Генерация
        max_tokens = 150,   -- увеличиваем длину ответа
        temperature = 0.1,   -- для кода лучше пониже
        top_p = 0.9,
        frequency_penalty = 0.0,
        presence_penalty = 0.0,
        timeout = 20000,     -- мс

        -- Если на сервере нужен ключ — просто экспортируй OPENAI_API_KEY
        -- api_key_name = 'OPENAI_API_KEY',
      },

      -- Виртуальные подсказки
      notify = true,
      virtualtext = {
        auto_trigger = true,
        auto_trigger_ft = { 'python', 'lua', 'javascript', 'typescript', 'go', 'rust', 'cpp' },
        -- Немного «жаднее» контекста вокруг курсора
        -- (minuet сам вырежет лишнее по окну контекста)
        context = {
          max_prefix_lines = 600,  -- сколько строк брать «сверху»
          max_suffix_lines = 200,  -- сколько строк «снизу»
          max_buffer_size_kb = 2048, -- отсечь очень большие файлы
        },
        debounce = 120, -- не спамить запросами при быстром наборе
      },

      -- Глобальные ограничения контекста (страховка, если файл огромный)
      context_window = 16000,  -- примерно сколько токенов/символов пытаться уместить
    }

    -- Ручной триггер подсказки под курсором
    vim.keymap.set('i', '<C-;>', function()
      require('minuet').complete()
    end, { desc = 'Minuet: complete at cursor' })

    -- Добрать подсказку ещё (если модель поддерживает продолжение)
    vim.keymap.set('i', '<A-;>', function()
      require('minuet').accept_or_complete()
    end, { desc = 'Minuet: accept or continue' })
  end,
}
}
