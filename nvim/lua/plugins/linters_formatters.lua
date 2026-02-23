return {
  {
    "stevearc/conform.nvim",
    event = "VeryLazy",
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          lua = { "stylua" },
          python = { "isort", "black" },
        },
        formatters = {
          black = { prepend_args = { "--fast" } },
          stylua = {
            prepend_args = {
              "--indent-type",
              "Spaces",
              "--indent-width",
              "2",
              "--column-width",
              "100",
            },
          },
        },
        notify_on_error = true,
      })
    end,
  },
  {
    "mfussenegger/nvim-lint",
    event = "VeryLazy",
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        python = { "mypy" },
      }

      local function get_project_root(start_dir)
        local start = start_dir or vim.loop.cwd()
        local markers = {
          "pyproject.toml",
          "mypy.ini",
          "setup.cfg",
          "tox.ini",
          ".git",
        }
        local found = vim.fs.find(markers, { path = start, upward = true })[1]
        return found and vim.fs.dirname(found) or start
      end

      local function find_mypy_config(root)
        local candidates = { "mypy.ini", "pyproject.toml", "setup.cfg", "tox.ini" }
        local found = vim.fs.find(candidates, { path = root, upward = false })[1]
        return found
      end

      local base_mypy_args = {
        "--python-executable",
        vim.fn.exepath("python"),
        "--show-column-numbers",
        "--show-error-end",
        "--no-error-summary",
      }

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        callback = function()
          if vim.bo.filetype ~= "python" then
            return
          end
          if vim.fn.executable("mypy") ~= 1 then
            return
          end
          local buf_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
          local root = get_project_root(buf_dir)
          local config_file = find_mypy_config(root)
          local args = vim.list_extend({}, base_mypy_args)
          if config_file then
            table.insert(args, "--config-file")
            table.insert(args, config_file)
          end
          lint.linters.mypy.args = args
          lint.try_lint("mypy")
        end,
      })
    end,
  },
}
