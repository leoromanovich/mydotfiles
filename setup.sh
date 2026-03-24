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
#  1. Проверка зависимостей (ничего не устанавливаем)
# =====================================================================
echo -e "\n${BLUE}=== Проверка зависимостей ===${NC}\n"

HAS_MISSING=false

# Критичные: без них setup не имеет смысла
for cmd in vim git; do
  if command -v "$cmd" &>/dev/null; then
    ok "$cmd найден"
  else
    err "$cmd не найден — установите вручную"
    HAS_MISSING=true
  fi
done

# Рекомендуемые: без них всё работает, но с ограничениями
_opt_desc() {
  case "$1" in
    curl) echo "скачивание vim-plug" ;;
    tmux) echo "терминальный мультиплексор" ;;
    rg)   echo "быстрый grep (ripgrep) для vim и bash" ;;
    fzf)  echo "fuzzy finder для vim и bash" ;;
  esac
}

OPTIONAL_MISSING=()
for cmd in curl tmux rg fzf; do
  if command -v "$cmd" &>/dev/null; then
    ok "$cmd найден"
  else
    warn "$cmd не найден — $(_opt_desc "$cmd")"
    OPTIONAL_MISSING+=("$cmd")
  fi
done

if [ "$HAS_MISSING" = true ]; then
  err "Не найдены критичные зависимости. Установите их и повторите setup."
  exit 1
fi

echo ""
if [ ${#OPTIONAL_MISSING[@]} -gt 0 ]; then
  info "Рекомендуется установить: ${OPTIONAL_MISSING[*]}"
  info "Конфиги будут настроены, но часть функций будет недоступна."
fi

# =====================================================================
#  2. Vim
# =====================================================================
echo -e "\n${BLUE}=== Настройка Vim ===${NC}\n"

# .vimrc
backup_and_link "$DOTFILES_DIR/vim/.vimrc" "$HOME/.vimrc"

# common.vim (пикеры без плагинов)
mkdir -p "$HOME/.vim"
backup_and_link "$DOTFILES_DIR/nvim/common.vim" "$HOME/.vim/common.vim"

# undodir
mkdir -p "$HOME/.vim/undodir"

# Установка vim-plug (нужен curl)
if command -v curl &>/dev/null; then
  if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
    info "Устанавливаю vim-plug..."
    curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    ok "vim-plug установлен"
  else
    ok "vim-plug уже установлен"
  fi
  info "Для установки плагинов запустите vim и выполните :PlugInstall"
else
  warn "curl не найден — vim-plug не установлен. Плагины будут недоступны."
fi

# =====================================================================
#  3. Tmux
# =====================================================================
echo -e "\n${BLUE}=== Настройка Tmux ===${NC}\n"

if command -v tmux &>/dev/null; then
  backup_and_link "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

  # Установка TPM (Tmux Plugin Manager)
  TPM_DIR="$HOME/.tmux/plugins/tpm"
  if [ ! -d "$TPM_DIR" ]; then
    info "Устанавливаю TPM (Tmux Plugin Manager)..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    ok "TPM установлен. Для установки плагинов в tmux нажмите prefix + I"
  else
    ok "TPM уже установлен"
  fi
else
  warn "tmux не найден — пропускаю настройку tmux"
fi

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

# =====================================================================
#  Итог
# =====================================================================
echo ""
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}  Установка завершена!${NC}"
echo -e "${GREEN}==============================================${NC}"
echo ""
echo "  Что настроено:"
echo "    - Vim:  ~/.vimrc, ~/.vim/common.vim"
if command -v tmux &>/dev/null; then
echo "    - Tmux: ~/.tmux.conf + TPM"
fi
echo "    - Bash: ~/.bashrc (source extras)"
echo "    - Git:  алиасы, rerere, gitignore"
echo ""
echo "  Следующие шаги:"
echo "    1. source ~/.bashrc          — применить bash-настройки"
echo "    2. vim → :PlugInstall        — установить плагины"
if command -v tmux &>/dev/null; then
echo "    3. tmux → prefix + I         — установить tmux-плагины"
fi

if [ ${#OPTIONAL_MISSING[@]} -gt 0 ]; then
  echo ""
  warn "Не установлены: ${OPTIONAL_MISSING[*]}"
  echo "    Рекомендуется доустановить для полной функциональности."
fi
echo ""
