return {
  {
    'milanglacier/minuet-ai.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local curl = require('plenary.curl')

      local OLLAMA_ENDPOINT  = 'http://localhost:11434/v1/completions'
      local OLLAMA_MODEL     = 'qwen2.5-coder:3b'

      local SGLANG_ENDPOINT  = 'http://localhost:30000/v1/completions'
      local SGLANG_MODEL     = 'qwen2.5-coder:7b'

      local function alive(url, model)
        local ok, res = pcall(function()
          return curl.post(url, {
            timeout = 1200, -- мс
            headers = {
              ['Content-Type'] = 'application/json',
              ['Authorization'] = 'Bearer TERM',
            },
            body = vim.json.encode({
              model = model,
              prompt = "<fim_prefix>ping<fim_suffix><fim_middle>",
              max_tokens = 1,
              stream = false,
            }),
          })
        end)
        if not ok or not res or res.status ~= 200 then return false end
        local okj, data = pcall(vim.json.decode, res.body)
        return okj and data and data.choices ~= nil
      end

      local ENDPOINT, MODEL, NAME = OLLAMA_ENDPOINT, OLLAMA_MODEL, 'Ollama'
      if alive(OLLAMA_ENDPOINT, OLLAMA_MODEL) then
        vim.notify('[minuet] использую Ollama (11434), модель: ' .. OLLAMA_MODEL, vim.log.levels.INFO)
      elseif alive(SGLANG_ENDPOINT, SGLANG_MODEL) then
        ENDPOINT, MODEL, NAME = SGLANG_ENDPOINT, SGLANG_MODEL, 'SGLang'
        vim.notify('[minuet] основной недоступен, использую SGLang (30000), модель: ' .. SGLANG_MODEL, vim.log.levels.WARN)
      else
        vim.notify('[minuet] ни Ollama:11434, ни SGLang:30000 не отвечают — оставляю Ollama по умолчанию', vim.log.levels.ERROR)
      end

      require('minuet').setup {
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
        },
        provider = 'openai_fim_compatible',
        n_completions = 1,
        context_window = 512,
        provider_options = {
          openai_fim_compatible = {
            api_key = 'TERM',
            name = NAME,          -- 'Ollama' или 'SGLang'
            end_point = ENDPOINT, -- выбранный эндпоинт
            model = MODEL,        -- 3b для Ollama, 7b для SGLang
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
