local ls = require("luasnip")
local s = ls.s
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local sn = ls.snippet_node
local rep = require("luasnip.extras").rep


ls.add_snippets("python", {
  -- npsv: сначала путь (директория), потом имя файла (без .npy), потом переменная
  s("npsv", {
    t("np.save('tmp_debug/"),
    i(1, "array"),        -- имя файла (без расширения)
    t(".npy', "),
    i(2, "arr"),          -- переменная
    t(") # DEBUG")
  }),
  s("npld", {
    i(1, "var_name"),        -- имя файла (без расширения)
    t(" = np.load('tmp_debug/"),
    i(2, "arr"),
    t(".npy') # DEBUG"),
  }),
  s("trsv", {
    t("np.save('tmp_debug/"),
    i(1, "array"),        -- имя файла (без расширения)
    t(".npy', "),
    i(2, "arr"),          -- переменная
    t(".detach().numpy() # DEBUG")
  }),
})
