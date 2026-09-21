#!/usr/bin/env bash
set -euo pipefail

# ENG-13666: the installer must preserve existing hooks and restore them on uninstall.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$ROOT_DIR/install-heelercli-precommit.sh"
TMPDIR_PATH="$(mktemp -d)"
trap "rm -rf '$TMPDIR_PATH'" EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "expected file $1"
}

assert_missing() {
  [[ ! -e "$1" ]] || fail "expected $1 to be absent"
}

assert_output() {
  local expected="$1"
  local actual="$2"
  [[ "$actual" == "$expected" ]] || fail "expected '$expected', got '$actual'"
}

make_cli_stub() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/heelercli" <<'EOF'
#!/usr/bin/env bash
printf 'heelercli %s\n' "$*"
EOF
  chmod +x "$bin_dir/heelercli"
}

test_fresh_install() {
  local case_dir="$TMPDIR_PATH/fresh"
  local hooks_dir="$case_dir/hooks"
  local bin_dir="$case_dir/bin"
  mkdir -p "$hooks_dir"
  make_cli_stub "$bin_dir"

  "$INSTALLER" --hooks-path "$hooks_dir" >/dev/null
  local output
  output="$(PATH="$bin_dir:$PATH" "$hooks_dir/pre-commit")"
  assert_output "heelercli secrets --pre-commit" "$output"

  "$INSTALLER" --hooks-path "$hooks_dir" --uninstall >/dev/null
  assert_missing "$hooks_dir/pre-commit"
  assert_missing "$hooks_dir/heelercli-pre-commit"
  assert_missing "$hooks_dir/pre-commit.heelercli-original"
  echo "PASS: fresh install uses the current CLI command"
}

test_existing_hook_round_trip() {
  local case_dir="$TMPDIR_PATH/existing"
  local hooks_dir="$case_dir/hooks"
  local bin_dir="$case_dir/bin"
  local expected_hook="$case_dir/original-pre-commit"
  local expected_mode
  mkdir -p "$hooks_dir"
  make_cli_stub "$bin_dir"

  cat > "$hooks_dir/pre-commit" <<'EOF'
#!/usr/bin/env bash
printf 'original hook\n'
EOF
  chmod +x "$hooks_dir/pre-commit"
  cp -p "$hooks_dir/pre-commit" "$expected_hook"
  expected_mode="$(stat -c '%a' "$hooks_dir/pre-commit")"

  "$INSTALLER" --hooks-path "$hooks_dir" >/dev/null
  local output
  output="$(PATH="$bin_dir:$PATH" "$hooks_dir/pre-commit")"
  assert_output $'original hook\nheelercli secrets --pre-commit' "$output"

  "$INSTALLER" --hooks-path "$hooks_dir" >/dev/null
  output="$(PATH="$bin_dir:$PATH" "$hooks_dir/pre-commit")"
  assert_output $'original hook\nheelercli secrets --pre-commit' "$output"

  "$INSTALLER" --hooks-path "$hooks_dir" --uninstall >/dev/null
  cmp -s "$expected_hook" "$hooks_dir/pre-commit" || fail "uninstall did not restore the original hook byte-for-byte"
  assert_output "$expected_mode" "$(stat -c '%a' "$hooks_dir/pre-commit")"
  assert_missing "$hooks_dir/heelercli-pre-commit"
  assert_missing "$hooks_dir/pre-commit.heelercli-original"
  echo "PASS: existing hook survives install, reinstall, and uninstall"
}

test_uninstall_refuses_changed_hook() {
  local case_dir="$TMPDIR_PATH/changed"
  local hooks_dir="$case_dir/hooks"
  mkdir -p "$hooks_dir"

  cat > "$hooks_dir/pre-commit" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$hooks_dir/pre-commit"
  "$INSTALLER" --hooks-path "$hooks_dir" >/dev/null

  cat > "$hooks_dir/pre-commit" <<'EOF'
#!/usr/bin/env bash
printf 'replacement hook\n'
EOF
  chmod +x "$hooks_dir/pre-commit"

  if "$INSTALLER" --hooks-path "$hooks_dir" --uninstall >/dev/null 2>&1; then
    fail "uninstall replaced a hook it does not own"
  fi
  assert_output "replacement hook" "$("$hooks_dir/pre-commit")"
  assert_file "$hooks_dir/pre-commit.heelercli-original"
  echo "PASS: uninstall preserves a hook changed after installation"
}

test_global_configuration_round_trip() {
  local case_dir="$TMPDIR_PATH/global"
  local home_dir="$case_dir/home"
  local config_file="$case_dir/gitconfig"
  local hooks_dir="$home_dir/.git-hooks"
  local repo_dir="$case_dir/repo"
  local bin_dir="$case_dir/bin"
  mkdir -p "$home_dir" "$repo_dir"
  make_cli_stub "$bin_dir"
  git -C "$repo_dir" init -q
  cat > "$repo_dir/.git/hooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
printf 'repository hook\n'
EOF
  chmod +x "$repo_dir/.git/hooks/pre-commit"

  HOME="$home_dir" GIT_CONFIG_GLOBAL="$config_file" "$INSTALLER" --global >/dev/null
  assert_output "$hooks_dir" "$(HOME="$home_dir" GIT_CONFIG_GLOBAL="$config_file" git config --global core.hooksPath)"
  assert_file "$hooks_dir/.heelercli-created-core-hooks-path"
  local output
  output="$(cd "$repo_dir" && HOME="$home_dir" GIT_CONFIG_GLOBAL="$config_file" PATH="$bin_dir:$PATH" "$hooks_dir/pre-commit")"
  assert_output $'repository hook\nheelercli secrets --pre-commit' "$output"

  HOME="$home_dir" GIT_CONFIG_GLOBAL="$config_file" "$INSTALLER" --global --uninstall >/dev/null
  if HOME="$home_dir" GIT_CONFIG_GLOBAL="$config_file" git config --global core.hooksPath >/dev/null 2>&1; then
    fail "uninstall did not restore the previous global hooks configuration"
  fi
  assert_missing "$hooks_dir/.heelercli-created-core-hooks-path"
  assert_file "$repo_dir/.git/hooks/pre-commit"
  echo "PASS: global install restores Git configuration on uninstall"
}

test_fresh_install
test_existing_hook_round_trip
test_uninstall_refuses_changed_hook
test_global_configuration_round_trip

echo "All installer regression cases passed."
