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
  --uninstall  Remove the Heeler hook and restore the previous hook.

USAGE
}

GLOBAL=false
UNINSTALL=false
HOOKS_PATH=""
CONFIGURED_GLOBAL_PATH=false

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
    if ! $UNINSTALL; then
      CONFIGURED_GLOBAL_PATH=true
    fi
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
ORIGINAL_HOOK="$HOOKS_PATH/pre-commit.heelercli-original"
GLOBAL_CONFIG_MARKER="$HOOKS_PATH/.heelercli-created-core-hooks-path"
MARKER="# heelercli pre-commit wrapper"
HOOK_MARKER="# heelercli managed hook"
CHAIN_REPOSITORY_HOOK=false

if $GLOBAL && { $CONFIGURED_GLOBAL_PATH || [[ -f "$GLOBAL_CONFIG_MARKER" ]]; }; then
  CHAIN_REPOSITORY_HOOK=true
fi

path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

is_managed_wrapper() {
  [[ -f "$PRE_COMMIT" ]] && grep -Fqx "$MARKER" "$PRE_COMMIT"
}

is_managed_hook() {
  [[ -f "$HCLI_HOOK" ]] && grep -Fqx "$HOOK_MARKER" "$HCLI_HOOK"
}

is_legacy_managed_hook() {
  [[ -f "$HCLI_HOOK" ]] && grep -Fqx "heelercli --pre-commit ." "$HCLI_HOOK"
}

uninstall() {
  if path_exists "$PRE_COMMIT" && ! is_managed_wrapper; then
    echo "Error: $PRE_COMMIT is not managed by heelercli; refusing to overwrite it during uninstall." >&2
    if path_exists "$ORIGINAL_HOOK"; then
      echo "The original hook remains at $ORIGINAL_HOOK." >&2
    fi
    exit 1
  fi

  if is_managed_wrapper; then
    rm -f "$PRE_COMMIT"
  fi

  if path_exists "$ORIGINAL_HOOK"; then
    mv "$ORIGINAL_HOOK" "$PRE_COMMIT"
    echo "Restored the original pre-commit hook at $PRE_COMMIT."
  else
    echo "Removed heelercli pre-commit wrapper."
  fi

  if is_managed_hook || is_legacy_managed_hook; then
    rm -f "$HCLI_HOOK"
  fi

  if $GLOBAL && [[ -f "$GLOBAL_CONFIG_MARKER" ]]; then
    if [[ "$(git config --global core.hooksPath || true)" == "$HOOKS_PATH" ]]; then
      git config --global --unset core.hooksPath
      echo "Restored the previous global Git hooks configuration."
    fi
    rm -f "$GLOBAL_CONFIG_MARKER"
  fi
}

if $UNINSTALL; then
  uninstall
  exit 0
fi

if path_exists "$PRE_COMMIT" && ! is_managed_wrapper && path_exists "$ORIGINAL_HOOK"; then
  echo "Error: Cannot preserve $PRE_COMMIT because $ORIGINAL_HOOK already exists." >&2
  exit 1
fi

if path_exists "$HCLI_HOOK" && ! is_managed_hook && ! is_legacy_managed_hook; then
  echo "Error: $HCLI_HOOK already exists and is not managed by heelercli." >&2
  exit 1
fi

if path_exists "$PRE_COMMIT" && ! is_managed_wrapper; then
  mv "$PRE_COMMIT" "$ORIGINAL_HOOK"
fi

cat > "$HCLI_HOOK" <<'EOF'
#!/usr/bin/env bash
# heelercli managed hook
set -euo pipefail

if ! command -v heelercli >/dev/null 2>&1; then
  echo "heelercli is not on PATH; skipping scan." >&2
  exit 0
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

heelercli secrets --pre-commit
EOF
chmod +x "$HCLI_HOOK"

cat > "$PRE_COMMIT" <<EOF
#!/usr/bin/env bash
$MARKER
set -euo pipefail

hooks_dir="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
original_hook="\$hooks_dir/$(basename "$ORIGINAL_HOOK")"
hcli_hook="\$hooks_dir/$(basename "$HCLI_HOOK")"
chain_repository_hook="$CHAIN_REPOSITORY_HOOK"

if [[ -x "\$original_hook" ]]; then
  "\$original_hook" "\$@"
fi
if [[ "\$chain_repository_hook" == true ]]; then
  git_common_dir="\$(git rev-parse --git-common-dir)"
  repository_hook="\$git_common_dir/hooks/pre-commit"
  if [[ -x "\$repository_hook" ]]; then
    "\$repository_hook" "\$@"
  fi
fi
"\$hcli_hook" "\$@"
EOF
chmod +x "$PRE_COMMIT"

if $CONFIGURED_GLOBAL_PATH; then
  touch "$GLOBAL_CONFIG_MARKER"
  git config --global core.hooksPath "$HOOKS_PATH"
  echo "Configured global Git hooks at $HOOKS_PATH"
fi

echo "heelercli pre-commit hook installed at $PRE_COMMIT"
