return {
-- {
--   "milanglacier/minuet-ai.nvim",
--   dependencies = { "nvim-lua/plenary.nvim" },
--   config = function()
--     -- читаем окружение
--     local endpoint = vim.fn.getenv("MINUET_FIM_ENDPOINT")
--     local model    = vim.fn.getenv("MINUET_MODEL")
--     local api_key  = vim.fn.getenv("MINUET_API_KEY")  -- можно не задавать для локальных серверов
--
--     -- функция для ключа: если ключ не нужен (локальный сервер), вернём "dummy"
--     local api_key_fn = function()
--       if api_key ~= vim.NIL and api_key ~= "" then
--         return api_key
--       end
--       return "dummy"
--     end
--
--     require("minuet").setup({
--       -- виртуальный текст + хоткеи, как у вас
--       virtualtext = {
--         auto_trigger_ft = { "python" },
--         keymap = {
--           accept = "<A-A>",
--           accept_line = "<A-a>",
--           accept_n_lines = "<A-z>",
--           prev = "<A-[>",
--           next = "<A-]>",
--           dismiss = "<A-e>",
--         },
--         debounce = 250,
--         context = { max_prefix_lines = 4000, max_suffix_lines = 4000, max_buffer_size_kb = 2048 },
--       },
--
--       -- один провайдер: OpenAI FIM совместимый (/v1/completions)
--       provider = "openai_fim_compatible",
--       n_completions = 1,
--       context_window = 8192,
--       notify = false,
--
--       provider_options = {
--         openai_fim_compatible = {
--           name = "env_fim",
--           end_point = (endpoint ~= vim.NIL and endpoint ~= "" and endpoint) or "http://localhost:11434/v1/completions",
--           api_key = api_key_fn,              -- читаем значение из MINUET_API_KEY (или "dummy")
--           model = (model ~= vim.NIL and model ~= "" and model) or "qwen2.5-coder:3b",
--           stream = true,
--           optional = { max_tokens = 64, top_p = 0.9, temperature = 0.1, stop = { "\n" } },
--         },
--       },
--     })
--
--     vim.keymap.set("i", "<C-;>", function()
--       pcall(function() require("minuet").complete() end)
--     end, { desc = "Minuet: complete (silent)" })
--
--     vim.keymap.set("i", "<A-;>", function()
--       pcall(function() require("minuet").accept_or_complete() end)
--     end, { desc = "Minuet: accept/continue (silent)" })
--   end,
-- }
{
  "ggml-org/llama.vim",
  init = function()
    vim.g.llama_config = {
      endpoint = "http://127.0.0.1:8012/infill",
      auto_fim = true,            -- временно ручной режим
      show_info = false,
      -- дай модели больше окружения вокруг курсора:
      context = { before = 8000, after = 4000, ring = 64 },
      ft = { "python", "lua", "cpp", "c", "javascript", "typescript", "rust" },

      -- твои хоткеи
      keymap_accept_full = "<A-A>",
      keymap_accept_line = "<A-a>",
      keymap_accept_multi = "<A-z>",
      keymap_prev = "<A-[>",
      keymap_next = "<A-]>",
      keymap_dismiss = "<A-e>",
      keymap_toggle = "<C-;>",

      -- ограничим длину, чтобы не улетать в «магические» импорты
      max_tokens = 64,
      temperature = 0.1,
      top_p = 0.9,
    }
  end,
}
}
