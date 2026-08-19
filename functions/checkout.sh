checkout() {
  branch=""
  isolated=false
  worktree=false

  for arg in "$@"; do
    case $arg in
      --isolated)
        isolated=true
        ;;
      --wt)
        worktree=true
        ;;
      --*)
        echo "Unknown flag: $arg"
        echo "Usage: checkout [branch-name] [--isolated] [--wt]"
        return 1
        ;;
      *)
        if [ -z "$branch" ]; then
          branch="$arg"
        fi
        ;;
    esac
  done

  # Use clipboard if no branch provided (macOS)
  if [ -z "$branch" ]; then
    branch=$(pbpaste 2>/dev/null)
    if [ -z "$branch" ]; then
      echo "No branch name provided and clipboard is empty."
      echo "Usage: checkout <branch-name> [--isolated] [--wt]"
      return 1
    fi
  fi

  echo "Branch to create: $branch"
  if [ "$isolated" = true ]; then
    echo "Mode: isolated worktree with separate database"
  elif [ "$worktree" = true ]; then
    echo "Mode: worktree (shared database)"
  fi

  read "confirm?Proceed with this branch? [y/N]: "

  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    return 1
  fi

  if [ "$isolated" = true ]; then
    _checkout_isolated "$branch"
  elif [ "$worktree" = true ]; then
    _checkout_worktree "$branch"
  else
    echo "Switching to main and pulling latest"
    git switch main || git checkout main
    git pull origin main

    echo "Creating and pushing new branch: $branch"
    git checkout -b "$branch"
    git push -u origin "$branch"
  fi
}

_checkout_worktree() {
  local branch="$1"
  local repo_root
  repo_root=$(git rev-parse --show-toplevel)

  local safe_name
  safe_name=$(echo "$branch" | sed 's/[^a-zA-Z0-9_-]/_/g')

  local worktree_dir="$repo_root/.worktrees/$safe_name"

  if [ -d "$worktree_dir" ]; then
    echo "Worktree already exists at $worktree_dir"
    echo "To remove: cd $repo_root && git worktree remove .worktrees/$safe_name"
    return 1
  fi

  echo "Fetching latest from origin"
  git fetch origin main

  echo "Creating worktree at $worktree_dir"
  git worktree add -b "$branch" "$worktree_dir" origin/main || {
    echo "Failed to create worktree. Branch may already exist."
    return 1
  }

  # Copy gitignored files needed for development
  if [ -f "$repo_root/rails/.env" ]; then
    echo "Copying .env file"
    cp "$repo_root/rails/.env" "$worktree_dir/rails/.env"
  fi

  echo "Pushing branch to origin"
  git -C "$worktree_dir" push -u origin "$branch"

  cd "$worktree_dir/rails" || { echo "Failed to cd into worktree"; return 1; }

  echo ""
  echo "Worktree ready!"
  echo "   Branch: $branch"
  echo "   Path:   $(pwd)"
  echo ""
  echo "   To clean up later:"
  echo "     cd $repo_root && git worktree remove .worktrees/$safe_name"
}

_checkout_isolated() {
  local branch="$1"
  local repo_root
  repo_root=$(git rev-parse --show-toplevel)

  local safe_name
  safe_name=$(echo "$branch" | sed 's/[^a-zA-Z0-9_-]/_/g')

  local worktree_dir="$repo_root/.worktrees/$safe_name"
  local db_name="tern_wt_$(echo "$safe_name" | cut -c1-40)"

  if [ -d "$worktree_dir" ]; then
    echo "Worktree already exists at $worktree_dir"
    echo "To remove: cd $repo_root && git worktree remove .worktrees/$safe_name"
    return 1
  fi

  echo "Fetching latest from origin"
  git fetch origin main

  echo "Creating worktree at $worktree_dir"
  git worktree add -b "$branch" "$worktree_dir" origin/main || {
    echo "Failed to create worktree. Branch may already exist."
    return 1
  }

  # Copy gitignored files needed for development
  if [ -f "$repo_root/rails/.env" ]; then
    echo "Copying .env file"
    cp "$repo_root/rails/.env" "$worktree_dir/rails/.env"
  fi

  # Configure worktree to use an isolated database
  echo "Configuring isolated database: $db_name"
  sed -i '' "s/database: tern_development/database: $db_name/g" "$worktree_dir/rails/config/database.yml"
  sed -i '' "s/database: tern_test/database: ${db_name}_test/g" "$worktree_dir/rails/config/database.yml"

  # Hide the database.yml change from git
  git -C "$worktree_dir" update-index --skip-worktree rails/config/database.yml

  cd "$worktree_dir/rails" || { echo "Failed to cd into worktree"; return 1; }

  echo "Installing dependencies"
  bundle install --quiet

  echo "Creating database"
  bin/rails db:create || { echo "Failed to create database"; return 1; }

  echo "Loading schema"
  bin/rails db:schema:load || { echo "Failed to load schema"; return 1; }

  echo "Seeding database"
  bin/rails db:seed || { echo "Failed to seed database"; return 1; }

  echo "Pushing branch to origin"
  git push -u origin "$branch"

  echo ""
  echo "Isolated worktree ready!"
  echo "   Branch:   $branch"
  echo "   Database: $db_name"
  echo "   Path:     $(pwd)"
  echo ""
  echo "   To clean up later:"
  echo "     cd $repo_root && git worktree remove .worktrees/$safe_name"
  echo "     dropdb $db_name && dropdb ${db_name}_test"
}
