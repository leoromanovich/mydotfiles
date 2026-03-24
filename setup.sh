#!/usr/bin/env bash
# =====================================================================
#  mydotfiles setup — bootstrap-скрипт для нового сервера
#  Устанавливает: vim, tmux, bash, git настройки
#
#  Использование:
#    git clone https://github.com/leoromanovich/mydotfiles.git ~/mydotfiles
#    cd ~/mydotfiles && bash setup.sh
#
#  Или одной строкой:
#    bash <(curl -sL https://raw.githubusercontent.com/leoromanovich/mydotfiles/main/setup.sh)
# =====================================================================
set -euo pipefail

# --- Цвета для вывода ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

# --- Определение директории dotfiles ---
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Если скрипт запущен через curl, сначала клонируем репо
if [ ! -f "$DOTFILES_DIR/vim/.vimrc" ]; then
  DOTFILES_DIR="$HOME/mydotfiles"
  if [ -d "$DOTFILES_DIR" ]; then
    info "Обновляем $DOTFILES_DIR..."
    git -C "$DOTFILES_DIR" pull --ff-only || true
  else
    info "Клонируем mydotfiles..."
    git clone https://github.com/leoromanovich/mydotfiles.git "$DOTFILES_DIR"
  fi
fi

info "Dotfiles: $DOTFILES_DIR"
echo ""

# --- Вспомогательные функции ---
backup_and_link() {
  local src="$1"
  local dst="$2"

  if [ ! -e "$src" ]; then
    warn "Исходный файл не найден: $src — пропускаю"
    return
  fi

  # Создать родительскую директорию если нет
  mkdir -p "$(dirname "$dst")"

  # Если уже правильный симлинк — ничего не делаем
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    ok "$dst -> $src (уже установлен)"
    return
  fi

  # Бэкап существующего файла
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    local backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
    warn "Бэкап: $dst -> $backup"
    mv "$dst" "$backup"
  fi

  ln -sf "$src" "$dst"
  ok "$dst -> $src"
}

# =====================================================================
#  1. Установка зависимостей
# =====================================================================
echo -e "\n${BLUE}=== Проверка зависимостей ===${NC}\n"

install_packages() {
  local missing=()

  for cmd in vim tmux git curl; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  # Полезные, но не критичные
  local optional_missing=()
  for cmd in rg fzf node; do
    if ! command -v "$cmd" &>/dev/null; then
      optional_missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    info "Устанавливаю: ${missing[*]}..."
    if command -v apt-get &>/dev/null; then
      sudo apt-get update -qq
      sudo apt-get install -y -qq "${missing[@]}"
    elif command -v yum &>/dev/null; then
      sudo yum install -y "${missing[@]}"
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y "${missing[@]}"
    elif command -v pacman &>/dev/null; then
      sudo pacman -S --noconfirm "${missing[@]}"
    elif command -v brew &>/dev/null; then
      brew install "${missing[@]}"
    else
      err "Не могу определить пакетный менеджер. Установите вручную: ${missing[*]}"
      exit 1
    fi
  fi

  if [ ${#optional_missing[@]} -gt 0 ]; then
    warn "Рекомендуемые пакеты не установлены: ${optional_missing[*]}"
    echo "    rg (ripgrep) — быстрый grep для vim и bash"
    echo "    fzf          — fuzzy finder для vim и bash"
    echo "    node (nodejs) — нужен для CoC.nvim (LSP в vim)"

    read -rp "Установить рекомендуемые пакеты? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      local pkgs=()
      for cmd in "${optional_missing[@]}"; do
        case "$cmd" in
          rg)   pkgs+=("ripgrep") ;;
          fzf)  pkgs+=("fzf") ;;
          node) pkgs+=("nodejs" "npm") ;;
        esac
      done

      if command -v apt-get &>/dev/null; then
        sudo apt-get install -y -qq "${pkgs[@]}" 2>/dev/null || warn "Некоторые пакеты не удалось установить"
      elif command -v brew &>/dev/null; then
        # На macOS пакеты называются иначе
        for cmd in "${optional_missing[@]}"; do
          case "$cmd" in
            rg)   brew install ripgrep ;;
            fzf)  brew install fzf ;;
            node) brew install node ;;
          esac
        done
      elif command -v dnf &>/dev/null; then
        sudo dnf install -y "${pkgs[@]}" 2>/dev/null || warn "Некоторые пакеты не удалось установить"
      elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm "${pkgs[@]}" 2>/dev/null || warn "Некоторые пакеты не удалось установить"
      fi
    fi
  fi

  ok "Зависимости проверены"
}

install_packages

# =====================================================================
#  2. Vim
# =====================================================================
echo -e "\n${BLUE}=== Настройка Vim ===${NC}\n"

# .vimrc
backup_and_link "$DOTFILES_DIR/vim/.vimrc" "$HOME/.vimrc"

# common.vim (пикеры без плагинов)
mkdir -p "$HOME/.vim"
backup_and_link "$DOTFILES_DIR/nvim/common.vim" "$HOME/.vim/common.vim"

