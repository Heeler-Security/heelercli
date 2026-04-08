#!/usr/bin/env bash
# heelercli pre-commit hook with automatic binary download
set -euo pipefail

REPO="Heeler-Security/heelercli"
CACHE_DIR="${HEELERCLI_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/heelercli}"
BIN_EXT=""
HEELERCLI_BIN="$CACHE_DIR/heelercli"
VERSION_FILE="$CACHE_DIR/.version"

EXPECTED_VERSION="${HEELERCLI_VERSION:-latest}"

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

get_platform() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  if [[ "$os" == "Darwin" && "$arch" == "x86_64" ]]; then
    local proc_translated=""
    local arm64_capable=""
    proc_translated="$(sysctl -in sysctl.proc_translated 2>/dev/null || true)"
    arm64_capable="$(sysctl -in hw.optional.arm64 2>/dev/null || true)"

    if [[ "$proc_translated" == "1" ]]; then
      cat >&2 <<'EOF'
Error: Detected a Rosetta-translated shell on Apple Silicon.
The auto-install hook cannot use darwin-amd64 because only darwin-arm64 builds are published.

Open a native arm64 terminal and run pre-commit again.
Examples:
  arch -arm64 /bin/zsh
  arch -arm64 /bin/bash
EOF
      exit 1
    fi

    if [[ "$arm64_capable" == "1" ]]; then
      cat >&2 <<'EOF'
Error: This appears to be Apple Silicon running an x86_64 shell.
The auto-install hook cannot use darwin-amd64 because only darwin-arm64 builds are published.

Open a native arm64 terminal and run pre-commit again.
EOF
      exit 1
    fi
  fi

  case "$os" in
    Linux)               platform="linux" ;;
    Darwin)              platform="darwin" ;;
    MINGW*|MSYS*|CYGWIN*) platform="windows" ;;
    *) echo "Error: Unsupported OS '$os'" >&2; exit 1 ;;
  esac

  case "$arch" in
    x86_64|amd64)
      if [[ "$platform" == "darwin" ]]; then
        echo "Error: macOS amd64 (darwin-amd64) is not supported by published heelercli binaries." >&2
        exit 1
      fi
      arch_suffix="amd64"
      ;;
    arm64|aarch64) arch_suffix="arm64" ;;
    *) echo "Error: Unsupported architecture '$arch'" >&2; exit 1 ;;
  esac

  echo "${platform}-${arch_suffix}"
}

download_heelercli() {
  local platform="$1"
  local version="$2"

  local ext="tgz"
  if [[ "$platform" == windows-* ]]; then
    ext="zip"
  fi

  local asset_name="heelercli-${platform}.${ext}"
  local download_url

  if [[ "$version" == "latest" ]]; then
    download_url="https://github.com/${REPO}/releases/latest/download/${asset_name}"
  else
    download_url="https://github.com/${REPO}/releases/download/${version}/${asset_name}"
  fi

  mkdir -p "$CACHE_DIR"
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" EXIT

  echo "Downloading heelercli ($version) for $platform..." >&2

  if ! curl -fLsS "$download_url" -o "$tmpdir/$asset_name"; then
    echo "Error: Failed to download $download_url" >&2
    exit 1
  fi

  local binary_name="heelercli${BIN_EXT}"

  if [[ "$ext" == "zip" ]]; then
    if ! command -v unzip &>/dev/null; then
      echo "Error: 'unzip' is required on Windows but was not found. Install Git for Windows or add unzip to PATH." >&2
      exit 1
    fi
    unzip -o -q "$tmpdir/$asset_name" -d "$tmpdir"
  else
    tar -C "$tmpdir" -xzf "$tmpdir/$asset_name"
  fi

  if [[ ! -f "$tmpdir/$binary_name" ]]; then
    echo "Error: Binary not found in downloaded archive" >&2
    exit 1
  fi

  mv "$tmpdir/$binary_name" "$HEELERCLI_BIN"
  chmod +x "$HEELERCLI_BIN"

  # Store the version we downloaded
  if [[ "$version" == "latest" ]]; then
    "$HEELERCLI_BIN" --version 2>/dev/null | head -1 > "$VERSION_FILE" || echo "latest" > "$VERSION_FILE"
  else
    echo "$version" > "$VERSION_FILE"
  fi

  echo "heelercli installed to $HEELERCLI_BIN" >&2
}

needs_download() {
  if [[ ! -x "$HEELERCLI_BIN" ]]; then
    return 0
  fi

  # Use existing binary for 'latest'
  if [[ "$EXPECTED_VERSION" == "latest" ]]; then
    return 1
  fi

  if [[ -f "$VERSION_FILE" ]]; then
    local installed_version
    installed_version="$(cat "$VERSION_FILE")"
    local expected_normalized="$EXPECTED_VERSION"
    if [[ "$expected_normalized" != v* ]]; then
      expected_normalized="v${expected_normalized}"
    fi
    if [[ "$installed_version" == *"$expected_normalized"* ]] || [[ "$installed_version" == "$EXPECTED_VERSION" ]]; then
      return 1
    fi
  fi

  return 0
}

main() {
  local platform
  local full_scan=false
  local only_validated=false
  local -a forward_args=()
  local -a secrets_args=()

  for arg in "$@"; do
    if [[ "$arg" == "--full-scan" ]]; then
      full_scan=true
    elif [[ "$arg" == "--secrets-only-validated" ]]; then
      only_validated=true
    else
      forward_args+=("$arg")
    fi
  done

  if is_truthy "${HEELERCLI_FULL_SECRETS_SCAN:-}"; then
    full_scan=true
  fi

  if is_truthy "${HEELERCLI_SECRETS_ONLY_VALIDATED:-}"; then
    only_validated=true
  fi

  case "${HEELERCLI_SECRETS_MODE:-}" in
    full|all)
      full_scan=true
      ;;
    pre-commit|staged|"")
      ;;
    *)
      echo "Error: Unsupported HEELERCLI_SECRETS_MODE='${HEELERCLI_SECRETS_MODE}'. Use 'pre-commit' or 'full'." >&2
      exit 1
      ;;
  esac

  platform="$(get_platform)"

  # Set Windows-specific binary extension and path
  if [[ "$platform" == windows-* ]]; then
    BIN_EXT=".exe"
    HEELERCLI_BIN="$CACHE_DIR/heelercli.exe"
  fi

  if needs_download; then
    download_heelercli "$platform" "$EXPECTED_VERSION"
  fi

  if $only_validated; then
    secrets_args+=("--only-validated")
  fi

  if $full_scan; then
    exec "$HEELERCLI_BIN" secrets ${secrets_args[@]+"${secrets_args[@]}"} . ${forward_args[@]+"${forward_args[@]}"}
  fi

  exec "$HEELERCLI_BIN" secrets --pre-commit ${secrets_args[@]+"${secrets_args[@]}"} . ${forward_args[@]+"${forward_args[@]}"}
}

main "$@"
