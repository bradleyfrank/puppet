#!/usr/local/env bash

set -eu

homebrew_url="https://raw.githubusercontent.com/Homebrew/install/master/install"
bootstrap_repo="https://github.com/bradleyfrank/bootstraps.git"

cleanup() {
  rm -rf "$tmp_repo"
}

not_supported() {
  printf '%s\n' "Unsupported OS, aborting..." >&2
  exit 1
}

trap cleanup EXIT

if [[ $OSTYPE =~ ^darwin ]]; then
  xcode-select --print-path &> /dev/null || xcode-select --install
  [[ ! -x /usr/local/bin/brew ]] && /usr/bin/ruby -e "$(curl -fsSL "$homebrew_url")"
  [[ ! -x /usr/local/bin/ansible ]] && brew install ansible git
elif [[ $OSTYPE =~ ^linux ]]; then
  case "$(sed -rn 's/^ID=([a-z]+)/\1/p' /etc/os-release)" in
    fedora) sudo dnf install ansible git -y ;;
         *) not_supported                   ;;
  esac
else
  not_supported
fi

ansible-pull \
  --url "$bootstrap_repo" \
  --directory "$(mktemp -d)" \
  --inventory localhost \
  --limit localhost \
  --purge \
  --ask-become-pass --vault-id @prompt \
  site.yml

exit 0
