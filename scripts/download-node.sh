#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $(basename "$0") <node-version> (example: $(basename "$0") 20.12.2)" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIMES_DIR="$ROOT/src/NodeJs.Embedded/runtimes"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

download_and_stage() {
  local rid="$1"
  local archive="$2"
  local inner_path="$3"

  local url="https://nodejs.org/dist/v${VERSION}/${archive}"
  local archive_path="$TMP_DIR/$archive"
  local extract_dir="$TMP_DIR/extracted/$rid"

  echo "Downloading $url"
  curl -fsSL "$url" -o "$archive_path"

  mkdir -p "$extract_dir"
  case "$archive" in
    *.zip)
      unzip -q "$archive_path" -d "$extract_dir"
      ;;
    *.tar.gz|*.tgz|*.tar.xz)
      tar -xf "$archive_path" -C "$extract_dir"
      ;;
    *)
      echo "Unknown archive format for $archive" >&2
      exit 1
      ;;
  esac

  local extracted_root
  extracted_root="$(find "$extract_dir" -maxdepth 1 -type d -name "node-v*" | head -n 1)"
  if [[ -z "$extracted_root" ]]; then
    echo "Could not locate extracted Node folder inside $extract_dir" >&2
    exit 1
  fi

  local node_path="$extracted_root/$inner_path"
  if [[ ! -f "$node_path" ]]; then
    echo "Node binary not found at $node_path" >&2
    exit 1
  fi

  local dest_dir="$RUNTIMES_DIR/$rid/native"
  mkdir -p "$dest_dir"
  cp "$node_path" "$dest_dir/"
  chmod +x "$dest_dir"/node*

  if [[ -f "$extracted_root/LICENSE" ]]; then
    cp "$extracted_root/LICENSE" "$dest_dir/LICENSE"
  fi

  echo "Embedded $rid -> $dest_dir"
}

download_and_stage "win-x64" "node-v${VERSION}-win-x64.zip" "node.exe"
download_and_stage "win-arm64" "node-v${VERSION}-win-arm64.zip" "node.exe"
download_and_stage "linux-x64" "node-v${VERSION}-linux-x64.tar.xz" "bin/node"
download_and_stage "linux-arm64" "node-v${VERSION}-linux-arm64.tar.xz" "bin/node"
download_and_stage "osx-x64" "node-v${VERSION}-darwin-x64.tar.gz" "bin/node"
download_and_stage "osx-arm64" "node-v${VERSION}-darwin-arm64.tar.gz" "bin/node"

echo "Done. Files placed under $RUNTIMES_DIR"
