return {
  -- nvim-dap и dap-ui
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require("dap")

      local function path_exists(p)
        return vim.fn.executable(p) == 1
      end
      local function join(a, b)
        return a .. "/" .. b
      end
      local function python_bin(dir)
        return join(join(dir, "bin"), "python")
      end

      local function get_python_for()
        local venv = os.getenv("VIRTUAL_ENV")
        if venv and path_exists(python_bin(venv)) then
          return python_bin(venv)
        end
        local conda = os.getenv("CONDA_PREFIX")
        if conda and path_exists(python_bin(conda)) then
          return python_bin(conda)
        end
        local exepath = vim.fn.exepath("python3")
        if exepath ~= "" then
          return exepath
        end
        exepath = vim.fn.exepath("python")
        if exepath ~= "" then
          return exepath
        end
        return "python"
      end

      dap.set_exception_breakpoints({ "raised", "uncaught" })
      local cache = vim.fn.stdpath("cache")
      vim.fn.mkdir(cache .. "/debugpy", "p")

      dap.adapters.python = function(cb)
        cb({
          type = "executable",
          command = get_python_for(),
          args = { "-m", "debugpy.adapter" },
          options = { env = { DEBUGPY_LOG_DIR = cache .. "/debugpy" } }, -- логи debugpy
        })
      end

      dap.configurations.python = {
        {
          name = "Launch current file",
          type = "python",
          request = "launch", -- <── ОБЯЗАТЕЛЬНО
          program = "${file}",
          cwd = "${workspaceFolder}", -- стабильнее на macOS
          console = "integratedTerminal", -- по желанию
          pythonPath = function()
            return get_python_for()
          end,
          justMyCode = false, -- чтобы видеть и сторонний код (по желанию)
          redirectOutput = true, -- <— traceback и print попадут в DAP REPL
          -- console = "integratedTerminal", -- альтернатива: открыть отдельный терминал
          showReturnValue = true,
        },
      } -- CUDA DAP через cpptools + cuda-gdb
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
            {
              text = "-enable-pretty-printing",
              description = "enable pretty printing",
              ignoreFailures = true,
            },
          },
        },
      }
      dap.configurations.cuda = dap.configurations.cpp

      -- Маппинги для nvim-dap
      vim.keymap.set("n", "<F5>", function()
        dap.continue()
      end, { noremap = true, silent = true })
      vim.keymap.set("n", "<F10>", function()
        dap.step_over()
      end, { noremap = true, silent = true })
      vim.keymap.set("n", "<F11>", function()
        dap.step_into()
      end, { noremap = true, silent = true })
      vim.keymap.set("n", "<F12>", function()
        dap.step_out()
      end, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>b", function()
        dap.toggle_breakpoint()
      end, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>B", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>lp", function()
        dap.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
      end, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>dr", function()
        dap.repl.open()
      end, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>dl", function()
        dap.run_last()
      end, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>dt", function()
        dap.terminate()
      end, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>dc", function()
        dap.clear_breakpoints()
      end, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>du", function()
        require("dapui").toggle({ reset = true })
      end, { desc = "DAP UI toggle" })
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- ---@diagnostic disable-next-line: missing-fields
      dapui.setup({
        expand_lines = true,
        force_buffers = true,

        element_mappings = {
          scopes = { expand = { "<CR>", "<2-LeftMouse>" }, edit = "e", repl = "r" },
          watches = { expand = "<CR>", remove = "d", edit = "e", repl = "r" },
          breakpoints = { open = "o", toggle = "t" },
        },

        layouts = {
          {
            position = "left",
            size = 40, -- кол-во колонок (или 0.x как доля ширины)
            elements = {
              { id = "scopes", size = 0.25 },
              { id = "breakpoints", size = 0.25 },
              { id = "stacks", size = 0.25 },
              { id = "watches", size = 0.25 },
            },
          },
          {
            position = "bottom",
            size = 40, -- кол-во строк
            elements = { { id = "repl", size = 1 } },
          },
        },

        controls = {
          enabled = true,
          element = "repl",
          -- icons = { ... } -- можешь переопределить при желании
        },

        render = {
          max_type_length = nil,
          max_value_lines = 100,
        },
      })

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },
}
