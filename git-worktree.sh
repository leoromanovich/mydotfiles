# Git Worktree Workflow for bare repos
# Usage: wt <cmd> [args]
#
# Setup: git clone --bare <url> myrepo/.git && cd myrepo && wt add main
# Structure: myrepo/
#              .git/    (bare repo)
#              main/    (worktree)
#              feat-x/  (worktree)

# Returns the directory containing .git (i.e. where worktrees live)
_wt_root() {
    local gitdir
    gitdir=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
    # Resolve to absolute path
    gitdir=$(cd "$gitdir" && pwd)
    if [[ "$(git -C "$gitdir" rev-parse --is-bare-repository 2>/dev/null)" != "true" ]]; then
        echo "Not in a bare git repository" >&2
        return 1
    fi
    # Worktrees live next to .git/, so return parent
    echo "${gitdir:h}"
}

# wt add <branch> [base] — create new branch worktree (like git switch -c)
# wt add <branch>         — checkout existing local/remote branch
wt-add() {
    local root branch="$1" base="${2:-main}"
    root=$(_wt_root) || return 1

    if [[ -z "$branch" ]]; then
        echo "Usage: wt add <branch> [base]" >&2
        return 1
    fi

    git -C "$root" fetch origin --quiet 2>/dev/null

    if git -C "$root" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
        # Local branch exists — just check it out
        git -C "$root" worktree add "$root/$branch" "$branch"
    elif git -C "$root" show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
        # Remote branch exists — create local tracking branch
        git -C "$root" worktree add --track -b "$branch" "$root/$branch" "origin/$branch"
    else
        # New branch from base
        git -C "$root" worktree add -b "$branch" "$root/$branch" "$base"
    fi
}

# wt rm <branch> [-f] — remove worktree and optionally delete branch
wt-rm() {
    local root branch="$1" force=""
    root=$(_wt_root) || return 1

    if [[ -z "$branch" ]]; then
        echo "Usage: wt rm <branch> [-f]" >&2
        return 1
    fi

    [[ "$2" == "-f" ]] && force="--force"

    if [[ ! -d "$root/$branch" ]]; then
        echo "Worktree '$branch' does not exist" >&2
        return 1
    fi

    git -C "$root" worktree remove "$root/$branch" $force || return 1

    echo "Removed worktree: $branch"
    read "yn?Delete branch '$branch' too? (y/N): "
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        git -C "$root" branch -D "$branch" 2>/dev/null
        echo "Deleted branch: $branch"
    fi
}

# wt list — show all worktrees
wt-list() {
    local root
    root=$(_wt_root) || return 1
    git -C "$root" worktree list
}

# wt cd <branch> — cd into worktree
wt-cd() {
    local root branch="$1"
    root=$(_wt_root) || return 1

    if [[ -z "$branch" ]]; then
        echo "Usage: wt cd <branch>" >&2
        return 1
    fi

    if [[ ! -d "$root/$branch" ]]; then
        echo "Worktree '$branch' does not exist" >&2
        return 1
    fi

    cd "$root/$branch"
}

# Main dispatcher
wt() {
    local cmd="$1"
    shift 2>/dev/null

    case "$cmd" in
        add|a)      wt-add "$@" ;;
        rm|remove)  wt-rm "$@" ;;
        list|ls|l)  wt-list ;;
        cd|sw)      wt-cd "$@" ;;
        *)
            echo "Usage: wt <command> [args]"
            echo ""
            echo "  add <branch> [base]  Create worktree (new branch from base, or checkout existing)"
            echo "  rm <branch> [-f]     Remove worktree (optionally delete branch)"
            echo "  list                 List all worktrees"
            echo "  cd <branch>          cd into worktree"
            ;;
    esac
}

# Zsh completion
if typeset -f compdef > /dev/null 2>&1; then
    _wt_completion() {
        local -a commands=(
            'add:Create worktree'
            'rm:Remove worktree'
            'list:List worktrees'
            'cd:cd into worktree'
        )
        local root=$(_wt_root 2>/dev/null)

        _arguments -C '1:command:->command' '*:args:->args'

        case $state in
            command) _describe 'command' commands ;;
            args)
                case "${line[1]}" in
                    add)
                        local -a branches
                        branches=(${(f)"$(git -C "$root" branch -a 2>/dev/null | sed 's/^[* ]*//' | sed 's|remotes/origin/||' | grep -v HEAD | sort -u)"})
                        _describe 'branch' branches
                        ;;
                    rm|remove|cd|sw)
                        local -a worktrees
                        worktrees=(${(f)"$(git -C "$root" worktree list --porcelain 2>/dev/null | grep '^worktree ' | sed "s|^worktree $root/||" | grep -v "^$root$")"})
                        _describe 'worktree' worktrees
                        ;;
                esac
                ;;
        esac
    }
    compdef _wt_completion wt
fi
