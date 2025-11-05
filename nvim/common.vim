" =====================================================================
"  Common Vim/Neovim config: "бедный Telescope" без плагинов
"  Совместим с Vim 8+ и Neovim (init.vim). Все отличия — под has('nvim').
" =====================================================================

" --- UI / completion ---
set nocompatible                 " вкл. «современное» поведение Vim
set wildmenu                     " меню завершения командной строки
set wildmode=list:longest,full   " сначала список + самое длинное, потом полное
set path+=**


" --- Игнор тяжёлых директорий и мусора ---
" set wildignore+=*/.git/*,*/.hg/*,*/.svn/*,*/node_modules/*,*/dist/*,*/build/*,*/out/*,*/target/*
" set wildignore+=*/.venv/*,*/venv/*,*/.mypy_cache/*,*/__pycache__/*,*/.pytest_cache/*
" set wildignore+=*.o,*.obj,*.class,*.pyc,*.pyo,*.swp,*.swo,*.cache


" --- Поиск по файлам/тексту ---
set ignorecase                   " нечувствительность к регистру...
set smartcase                    " ...кроме когда есть заглавные буквы в запросе
set grepformat=%f:%l:%c:%m       " формат вывода для quickfix от grep/vimgrep

" Если установлен ripgrep, используем его для :grep; иначе останется :vimgrep
if executable('rg')
  " --vimgrep   формат как у vimgrep (файл:строка:колонка:сообщение)
  " --hidden    ищем и в скрытых файлах (уважает .gitignore без -u)
  " --smart-case регистр-умный поиск
  set grepprg=rg\ --vimgrep\ --hidden\ --smart-case
endif

" --- Quickfix / Location list удобства ---
nnoremap <silent> <leader>qo :copen<CR>     " открыть quickfix
nnoremap <silent> <leader>qc :cclose<CR>    " закрыть quickfix
nnoremap <silent> ]q :cnext<CR>             " след. результат
nnoremap <silent> [q :cprev<CR>             " пред. результат

" Фильтрация quickfix по паттерну:
" 1) Если есть встроенная/плагиновая :Cfilter — используем её
if exists(':Cfilter')
  nnoremap <leader>qf :Cfilter 
else
    function! s:QfFilter() abort
  call inputsave()
  let pat = input('qf filter (regex or glob; f:/m:; !invert): ')
  call inputrestore()
  if empty(pat) | echo 'Filter cancelled' | return | endif

  " Инверсия
  let invert = pat[0] ==# '!'
  if invert | let pat = pat[1:] | endif

  " Режим поля
  let mode = ''
  if pat =~# '^f:' | let mode = 'file' | let pat = pat[2:] |
  elseif pat =~# '^m:' | let mode = 'msg'  | let pat = pat[2:] | endif

  " Глоб → регекс (если есть * ? [])
  let rx = pat =~# '[\*\?\[\]]' ? glob2regpat(pat) : pat

  let items = getqflist()
  let filtered = []
  for it in items
    let fname = ''
    if has_key(it, 'bufnr') && it.bufnr > 0
      let fname = fnamemodify(bufname(it.bufnr), ':t')
    elseif has_key(it, 'filename')
      let fname = fnamemodify(it.filename, ':t')
    endif

    let msg = get(it,'text','')

    if mode ==# 'file'
      let target = fname
    elseif mode ==# 'msg'
      let target = msg
    else
      let target = msg . ' ' . fname . ' ' . string(get(it,'lnum',''))
    endif

    let ok = target =~ rx
    if invert ? (!ok) : ok
      call add(filtered, it)
    endif
  endfor

  call setqflist([], 'r', {
        \ 'items': filtered,
        \ 'title': 'QF filtered: ' . (invert ? '!' : '') . (empty(mode)? '' : mode[0].':') . pat
        \ })
  copen
endfunction
  nnoremap <silent> <leader>qf :call <SID>QfFilter()<CR>
endif

" --- «Пикеры» на штатных командах ---

" 1) Files: аналог find_files → :find + <Tab> completion
nnoremap <leader>ff :find 
" Найти файл с именем, как под курсором (basename)
nnoremap <silent> <leader>fF :execute 'find ' . expand('<cfile>:t')<CR>

" 2) Live grep: аналог live_grep → :grep → quickfix
" Введёте запрос сами
nnoremap <leader>fg :grep 
" Поиск слова под курсором
nnoremap <silent> <leader>fG :silent grep! <C-R><C-W> \| copen<CR>

" 3) Buffers: аналог buffers → :buffer + completion
nnoremap <leader>fb :buffer 

" 4) Recent files (MRU): аналог oldfiles
nnoremap <silent> <leader>fr :browse oldfiles<CR>

" 5) Help / Tags: аналог help_tags / tags
" Поиск по справке → quickfix
" --- Helpgrep picker (устойчиво к scope) ---
function! s:HelpGrep() abort
  call inputsave()
  let q = input('helpgrep: ')
  call inputrestore()
  if empty(q)
    echo 'helpgrep: cancelled'
    return
  endif
  " Используем :execute, экранируем проблемные символы
  execute 'silent helpgrep ' . escape(q, '|')
  copen
endfunction
nnoremap <silent> <leader>fh :call <SID>HelpGrep()<CR>

" Выбор тега под курсором из нескольких совпадений
nnoremap <silent> <leader>ft :tselect <C-R><C-W><CR>

" --- Preview window как «предпросмотр» ---
set previewheight=15
" Открыть определение тега в preview-окне
nnoremap <silent> <leader>pp :ptag <C-R><C-W><CR>
nnoremap <silent> ]p :ptnext<CR>
nnoremap <silent> [p :ptprevious<CR>

" --- Массовые правки через quickfix ---
" После :grep — можно выполнить одну команду для всех попаданий:
" Пример: :cdo s/old/new/ge | update
nnoremap <leader>qa :cdo 

" =====================================================================
"      Раздел Neovim-only (мягкие улучшения, безопасные для Vim)
" =====================================================================
if has('nvim')
  " В Neovim есть :terminal получше, полезно для rg/ctags вручную
  nnoremap <silent> <leader>sh :terminal<CR>
endif

" =====================================================================
"        Кросс-платформенные мелочи / рекомендации
" =====================================================================
" - Ctags: сгенерируйте индексы: `ctags -R .` (Universal Ctags предпочтительнее).
" - Быстрый обзор буферов: :ls (или :buffers), переключение — :buffer <nr>
" - Для проектов с Git: можно добавить path+=.git/** если хочется искать внутри .git
" - Если quickfix «шумный», используйте фильтры (см. <leader>qf) или уточняйте :grep
