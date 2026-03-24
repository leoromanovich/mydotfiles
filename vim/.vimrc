" =====================================================================
"  Vim config — лёгкий конфиг для серверов
"  Работает на Vim 7.4+, без внешних зависимостей
"  Для полноценной разработки (LSP, дебаг) — используй Neovim
" =====================================================================

" --- Leader ---
let mapleader = ' '
let maplocalleader = ' '

" =====================================================================
"  vim-plug (опционально, если есть curl)
" =====================================================================
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  if executable('curl')
    silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs
      \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
  endif
endif

if !empty(glob(data_dir . '/autoload/plug.vim'))

call plug#begin('~/.vim/plugged')

" --- Fuzzy finder (если fzf установлен) ---
if executable('fzf')
  Plug 'junegunn/fzf', { 'do': './install --bin' }
  Plug 'junegunn/fzf.vim'
endif

Plug 'tpope/vim-vinegar'       " улучшенный netrw
Plug 'tpope/vim-commentary'    " gcc для комментирования
Plug 'tpope/vim-surround'      " cs'" для замены кавычек
Plug 'tpope/vim-repeat'        " . для плагинов

call plug#end()

endif " vim-plug installed

" =====================================================================
"  Опции
" =====================================================================
set nocompatible
set mouse=a
set number
set nobackup
set nowritebackup
set noswapfile
set encoding=utf-8
set fileencoding=utf-8
set hlsearch
set incsearch
set ignorecase
set smartcase
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
set numberwidth=4
set nowrap
set scrolloff=8
set sidescrolloff=8
set hidden
set backspace=indent,eol,start
set wildmenu
set wildmode=longest:full,full

" termguicolors только если терминал поддерживает
if has('termguicolors') && $TERM !~# '^\(linux\|screen\)$'
  set termguicolors
endif

" signcolumn если поддерживается
if exists('+signcolumn')
  set signcolumn=yes
endif

" --- Folding ---
set foldlevel=99
set foldlevelstart=99
set foldenable
set foldmethod=indent

" --- Colorscheme ---
colorscheme industry

" =====================================================================
"  Keymaps
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
"  Autocmds
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
  autocmd FileType qf nnoremap <buffer> <silent> n :cnext<CR><C-w>p
  autocmd FileType qf nnoremap <buffer> <silent> p :cprev<CR><C-w>p
augroup END

" --- Запоминание fold-ов ---
augroup remember_folds
  autocmd!
  autocmd BufWinLeave * if &buftype ==# '' | silent! mkview | endif
  autocmd BufWinEnter * if &buftype ==# '' | silent! loadview | endif
augroup END

" =====================================================================
"  common.vim (пикеры без плагинов)
" =====================================================================
if filereadable(expand('~/.vim/common.vim'))
  source ~/.vim/common.vim
endif

" =====================================================================
"  fzf.vim (если установлен)
" =====================================================================
if executable('fzf')
  let g:fzf_layout = { 'down': '~40%' }
  nnoremap <silent> <leader>ff :Files<CR>
  nnoremap <silent> <leader>fg :Rg<CR>
  nnoremap <silent> <leader>fb :Buffers<CR>
  nnoremap <silent> <leader>fh :Helptags<CR>
  nnoremap <silent> <leader>fr :History<CR>

  if executable('rg')
    command! -bang AllFiles call fzf#run(fzf#wrap({
      \ 'source': 'rg --files --hidden --no-ignore --glob "!.git/"',
      \ }, <bang>0))
    nnoremap <silent> <leader>fa :AllFiles<CR>
  endif
endif

" =====================================================================
"  netrw (file explorer)
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
