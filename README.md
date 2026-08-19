# Tern Shell Functions

Shell functions for the Tern development workflow. Handles branch creation, git worktrees, isolated databases, and cleanup.

## Install

```bash
git clone git@github.com:tern-travel/shell-functions.git ~/tern-shell-functions
cd ~/tern-shell-functions
bash install.sh
source ~/.zshrc
```

The install script symlinks the functions into `~/.shell-functions/` and adds a loader to your `.zshrc`. If you already have files there, it won't overwrite them.

### Prerequisites

- macOS (uses `pbpaste` for clipboard, `sed -i ''` for in-place edits)
- zsh
- git
- PostgreSQL CLI tools (`dropdb`) — only needed for `--isolated` mode

### Environment

Add to your `.zshrc` if not already set:

```bash
export TERN_REPO_PATH="$HOME/tern"
```

## Commands

### `checkout`

Create a new branch from main. Three modes:

```bash
# Standard — switches main checkout to new branch
checkout tyler/eng2a-1234-my-feature

# Worktree — creates a git worktree, shares your dev database
checkout tyler/eng2a-1234-my-feature --wt

# Isolated — creates a worktree with its own database (schema + seeds)
checkout tyler/eng2a-1234-my-feature --isolated
```

If no branch name is given, reads from the clipboard (handy for copying branch names from Linear).

All modes push the branch to origin automatically.

### `cleanup`

Tears down the current branch and everything associated with it:

```bash
cleanup
```

What it does:
- Detects if you're in a worktree and removes it
- Drops isolated databases if the worktree had them
- Deletes the branch locally and from origin
- Switches back to main and pulls latest

Works from any context — main checkout, shared worktree, or isolated worktree. Always confirms before acting.

## How it works

`checkout --wt` and `--isolated` create worktrees under `<repo>/.worktrees/<branch>/`. The isolated mode additionally:
1. Rewrites `database.yml` to use a dedicated database (`tern_wt_<branch>`)
2. Marks that change as `skip-worktree` so git ignores it
3. Runs `db:create`, `db:schema:load`, and `db:seed`

`cleanup` reverses all of this — it detects the worktree type from the database.yml contents and cleans up accordingly.

## Updating

Pull the latest and the symlinks pick up changes automatically:

```bash
cd ~/tern-shell-functions && git pull
```
