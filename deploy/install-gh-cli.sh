#!/usr/bin/env bash
# Official GitHub CLI - https://github.com/cli/cli/blob/trunk/docs/install_linux.md
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

if command -v gh >/dev/null 2>&1; then
  echo "[install-gh-cli] already installed: $(gh --version | head -1)"
  exit 0
fi

(type -p wget >/dev/null || (apt-get update && apt-get install -y wget)) \
  && mkdir -p -m 755 /etc/apt/keyrings \
  && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && cat "$out" | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
  && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && mkdir -p -m 755 /etc/apt/sources.list.d \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
  && apt-get update \
  && apt-get install -y gh

echo "[install-gh-cli] $(gh --version | head -1)"
