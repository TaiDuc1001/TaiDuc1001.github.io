#!/usr/bin/env bash

set -euo pipefail

print_tectonic_version() {
  local tectonic_bin="$1"

  if "$tectonic_bin" -V >/dev/null 2>&1; then
    "$tectonic_bin" -V
    return 0
  fi

  if "$tectonic_bin" --version >/dev/null 2>&1; then
    "$tectonic_bin" --version
    return 0
  fi

  # Some builds may not expose a version flag; do not fail install just for that.
  echo "tectonic is available at ${tectonic_bin}, but version flag is unsupported."
  return 0
}

if command -v tectonic >/dev/null 2>&1; then
  print_tectonic_version "$(command -v tectonic)"
  exit 0
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Unsupported OS: $(uname -s). Please install tectonic manually." >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64|amd64)
    target_triple="x86_64-unknown-linux-gnu"
    ;;
  aarch64|arm64)
    target_triple="aarch64-unknown-linux-musl"
    ;;
  i686|i386)
    target_triple="i686-unknown-linux-gnu"
    ;;
  *)
    echo "Unsupported architecture: $(uname -m). Please install tectonic manually." >&2
    exit 1
    ;;
esac

api_json="$(curl -fsSL https://api.github.com/repos/tectonic-typesetting/tectonic/releases/latest)"
tag_name="$(printf '%s\n' "$api_json" | sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

if [[ -z "$tag_name" ]]; then
  echo "Unable to detect latest tectonic release tag." >&2
  exit 1
fi

version="${tag_name#tectonic@}"
asset_name="tectonic-${version}-${target_triple}.tar.gz"
download_url="$(printf '%s\n' "$api_json" | sed -n "s#^[[:space:]]*\"browser_download_url\":[[:space:]]*\"\\([^\"]*${asset_name}\\)\".*#\\1#p" | head -n1)"

if [[ -z "$download_url" ]]; then
  echo "Unable to find download URL for ${asset_name}." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

archive_path="${tmp_dir}/${asset_name}"
curl -fsSL "$download_url" -o "$archive_path"
tar -xzf "$archive_path" -C "$tmp_dir"

binary_path="$(find "$tmp_dir" -maxdepth 3 -type f -name tectonic | head -n1)"
if [[ -z "$binary_path" ]]; then
  echo "Unable to locate tectonic binary in downloaded archive." >&2
  exit 1
fi

default_install_dir="${TECTONIC_INSTALL_DIR:-/usr/local/bin}"
install_dir="$default_install_dir"

if ! mkdir -p "$install_dir" 2>/dev/null || [[ ! -w "$install_dir" ]]; then
  install_dir="${HOME}/.local/bin"
  mkdir -p "$install_dir"
fi

install -m 0755 "$binary_path" "${install_dir}/tectonic"

print_tectonic_version "${install_dir}/tectonic"

if [[ "$install_dir" == "${HOME}/.local/bin" ]]; then
  echo "tectonic installed to ${install_dir}. Ensure this directory is in PATH."
fi
