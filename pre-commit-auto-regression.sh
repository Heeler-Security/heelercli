#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$ROOT_DIR/heelercli-pre-commit-auto.sh"

if [[ ! -f "$HOOK_SCRIPT" ]]; then
  echo "Error: Hook script not found at $HOOK_SCRIPT" >&2
  exit 1
fi

TMPDIR_PATH="$(mktemp -d)"
trap "rm -rf '$TMPDIR_PATH'" EXIT

mkdir -p "$TMPDIR_PATH/cache"

cat >"$TMPDIR_PATH/cache/heelercli" <<'EOF'
#!/usr/bin/env bash
printf "%s\n" "$*"
EOF
chmod +x "$TMPDIR_PATH/cache/heelercli"

run_case() {
  local name="$1"
  local expected="$2"
  shift 2

  local output
  output="$(HEELERCLI_CACHE_DIR="$TMPDIR_PATH/cache" /bin/bash "$HOOK_SCRIPT" "$@" 2>/dev/null)"

  if [[ "$output" != "$expected" ]]; then
    echo "FAIL: $name" >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $output" >&2
    exit 1
  fi

  echo "PASS: $name"
}

run_env_case() {
  local name="$1"
  local env_var="$2"
  local expected="$3"

  local output
  output="$(env "$env_var" HEELERCLI_CACHE_DIR="$TMPDIR_PATH/cache" /bin/bash "$HOOK_SCRIPT" 2>/dev/null)"

  if [[ "$output" != "$expected" ]]; then
    echo "FAIL: $name" >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $output" >&2
    exit 1
  fi

  echo "PASS: $name"
}

run_case "default pre-commit mode" "secrets --pre-commit ."
run_case "full-scan flag" "secrets ." --full-scan
run_case "only-validated flag" "secrets --pre-commit --only-validated ." --secrets-only-validated
run_case "full scan + only validated" "secrets --only-validated ." --full-scan --secrets-only-validated
run_case "forward args preserved" "secrets --pre-commit . --exclude dist/**" --exclude "dist/**"

run_env_case "env full scan" "HEELERCLI_FULL_SECRETS_SCAN=1" "secrets ."
run_env_case "env only validated" "HEELERCLI_SECRETS_ONLY_VALIDATED=1" "secrets --pre-commit --only-validated ."
run_env_case "env secrets mode full" "HEELERCLI_SECRETS_MODE=full" "secrets ."

echo "All regression cases passed."
