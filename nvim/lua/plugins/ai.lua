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
        require('avante').edit()    -- режим правок по выделению (кратко: «сделай вот это с этим кодом»)
      end, { desc = 'Avante: Edit selection' })
    end,
  },
}
