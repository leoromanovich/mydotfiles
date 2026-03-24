" =====================================================================
"  Vim config — аналог Neovim-конфига (nvim/)
"  Требует: Vim 8.2+, Node.js (для CoC), fzf, ripgrep
" =====================================================================

" --- Leader ---
let mapleader = ' '
let maplocalleader = ' '

" =====================================================================
"  vim-plug: менеджер плагинов (аналог lazy.nvim)
" =====================================================================
" Автоустановка vim-plug
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  echom '[dotfiles] Скачиваю vim-plug...'
  execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  echom '[dotfiles] vim-plug установлен. Устанавливаю плагины...'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

" --- LSP, Completion, Formatting, Linting (аналог lspconfig + mason + blink.cmp + conform + nvim-lint) ---
Plug 'neoclide/coc.nvim', {'branch': 'release', 'do': '!echo "[dotfiles] coc.nvim: npm install..." && npm install'}

" --- Fuzzy finder (аналог telescope.nvim) ---
Plug 'junegunn/fzf', { 'do': '!echo "[dotfiles] fzf: скачиваю бинарник..." && ./install --bin' }
Plug 'junegunn/fzf.vim'

" --- File explorer (аналог oil.nvim, улучшенный netrw) ---
Plug 'tpope/vim-vinegar'

" --- Commenting (аналог Comment.nvim) ---
Plug 'tpope/vim-commentary'

" --- Auto pairs (аналог nvim-autopairs) ---
Plug 'jiangmiao/auto-pairs'

" --- Snippets (через coc-snippets, аналог LuaSnip) ---
Plug 'honza/vim-snippets'

" --- Testing (аналог vim-test — тот же плагин) ---
Plug 'vim-test/vim-test'

" --- Debugger (аналог nvim-dap) ---
Plug 'puremourning/vimspector'

" --- Surround ---
Plug 'tpope/vim-surround'

" --- Repeat (поддержка . для плагинов) ---
Plug 'tpope/vim-repeat'

call plug#end()

" =====================================================================
"  Опции (аналог config/options.lua)
" =====================================================================
set nocompatible
set termguicolors
set mouse=a
set number
set nobackup
set nowritebackup
set noswapfile
set cmdheight=1
set completeopt=menuone,noselect
set conceallevel=0
set encoding=utf-8
set fileencoding=utf-8
set hlsearch
set ignorecase
set smartcase
set pumheight=10
set showmode
set showtabline=0
set smartindent
set splitbelow
set splitright
set timeoutlen=1000
set undofile
set undodir=~/.vim/undodir
set updatetime=300
set expandtab
set shiftwidth=4
set tabstop=4
set cursorline
set laststatus=2
set noshowcmd
set noruler
set numberwidth=4
set nowrap
set scrolloff=8
set sidescrolloff=8
set signcolumn=yes
set hidden
set shortmess+=c

" --- Folding ---
set foldcolumn=1
set foldlevel=99
set foldlevelstart=99
set foldenable
set foldmethod=indent
set viewoptions=folds,cursor

" --- Colorscheme ---
colorscheme industry

" =====================================================================
"  Keymaps (аналог config/keymaps.lua)
" =====================================================================

" Навигация между окнами
nnoremap <silent> <C-h> <C-w>h
nnoremap <silent> <C-j> <C-w>j
nnoremap <silent> <C-k> <C-w>k
nnoremap <silent> <C-l> <C-w>l

" Изменение размеров окон
nnoremap <silent> <leader><Up> :resize -4<CR>
nnoremap <silent> <leader><Down> :resize +4<CR>
nnoremap <silent> <leader><Left> :vertical resize +4<CR>
nnoremap <silent> <leader><Right> :vertical resize -4<CR>

" Переключение буферов
nnoremap <silent> <Tab> :bnext<CR>
nnoremap <silent> <S-Tab> :bprevious<CR>
nnoremap <leader>bb :ls<CR>:b

" Удалить строки с # DEBUG
command! -range=% RmDebugLines <line1>,<line2>g/\v#\s*DEBUG/d
nnoremap <silent> <leader>rmd :RmDebugLines<CR>
vnoremap <silent> <leader>rmd :RmDebugLines<CR>

" Выполнить выделение в bash
vnoremap <leader>xb :<C-U>'<,'>w !bash -eux -s<CR>

" =====================================================================
"  Autocmds (аналог config/autocmd.lua)
" =====================================================================

" --- pytest + :make из корня проекта ---
function! s:FindProjectRoot() abort
  let l:markers = ['pyproject.toml', 'pytest.ini', 'setup.cfg', 'tox.ini', '.git']
  let l:dir = expand('%:p:h')
  while l:dir !=# '/'
    for l:marker in l:markers
      if filereadable(l:dir . '/' . l:marker) || isdirectory(l:dir . '/' . l:marker)
        return l:dir
      endif
    endfor
    let l:dir = fnamemodify(l:dir, ':h')
  endwhile
  return getcwd()
endfunction

