# Git Worktree Workflow Functions
# Usage: wt <cmd> [args]
# Commands: add, rm, list, switch, sync, prune, cleanup, init

# Get the bare repo root (where .git/worktrees lives)
_wt_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/HEAD" && -d "$dir/objects" && -d "$dir/refs" && ! -d "$dir/.git" ]]; then
            echo "$dir"
            return 0
        fi
        dir="${dir:h}"
    done
    return 1
}

# Check if we're in a bare repo or its worktree
_wt_check_bare() {
    local root=$(_wt_root)
    if [[ -z "$root" ]]; then
        echo "Error: Not in a bare git repository" >&2
        return 1
    fi
    return 0
}

# Check if branch is protected (main/master)
_wt_is_protected() {
    local branch="$1"
    [[ "$branch" == "main" || "$branch" == "master" ]]
}

# Create a new worktree
# Usage: wt-add <branch> [base]
wt-add() {
    _wt_check_bare || return 1

    local branch="$1"
    local base="${2:-main}"
    local root=$(_wt_root)

    if [[ -z "$branch" ]]; then
        echo "Usage: wt-add <branch> [base]" >&2
        return 1
    fi

    # Check if folder already exists
    if [[ -d "$root/$branch" ]]; then
        echo "Error: Directory '$branch' already exists" >&2
        echo "Use 'wt-switch $branch' to switch to it" >&2
        return 1
    fi

    # Check if branch is already checked out in another worktree
    local existing_worktree=$(git worktree list --porcelain 2>/dev/null | grep -A1 "^worktree" | grep -B1 "branches/$branch$" | head -1 | cut -d' ' -f2)
    if [[ -n "$existing_worktree" && -d "$existing_worktree" ]]; then
        echo "Error: Branch '$branch' is already checked out in: $existing_worktree" >&2
        echo "Use 'wt-switch $branch' to switch to it" >&2
        return 1
    fi

    # Check if branch exists locally or remotely
    local branch_exists=$(git branch --list "$branch" 2>/dev/null)
    local remote_branch=$(git branch -r --list "origin/$branch" 2>/dev/null)

    if [[ -n "$branch_exists" ]]; then
        # Branch exists locally - checkout existing
        git worktree add "$branch" "$branch"
    elif [[ -n "$remote_branch" ]]; then
        # Branch exists on remote - create tracking branch
        git worktree add "$branch" -b "$branch" "origin/$branch"
    else
        # New branch from base
        # Check if base exists
        local base_exists=$(git branch --list "$base" 2>/dev/null)
        local remote_base=$(git branch -r --list "origin/$base" 2>/dev/null)

        if [[ -z "$base_exists" && -z "$remote_base" ]]; then
            echo "Error: Base branch '$base' does not exist" >&2
            return 1
        fi

        local base_ref="$base"
        [[ -z "$base_exists" && -n "$remote_base" ]] && base_ref="origin/$base"

        git worktree add "$branch" -b "$branch" "$base_ref"
    fi

    if [[ $? -eq 0 ]]; then
        echo "Created worktree: $root/$branch"
        echo "Run 'wt-switch $branch' to switch to it"
    fi
}

# Remove a worktree
# Usage: wt-rm <branch> [-f]
wt-rm() {
    _wt_check_bare || return 1

    local branch="$1"
    local force="$2"
    local root=$(_wt_root)

    if [[ -z "$branch" ]]; then
        echo "Usage: wt-rm <branch> [-f]" >&2
        return 1
    fi

    # Check if worktree exists
    local worktree_path="$root/$branch"
    if [[ ! -d "$worktree_path" ]]; then
        echo "Error: Worktree '$branch' does not exist" >&2
        return 1
    fi

    # Check if branch is protected
    if _wt_is_protected "$branch"; then
        echo "Error: Cannot remove protected branch '$branch'" >&2
        return 1
    fi

    # Check for uncommitted changes unless -f
    if [[ "$force" != "-f" ]]; then
        local has_changes=$(cd "$worktree_path" && git status --porcelain 2>/dev/null)
        if [[ -n "$has_changes" ]]; then
            echo "Error: Worktree '$branch' has uncommitted changes" >&2
            echo "Use 'wt-rm $branch -f' to force removal" >&2
            return 1
        fi
    fi

    git worktree remove "$branch" ${force:+--force}

    # Optionally delete the branch if it's merged
    if [[ $? -eq 0 ]]; then
        echo "Removed worktree: $worktree_path"
        read "delete_branch?Delete branch '$branch'? (y/N): "
        if [[ "$delete_branch" =~ ^[Yy]$ ]]; then
            git branch -d "$branch" 2>/dev/null || git branch -D "$branch"
            echo "Deleted branch: $branch"
        fi
    fi
}

