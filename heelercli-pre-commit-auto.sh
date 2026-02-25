#!/usr/bin/env bash
# heelercli pre-commit hook with automatic binary download
set -euo pipefail

REPO="Heeler-Security/heelercli"
CACHE_DIR="${HEELERCLI_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/heelercli}"
BIN_EXT=""
HEELERCLI_BIN="$CACHE_DIR/heelercli"
VERSION_FILE="$CACHE_DIR/.version"

EXPECTED_VERSION="${HEELERCLI_VERSION:-latest}"

get_platform() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Linux)               platform="linux" ;;
    Darwin)              platform="darwin" ;;
    MINGW*|MSYS*|CYGWIN*) platform="windows" ;;
    *) echo "Error: Unsupported OS '$os'" >&2; exit 1 ;;
  esac

  case "$arch" in
    x86_64|amd64)  arch_suffix="amd64" ;;
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
  trap 'rm -rf "$tmpdir"' EXIT

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
  platform="$(get_platform)"

  # Set Windows-specific binary extension and path
  if [[ "$platform" == windows-* ]]; then
    BIN_EXT=".exe"
    HEELERCLI_BIN="$CACHE_DIR/heelercli.exe"
  fi

  if needs_download; then
    download_heelercli "$platform" "$EXPECTED_VERSION"
  fi

  # Run heelercli secrets
  exec "$HEELERCLI_BIN" secrets --pre-commit . "$@"
}

main "$@"
