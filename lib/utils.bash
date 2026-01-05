#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/nats-io/nats-server"
TOOL_NAME="nats"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//'
}

list_all_versions() {
  list_github_tags
}

get_tool_cmd() {
  local version
  version="$(echo "$1" | cut -d . -f 1)"

  # Prior to version 2 the command was gnatsd.
  if [[ "$version" -lt 2 ]]; then
    echo "gnatsd"
    return
  fi

  echo "nats-server"
}

download_release() {
  local version filename suffix url platform arch
  version="$1"
  filename="$2"
  suffix="$3"
  tool_cmd="$(get_tool_cmd "$version")"
  platform="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="${ASDF_NATS_ARCH-$(uname -m)}"

  case "$arch" in
  x86_64)
    arch=amd64
    ;;
  esac

  url="$GH_REPO/releases/download/v${version}/${tool_cmd}-v${version}-${platform}-${arch}${suffix}"

  echo "* Downloading $TOOL_NAME release $version..."
  if ! curl "${curl_opts[@]}" -o "$filename" -C - "${url}"; then
    echo "Could not download ${url}"
    return 1
  fi
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"
  local tool_cmd="$(get_tool_cmd "$version")"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    local tool_cmd
    tool_cmd="$(get_tool_cmd "$version")"

    mkdir -p "$install_path/bin"
    cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"
    mv "$install_path/$tool_cmd" "$install_path/bin"
    chmod +x "$install_path/bin/$tool_cmd"

    # Assert executable exists.
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to exist."

    echo "$TOOL_NAME $version installation was successful! The nats server is available as $tool_cmd."
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