augroup pytest_make_root
  autocmd!
  autocmd BufEnter,BufWinEnter *.py,pytest.ini,pyproject.toml,setup.cfg,tox.ini
    \ let &l:makeprg = 'cd ' . shellescape(s:FindProjectRoot()) . ' && python3 -m pytest --color=no .'
    \ | setlocal errorformat=%f:%l:\ %m,%f:%l:%c:\ %m,%-G%.%#
    \ | nnoremap <buffer> <silent> <leader>m :make<CR>:copen<CR>
augroup END

" --- Quickfix: n/p для навигации ---
augroup quickfix_nav
  autocmd!
  autocmd FileType qf nnoremap <buffer> <silent> n <Cmd>cnext<CR><C-w>p
  autocmd FileType qf nnoremap <buffer> <silent> p <Cmd>cprev<CR><C-w>p
augroup END

" --- Запоминание fold-ов ---
augroup remember_folds
  autocmd!
  autocmd BufWinLeave * if &buftype ==# '' | silent! mkview | endif
  autocmd BufWinEnter * if &buftype ==# '' | silent! loadview | endif
augroup END

" =====================================================================
"  common.vim (пикеры без плагинов, quickfix)
" =====================================================================
if filereadable(expand('~/.vim/common.vim'))
  source ~/.vim/common.vim
endif

" =====================================================================
"  CoC.nvim (аналог lspconfig + mason + blink.cmp + conform + nvim-lint)
" =====================================================================

" Подсказка при наведении (аналог K в lspconfig)
nnoremap <silent> K :call CocActionAsync('doHover')<CR>

" LSP-навигация (аналог keymaps из lsp.lua)
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gD <Plug>(coc-declaration)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> go <Plug>(coc-type-definition)
nmap <silent> gr <Plug>(coc-references)
nmap <silent> gs :call CocActionAsync('showSignatureHelp')<CR>
nmap <silent> <F2> <Plug>(coc-rename)
nmap <silent> <F3> :call CocActionAsync('format')<CR>
nmap <silent> <F4> <Plug>(coc-codeaction-cursor)

" Диагностика (аналог <leader>d)
nmap <silent> <leader>d :CocDiagnostics<CR>
nmap <silent> [d <Plug>(coc-diagnostic-prev)
nmap <silent> ]d <Plug>(coc-diagnostic-next)

" Форматирование (аналог <leader>rf)
nnoremap <silent> <leader>rf :call CocActionAsync('format')<CR>

" Tab/S-Tab для навигации в completion меню
inoremap <silent><expr> <Tab> coc#pum#visible() ? coc#pum#next(1) : "\<Tab>"
inoremap <silent><expr> <S-Tab> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" =====================================================================
"  fzf.vim (аналог telescope.nvim)
" =====================================================================
let g:fzf_layout = { 'down': '~40%' }

" Пикеры (аналог telescope keymaps)
nnoremap <silent> <leader>ff :Files<CR>
nnoremap <silent> <leader>fg :Rg<CR>
nnoremap <silent> <leader>fb :Buffers<CR>
nnoremap <silent> <leader>fh :Helptags<CR>
nnoremap <silent> <leader>fr :History<CR>

" Поиск всех файлов, включая .gitignore'd (аналог <leader>fa)
command! -bang AllFiles call fzf#run(fzf#wrap({
  \ 'source': 'rg --files --hidden --no-ignore --glob "!.git/"',
  \ }, <bang>0))
nnoremap <silent> <leader>fa :AllFiles<CR>

" =====================================================================
"  vim-test (аналог tests.lua)
" =====================================================================
let test#strategy = 'vimterminal'
let test#python#runner = 'pytest'

nnoremap <silent> <leader>tn :TestNearest<CR>
nnoremap <silent> <leader>tf :TestFile<CR>
nnoremap <silent> <leader>ts :TestSuite<CR>
nnoremap <silent> <leader>tv :TestVisit<CR>

" =====================================================================
"  Vimspector (аналог nvim-dap)
" =====================================================================
let g:vimspector_enable_mappings = 'HUMAN'

nmap <leader>b <Plug>VimspectorToggleBreakpoint
nmap <leader>B <Plug>VimspectorToggleConditionalBreakpoint
nmap <leader>dt <Plug>VimspectorStop
nmap <leader>dr <Plug>VimspectorRestart

" =====================================================================
"  Snippets (coc-snippets, аналог LuaSnip)
" =====================================================================
" Навигация по placeholder-ам сниппетов
let g:coc_snippet_next = '<C-j>'
let g:coc_snippet_prev = '<C-k>'

" =====================================================================
"  netrw (file explorer, аналог oil.nvim)
" =====================================================================
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_browse_split = 0
let g:netrw_winsize = 25
nnoremap <silent> - :Explore<CR>

" =====================================================================
"  CUDA filetype
" =====================================================================
augroup cuda_ft
  autocmd!
  autocmd BufRead,BufNewFile *.cu,*.cuh setfiletype cuda
augroup END

" Создать undodir если не существует
if !isdirectory(expand('~/.vim/undodir'))
  call mkdir(expand('~/.vim/undodir'), 'p')
endif