# List all worktrees with status
wt-list() {
    _wt_check_bare || return 1

    local root=$(_wt_root)

    echo "Worktrees in $root:"
    echo ""

    # Get non-bare worktrees using git worktree list
    git worktree list --porcelain 2>/dev/null | while IFS= read -r line; do
        # Look for worktree entries
        if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
            local wt_path="${match[1]}"
            local wt_name="${wt_path:t}"
            local wt_info=""

            # Read next lines until empty line or next worktree
            local is_bare=false
            local branch=""
            while IFS= read -r info_line && [[ -n "$info_line" ]]; do
                if [[ "$info_line" == "bare" ]]; then
                    is_bare=true
                elif [[ "$info_line" =~ ^branch\ refs/heads/(.+)$ ]]; then
                    branch="${match[1]}"
                fi
            done

            # Skip bare repo
            [[ "$is_bare" == true ]] && continue

            # Check if directory exists
            if [[ ! -d "$wt_path" ]]; then
                echo "  [MISSING]  $wt_name"
                continue
            fi

            # Get status
            local wt_status=""
            local changes=$(cd "$wt_path" 2>/dev/null && git status --porcelain 2>/dev/null | head -1)
            [[ -n "$changes" ]] && wt_status=" [DIRTY]"

            local ahead=$(cd "$wt_path" 2>/dev/null && git rev-list --count @{upstream}..HEAD 2>/dev/null)
            local behind=$(cd "$wt_path" 2>/dev/null && git rev-list --count HEAD..@{upstream} 2>/dev/null)

            local sync=""
            [[ -n "$ahead" && "$ahead" != "0" ]] && sync=" ↑$ahead"
            [[ -n "$behind" && "$behind" != "0" ]] && sync="$sync ↓$behind"

            printf "  %-20s %s%s%s\n" "$wt_name" "${branch:-detached}" "$wt_status" "$sync"
        fi
    done
}

# Switch to a worktree (cd into it)
# Usage: wt-switch <branch>
wt-switch() {
    local branch="$1"
    local root=$(_wt_root)

    if [[ -z "$branch" ]]; then
        echo "Usage: wt-switch <branch>" >&2
        return 1
    fi

    local worktree_path="$root/$branch"
    if [[ ! -d "$worktree_path" ]]; then
        echo "Error: Worktree '$branch' does not exist" >&2
        echo "Use 'wt-add $branch' to create it" >&2
        return 1
    fi

    cd "$worktree_path"
    echo "Switched to: $worktree_path"
}

