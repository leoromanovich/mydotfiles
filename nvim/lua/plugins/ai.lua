return {
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
}