# coc-settings.json
backup_and_link "$DOTFILES_DIR/vim/coc-settings.json" "$HOME/.vim/coc-settings.json"

# Установка vim-plug
if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
  info "Устанавливаю vim-plug..."
  curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  ok "vim-plug установлен"
else
  ok "vim-plug уже установлен"
fi

# undodir
mkdir -p "$HOME/.vim/undodir"

# Установка плагинов
info "Устанавливаю vim-плагины (может занять время)..."
vim -E -s +'PlugInstall --sync' +qall 2>&1 | while IFS= read -r line; do
  # Показываем строки с прогрессом установки плагинов
  case "$line" in
    *Installing*|*Updated*|*Already*|*Error*|*Resolving*|*error*|*npm*)
      echo "  $line" ;;
  esac
done
# Проверяем, что plugged-директория не пустая
if [ -d "$HOME/.vim/plugged" ] && [ "$(ls -A "$HOME/.vim/plugged" 2>/dev/null)" ]; then
  ok "vim-плагины установлены ($(ls "$HOME/.vim/plugged" | wc -l | tr -d ' ') шт.)"
else
  warn "Не удалось установить vim-плагины автоматически. Запустите vim и выполните :PlugInstall"
fi

# Установка CoC extensions
if command -v node &>/dev/null; then
  info "Устанавливаю CoC extensions..."
  vim -E -s +'CocInstall -sync coc-pyright coc-clangd coc-snippets' +qall 2>&1 | while IFS= read -r line; do
    case "$line" in
      *Installing*|*installed*|*Updated*|*Error*|*error*)
        echo "  $line" ;;
    esac
  done || warn "Не удалось установить CoC extensions. Запустите vim и выполните :CocInstall coc-pyright coc-clangd coc-snippets"
else
  warn "Node.js не установлен — CoC extensions пропущены"
fi

# =====================================================================
#  3. Tmux
# =====================================================================
echo -e "\n${BLUE}=== Настройка Tmux ===${NC}\n"

# tmux.conf
backup_and_link "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

# Установка TPM (Tmux Plugin Manager)
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
  info "Устанавливаю TPM (Tmux Plugin Manager)..."
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
  ok "TPM установлен"
else
  ok "TPM уже установлен"
fi

# Установка tmux-плагинов
info "Устанавливаю tmux-плагины..."
"$TPM_DIR/bin/install_plugins" 2>/dev/null || warn "Не удалось установить tmux-плагины. В tmux нажмите prefix + I"

# =====================================================================
#  4. Bash
# =====================================================================
echo -e "\n${BLUE}=== Настройка Bash ===${NC}\n"

BASHRC="$HOME/.bashrc"
SOURCE_LINE="# mydotfiles extras"
SOURCE_CMD="[ -f \"$DOTFILES_DIR/bash/.bashrc_extras\" ] && source \"$DOTFILES_DIR/bash/.bashrc_extras\""

if [ -f "$BASHRC" ] && grep -qF "mydotfiles extras" "$BASHRC"; then
  ok ".bashrc уже содержит source mydotfiles"
else
  info "Добавляю source в .bashrc..."
  {
    echo ""
    echo "$SOURCE_LINE"
    echo "$SOURCE_CMD"
  } >> "$BASHRC"
  ok "Добавлено в $BASHRC"
fi

# =====================================================================
#  5. Git
# =====================================================================
echo -e "\n${BLUE}=== Настройка Git ===${NC}\n"

read -rp "Применить git-алиасы и настройки? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  # Меняем editor на vim для серверов (в оригинале nvim)
  git config --global rerere.enabled true
  git config --global alias.co checkout
  git config --global alias.ci commit
  git config --global alias.st 'status -u'
  git config --global alias.br branch
  git config --global alias.unstage 'reset HEAD --'
  git config --global alias.last 'log -1 HEAD'
  git config --global alias.lgraph 'log --pretty=format:"%h %an | %s" --graph'
  git config --global core.editor vim

  # gitignore
  git config --global core.excludesfile "$HOME/.gitignore_global"
  cp "$DOTFILES_DIR/mygitignore" "$HOME/.gitignore_global"

  ok "Git настроен"
else
  info "Git настройки пропущены"
fi

# =====================================================================
#  Итог
# =====================================================================
echo ""
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}  Установка завершена!${NC}"
echo -e "${GREEN}==============================================${NC}"
echo ""
echo "  Что установлено:"
echo "    - Vim:  ~/.vimrc, ~/.vim/common.vim, ~/.vim/coc-settings.json"
echo "    - Tmux: ~/.tmux.conf + TPM"
echo "    - Bash: ~/.bashrc (source extras)"
echo ""
echo "  Следующие шаги:"
echo "    1. source ~/.bashrc          — применить bash-настройки"
echo "    2. tmux                      — запустить tmux"
echo "    3. vim → :PlugStatus         — проверить плагины"
echo "    4. vim → :CocInfo            — проверить LSP"
echo ""
