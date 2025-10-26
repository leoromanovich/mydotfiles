return {
  {
    "yetone/avante.nvim",
    build = "make", -- у плагина есть сборочный шаг
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "MeanderingProgrammer/render-markdown.nvim",
      "echasnovski/mini.icons",
    },
    config = function()
      require("render-markdown").setup({})

      require("avante").setup({
        provider = "sglang",
        providers = {
          sglang = {
            __inherited_from = "openai",
            endpoint = "http://localhost:30000/v1", -- база (не /chat/completions)
            api_key_name = "TERM", -- подставит Authorization: Bearer $TERM
            model = "qwen2.5-coder:7b",
            timeout = 30000, -- мс
          },
        },
      })

      -- Быстрые хоткеи (минимум для старта)
      vim.keymap.set("n", "<leader>aa", function()
        require("avante").toggle() -- открыть/закрыть чат (sidebar)
      end, { desc = "Avante: Chat sidebar" })

      vim.keymap.set({ "n", "x" }, "<leader>ae", function()
        require("avante.api").edit() -- режим правок по выделению (кратко: «сделай вот это с этим кодом»)
      end, { desc = "Avante: Edit selection" })
    end,
  },

{
  "milanglacier/minuet-ai.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    -- читаем окружение
    local endpoint = vim.fn.getenv("MINUET_FIM_ENDPOINT")
    local model    = vim.fn.getenv("MINUET_MODEL")
    local api_key  = vim.fn.getenv("MINUET_API_KEY")  -- можно не задавать для локальных серверов

    -- функция для ключа: если ключ не нужен (локальный сервер), вернём "dummy"
    local api_key_fn = function()
      if api_key ~= vim.NIL and api_key ~= "" then
        return api_key
      end
      return "dummy"
    end

    require("minuet").setup({
      -- виртуальный текст + хоткеи, как у вас
      virtualtext = {
        auto_trigger_ft = { "python" },
        keymap = {
          accept = "<A-A>",
          accept_line = "<A-a>",
          accept_n_lines = "<A-z>",
          prev = "<A-[>",
          next = "<A-]>",
          dismiss = "<A-e>",
        },
        debounce = 250,
        context = { max_prefix_lines = 4000, max_suffix_lines = 4000, max_buffer_size_kb = 2048 },
      },

      -- один провайдер: OpenAI FIM совместимый (/v1/completions)
      provider = "openai_fim_compatible",
      n_completions = 1,
      context_window = 8192,
      notify = false,

      provider_options = {
        openai_fim_compatible = {
          name = "env_fim",
          end_point = (endpoint ~= vim.NIL and endpoint ~= "" and endpoint) or "http://localhost:11434/v1/completions",
          api_key = api_key_fn,              -- читаем значение из MINUET_API_KEY (или "dummy")
          model = (model ~= vim.NIL and model ~= "" and model) or "qwen2.5-coder:3b",
          stream = true,
          optional = { max_tokens = 64, top_p = 0.9, temperature = 0.1, stop = { "\n" } },
        },
      },
    })

    vim.keymap.set("i", "<C-;>", function()
      pcall(function() require("minuet").complete() end)
    end, { desc = "Minuet: complete (silent)" })

    vim.keymap.set("i", "<A-;>", function()
      pcall(function() require("minuet").accept_or_complete() end)
    end, { desc = "Minuet: accept/continue (silent)" })
  end,
}}
