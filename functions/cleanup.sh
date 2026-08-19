cleanup() {
  local branch
  branch=$(git branch --show-current 2>/dev/null)

  if [ -z "$branch" ]; then
    echo "Not on a git branch."
    return 1
  fi

  if [ "$branch" = "main" ]; then
    echo "Already on main, nothing to clean up."
    return 0
  fi

  local repo_root
  repo_root=$(git rev-parse --show-toplevel)

  # Detect if we're inside a worktree
  local git_common_dir
  git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
  local git_dir
  git_dir=$(git rev-parse --git-dir 2>/dev/null)

  local in_worktree=false
  local worktree_dir=""
  local db_name=""

  if [ "$git_common_dir" != "$git_dir" ]; then
    in_worktree=true
    worktree_dir="$repo_root"

    # Check if this worktree has an isolated database
    local db_yml="$repo_root/rails/config/database.yml"
    if [ -f "$db_yml" ]; then
      local dev_db
      dev_db=$(grep 'database: tern_wt_' "$db_yml" | head -1 | sed 's/.*database: //' | tr -d ' ')
      if [ -n "$dev_db" ]; then
        db_name="$dev_db"
      fi
    fi
  fi

  echo "Branch:    $branch"
  if [ "$in_worktree" = true ]; then
    echo "Worktree:  $worktree_dir"
  fi
  if [ -n "$db_name" ]; then
    echo "Database:  $db_name (+ ${db_name}_test)"
  fi
  echo ""
  echo "This will delete the branch locally and from origin, then switch to main."

  read "confirm?Proceed? [y/N]: "
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    return 1
  fi

  if [ "$in_worktree" = true ]; then
    # Leave the worktree before removing it
    local main_worktree
    main_worktree=$(git worktree list --porcelain | grep "^worktree " | head -1 | sed 's/^worktree //')

    echo "Switching to main worktree"
    cd "$main_worktree" || { echo "Failed to cd to main worktree at $main_worktree"; return 1; }

    echo "Removing worktree"
    git worktree remove "$worktree_dir" --force

    # Drop isolated databases if they exist
    if [ -n "$db_name" ]; then
      echo "Dropping database: $db_name"
      dropdb --if-exists "$db_name"
      dropdb --if-exists "${db_name}_test"
    fi
  fi

  echo "Switching to main and pulling latest"
  git switch main || git checkout main
  git pull origin main

  echo "Deleting local branch: $branch"
  git branch -D "$branch" 2>/dev/null

  echo "Deleting remote branch: $branch"
  git push origin --delete "$branch" 2>/dev/null

  if [ -n "$TERN_REPO_PATH" ]; then
    cd "$TERN_REPO_PATH/rails"
  fi

  echo ""
  echo "Cleaned up $branch"
}
