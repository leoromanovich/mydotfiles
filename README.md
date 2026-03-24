# mydotfiles

Лёгкие конфиги для серверов и рабочих машин. Работает на старых системах (Vim 7.4+, Bash/Zsh), ничего не устанавливает — только раскидывает конфиги и предупреждает о недостающих утилитах.

## Установка

```bash
git clone https://github.com/leoromanovich/mydotfiles.git ~/mydotfiles
cd ~/mydotfiles && bash setup.sh
```

Или одной строкой:

```bash
bash <(curl -sL https://raw.githubusercontent.com/leoromanovich/mydotfiles/main/setup.sh)
```

### Что делает setup.sh

- Проверяет зависимости (не устанавливает, только предупреждает)
- Симлинкит конфиги: `~/.vimrc`, `~/.vim/common.vim`, `~/.tmux.conf`, `~/.bashrc`
- Применяет git-алиасы и настройки
- Ставит vim-plug и TPM (если есть curl/tmux)

### Критичные зависимости

`vim`, `git` — без них setup не запустится.

### Рекомендуемые (опционально)

| Утилита | Зачем |
|---------|-------|
| `curl` | Скачивание vim-plug |
| `tmux` | Терминальный мультиплексор |
| `fzf` | Fuzzy finder в vim и терминале |
| `rg` (ripgrep) | Быстрый grep в vim и терминале |

---

## Git

### Shell-алиасы

| Алиас | Команда | Использование |
|-------|---------|---------------|
| `gs` | `git status -u` | Что изменилось |
| `gl` | `git log --oneline -20` | Последние коммиты |
| `glg` | `git log --graph` | История с графом веток |
| `gd` | `git diff` | Незастейдженные изменения |
| `gds` | `git diff --staged` | Что уйдёт в коммит |
| `ga` | `git add` | `ga file.py` или `ga .` |
| `gc` | `git commit` | Откроет vim для сообщения |
| `gco` | `git checkout` | Переключить ветку |
| `gb` | `git branch` | Список веток |
| `gp` | `git push` | Запушить |
| `gpu` | `git pull` | Подтянуть |

### Git config алиасы

| Команда | Что делает |
|---------|-----------|
| `git co feature-x` | checkout |
| `git ci -m "msg"` | commit |
| `git st` | status -u |
| `git br` | branch |
| `git unstage file.py` | убрать файл из stage |
| `git last` | показать последний коммит |
| `git lgraph` | граф коммитов |

### rerere

Включён `rerere.enabled` — git запоминает как ты разрешал конфликты мержей. При повторном конфликте тех же строк разрешится автоматически.

### Git Worktree (`wt`)

Для параллельной работы с несколькими ветками через bare-репо. Подключается через `source git-worktree.sh`.

```bash
# Начальная настройка
git clone --bare git@github.com:user/repo.git myrepo/.git
cd myrepo
wt add main              # создать worktree для main

# Работа
wt add feat-auth main    # новая ветка от main → myrepo/feat-auth/
wt cd feat-auth          # перейти в worktree
wt cd main               # переключиться обратно
wt list                  # показать все worktree
wt rm feat-auth          # удалить worktree (спросит про удаление ветки)
```

Структура на диске:
```
myrepo/
  .git/         (bare repo)
  main/         (worktree)
  feat-auth/    (worktree)
```

---

## Vim

Лёгкий конфиг без LSP/автокомплита. Для полноценной разработки — Neovim.

**Leader = Space**

### Навигация

| Хоткей | Действие |
|--------|----------|
| `Ctrl+h/j/k/l` | Перемещение между split-ами |
| `Tab` / `Shift+Tab` | Следующий / предыдущий буфер |
| `Space bb` | Список буферов + выбор по номеру |
| `-` | Открыть файловый менеджер (netrw) |

### Окна

| Хоткей | Действие |
|--------|----------|
| `Space Up/Down` | Уменьшить/увеличить высоту |
| `Space Left/Right` | Увеличить/уменьшить ширину |

### Редактирование (плагины)

| Хоткей | Действие | Плагин |
|--------|----------|--------|
| `gcc` | Закомментировать строку | vim-commentary |
| `gc` (visual) | Закомментировать выделение | vim-commentary |
| `cs'"` | `'text'` → `"text"` | vim-surround |
| `ds"` | `"text"` → `text` | vim-surround |
| `ysiw]` | `word` → `[word]` | vim-surround |

### Поиск файлов и текста

Одни и те же хоткеи работают с fzf (если установлен) и без него (через встроенные команды vim):

| Хоткей | С fzf | Без fzf |
|--------|-------|---------|
| `Space ff` | `:Files` (fuzzy) | `:find` + Tab (wildmenu) |
| `Space fg` | `:Rg` (fuzzy grep) | `:grep` + quickfix |
| `Space fb` | `:Buffers` (fuzzy) | `:buffer` + Tab |
| `Space fr` | `:History` | `:browse oldfiles` |
| `Space fh` | `:Helptags` | `:helpgrep` + quickfix |
| `Space fa` | Все файлы (rg) | — |

Дополнительно (без плагинов, из common.vim):

| Хоткей | Действие |
|--------|----------|
| `Space fF` | Найти файл с именем как под курсором |
| `Space fG` | Grep слово под курсором |
| `Space ft` | Выбрать тег под курсором |

### Quickfix

| Хоткей | Действие |
|--------|----------|
| `Space qo` | Открыть quickfix |
| `Space qc` | Закрыть quickfix |
| `]q` / `[q` | Следующий / предыдущий результат |
| `n` / `p` (в quickfix окне) | Следующая / предыдущая ошибка |
| `Space qf` | Фильтр quickfix (regex, `f:` по файлу, `m:` по тексту, `!` инвертировать) |
| `Space qa` | Выполнить команду на всех результатах (`:cdo`) |

### Python / тесты

| Хоткей | Действие |
|--------|----------|
| `Space m` | Запустить pytest через `:make` (в .py файлах) |

### Утилиты

| Хоткей | Действие |
|--------|----------|
| `Space rmd` | Удалить все строки с `# DEBUG` |
| `Space xb` (visual) | Выполнить выделенный текст в bash |

---

## Tmux

Плагин: только `vim-tmux-navigator` (единая навигация Ctrl+h/j/k/l между vim и tmux).

| Хоткей | Действие |
|--------|----------|
| `Ctrl+h/j/k/l` | Навигация между панелями (и vim split-ами) |
| `Alt+Arrow` | Навигация между панелями |
| `Shift+Arrow` | Изменение размеров панелей |
| `Ctrl+Left/Right` | Предыдущее/следующее окно |
| `Alt+H/L` | Предыдущее/следующее окно |
| `prefix "` | Горизонтальный split (сохраняет pwd) |
| `prefix %` | Вертикальный split (сохраняет pwd) |

### Копирование (vi-mode)

| Хоткей | Действие |
|--------|----------|
| `prefix [` | Войти в copy mode |
| `v` | Начать выделение |
| `Ctrl+v` | Прямоугольное выделение |
| `y` | Скопировать в системный буфер (pbcopy/xclip) |
