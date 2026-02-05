#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install-heelercli-pre-commit.sh [--global] [--hooks-path PATH] [--uninstall]

Installs a Git pre-commit hook that runs heelercli.

Modes:
  (default)    Install in the current repo.
  --global     Install in the global Git hooks directory.
  --hooks-path Override hooks directory (repo only).
  --uninstall  Remove the installed hook.

USAGE
}

GLOBAL=false
UNINSTALL=false
HOOKS_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)
      GLOBAL=true
      shift
      ;;
    --hooks-path)
      HOOKS_PATH="$2"
      shift 2
      ;;
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# ------------------------------
# Determine hooks directory
# ------------------------------
if $GLOBAL; then
  GLOBAL_PATH="$(git config --global core.hooksPath || true)"
  if [[ -z "$GLOBAL_PATH" ]]; then
    GLOBAL_PATH="$HOME/.git-hooks"
    git config --global core.hooksPath "$GLOBAL_PATH"
    echo "Configured global Git hooks at $GLOBAL_PATH"
  fi
  HOOKS_PATH="$GLOBAL_PATH"
else
  if [[ -z "$HOOKS_PATH" ]]; then
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      HOOKS_PATH="$(git rev-parse --git-path hooks)"
    else
      HOOKS_PATH="$PWD/.git/hooks"
      echo "Git repository not detected; using fallback hooks path $HOOKS_PATH"
    fi
  fi
fi

mkdir -p "$HOOKS_PATH"

PRE_COMMIT="$HOOKS_PATH/pre-commit"
HCLI_HOOK="$HOOKS_PATH/heelercli-pre-commit"
MARKER="# heelercli pre-commit wrapper"

# ------------------------------
# Uninstall
# ------------------------------
uninstall() {
   rm -f "$PRE_COMMIT"
   echo "Removed heelercli pre-commit wrapper."
}

if $UNINSTALL; then
  uninstall
  exit 0
fi

# ------------------------------
# Create heelercli hook
# ------------------------------
cat > "$HCLI_HOOK" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! command -v heelercli >/dev/null 2>&1; then
  echo "heelercli is not on PATH; skipping scan." >&2
  exit 0
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

heelercli --pre-commit .
EOF
chmod +x "$HCLI_HOOK"

# ------------------------------
# Install wrapper
# ------------------------------
cat > "$PRE_COMMIT" <<EOF
#!/usr/bin/env bash
$MARKER
set -euo pipefail

hcli_hook="$HCLI_HOOK"

"\$hcli_hook" "\$@"
EOF
chmod +x "$PRE_COMMIT"

echo "heelercli pre-commit hook installed at $PRE_COMMIT"