# Fetch all remotes and prune
wt-sync() {
    _wt_check_bare || return 1

    echo "Fetching all remotes..."
    git fetch --all --prune

    echo ""
    echo "Updating worktrees..."

    local root=$(_wt_root)
    for wt in "$root"/*(/N); do
        local wt_name="${wt:t}"
        [[ "$wt_name" == "objects" || "$wt_name" == "refs" || "$wt_name" == "hooks" || "$wt_name" == "info" ]] && continue

        if [[ -d "$wt/.git" || -f "$wt/HEAD" ]]; then
            echo "  Updating $wt_name..."
            (cd "$wt" && git pull --rebase 2>/dev/null || true)
        fi
    done
}

# Prune stale worktrees (deleted directories)
wt-prune() {
    _wt_check_bare || return 1

    echo "Pruning stale worktrees..."
    git worktree prune -v
}

# Interactive cleanup of merged branches
wt-cleanup() {
    _wt_check_bare || return 1

    local root=$(_wt_root)
    local main_branch="main"
    [[ -z "$(git branch --list main)" ]] && main_branch="master"

    echo "Looking for merged branches into $main_branch..."
    echo ""

    local merged=$(git branch --merged "$main_branch" | grep -v "^\*" | grep -v "^[[:space:]]*main$" | grep -v "^[[:space:]]*master$")

    if [[ -z "$merged" ]]; then
        echo "No merged branches to clean up"
        return 0
    fi

    echo "Merged branches:"
    echo "$merged"
    echo ""

    read "confirm?Remove these merged worktrees and branches? (y/N): "
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        return 0
    fi

    echo "$merged" | while IFS= read -r branch; do
        branch=$(echo "$branch" | xargs)  # trim whitespace
        [[ -z "$branch" ]] && continue

        local wt_path="$root/$branch"
        if [[ -d "$wt_path" ]]; then
            echo "Removing worktree: $branch"
            git worktree remove "$branch" --force 2>/dev/null || rm -rf "$wt_path"
        fi

        echo "Deleting branch: $branch"
        git branch -d "$branch" 2>/dev/null
    done

    echo ""
    echo "Cleanup complete"
}

# Initialize main worktree if it doesn't exist
wt-init() {
    _wt_check_bare || return 1

    local root=$(_wt_root)
    local main_branch="main"
    [[ -z "$(git branch --list main)" ]] && main_branch="master"

    if [[ -d "$root/$main_branch" ]]; then
        echo "Main worktree already exists: $root/$main_branch"
        return 0
    fi

    git worktree add "$main_branch" "$main_branch"
    echo "Created main worktree: $root/$main_branch"
}

# Main wt command dispatcher
wt() {
    local cmd="$1"
    shift 2>/dev/null

    case "$cmd" in
        add|a)     wt-add "$@" ;;
        rm|remove) wt-rm "$@" ;;
        list|ls|l) wt-list ;;
        switch|sw|s) wt-switch "$@" ;;
        sync)      wt-sync ;;
        prune)     wt-prune ;;
        cleanup)   wt-cleanup ;;
        init)      wt-init ;;
        *)
            echo "Git Worktree Workflow"
            echo ""
            echo "Usage: wt <command> [args]"
            echo ""
            echo "Commands:"
            echo "  add <branch> [base]  Create worktree (new or existing branch)"
            echo "  rm <branch> [-f]     Remove worktree"
            echo "  list                 List all worktrees with status"
            echo "  switch <branch>      Switch to worktree (cd)"
            echo "  sync                 Fetch all remotes and update worktrees"
            echo "  prune                Remove stale worktree references"
            echo "  cleanup              Remove merged branches interactively"
            echo "  init                 Create main worktree if missing"
            ;;
    esac
}

# Zsh completion
_wt_completion() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        '1:command:->command' \
        '*:args:->args'

    case $state in
        command)
            local commands=(
                'add:Create worktree'
                'rm:Remove worktree'
                'list:List worktrees'
                'switch:Switch to worktree'
                'sync:Fetch and update'
                'prune:Remove stale references'
                'cleanup:Remove merged branches'
                'init:Create main worktree'
            )
            _describe 'command' commands
            ;;
        args)
            local cmd="${line[1]}"
            local root=$(_wt_root)

            case $cmd in
                add)
                    if [[ $CURRENT -eq 2 ]]; then
                        # Suggest branches (local and remote)
                        local -a branches
                        branches=(${(f)"$(git branch -a 2>/dev/null | sed 's/^[* ]*//' | sed 's|remotes/||' | grep -v HEAD | sort -u)"})
                        _describe 'branch' branches
                    elif [[ $CURRENT -eq 3 ]]; then
                        # Suggest base branches
                        local -a branches
                        branches=(${(f)"$(git branch 2>/dev/null | sed 's/^[* ]*//')"})
                        _describe 'base' branches
                    fi
                    ;;
                rm|remove|switch|sw)
                    # Suggest existing worktrees
                    if [[ -n "$root" ]]; then
                        local -a worktrees
                        worktrees=(${(f)"$(git worktree list --porcelain 2>/dev/null | grep '^worktree' | cut -d' ' -f2 | xargs -I{} basename {})"})
                        _describe 'worktree' worktrees
                    fi
                    ;;
            esac
            ;;
    esac
}

# Register completion (deferred until compinit is loaded)
_wt_compinit_hook() {
    if typeset -f compdef > /dev/null 2>&1; then
        compdef _wt_completion wt
        compdef _wt_completion wt-add
        compdef _wt_completion wt-rm
        compdef _wt_completion wt-switch
    fi
}
# Try to register immediately if compinit already loaded
_wt_compinit_hook 2>/dev/null || true
