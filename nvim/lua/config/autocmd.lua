-- :make running pytest from project root
local grp = vim.api.nvim_create_augroup("pytest_make_root", { clear = true })

local function project_root(buf)
  local f = vim.api.nvim_buf_get_name(buf)
  local start = (f ~= "" and vim.fs.dirname(f)) or vim.loop.cwd()
  local markers = { "pyproject.toml", "pytest.ini", "setup.cfg", "tox.ini", ".git" }
  local found = vim.fs.find(markers, { path = start, upward = true })[1]
  return found and vim.fs.dirname(found) or vim.loop.cwd()
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  group = grp,
  pattern = { "*.py", "pytest.ini", "pyproject.toml", "setup.cfg", "tox.ini" },
  callback = function(args)
    local root = project_root(args.buf)
    -- Команда: cd в корень и запуск pytest по всему проекту
    vim.opt_local.makeprg = ("cd %s && python3 -m pytest --color=no ."):format(
      vim.fn.shellescape(root)
    )
    -- Парсинг ошибок в quickfix
    vim.opt_local.errorformat = table.concat({
      "%f:%l: %m",
      "%f:%l:%c: %m",
      "%-G%.%#",
    }, ",")
    -- Хоткей: <leader>m -> :make + quickfix
    vim.keymap.set("n", "<leader>m", function()
      vim.cmd("make")
      vim.cmd("copen")
    end, { buffer = true, desc = "Run pytest from project root" })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    local o = { buffer = true, silent = true }
    -- n/p — перейти к след./пред. валидной записи и вернуться в quickfix
    vim.keymap.set("n", "n", "<Cmd>cnext<CR><C-w>p", o)
    vim.keymap.set("n", "p", "<Cmd>cprev<CR><C-w>p", o)
  end,
})
