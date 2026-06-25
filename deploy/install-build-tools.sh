#!/usr/bin/env bash
# PMM In Progress toolchain on control plane / runners (lint + partial build).
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
APT_INSTALL=(apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

apt-get update
"${APT_INSTALL[@]}" make build-essential git curl ca-certificates

# Docker for PMM devcontainer / pmm-framework (runners already install docker)
if ! command -v docker >/dev/null 2>&1; then
  "${APT_INSTALL[@]}" docker.io
  systemctl enable --now docker 2>/dev/null || true
fi

# Yarn via corepack (Node 22 ships corepack; must be enabled for all users)
if command -v corepack >/dev/null 2>&1; then
  corepack enable
  corepack prepare yarn@1.22.22 --activate 2>/dev/null || corepack prepare yarn@stable --activate
fi
# Ensure yarn on PATH for non-login shells (agent-canvas subprocesses)
if command -v corepack >/dev/null 2>&1 && ! command -v yarn >/dev/null 2>&1; then
  ln -sf "$(command -v corepack)" /usr/local/bin/yarn 2>/dev/null || true
fi

# Go (host tests; full make build still prefers devcontainer: make env-up && make env TARGET=build)
if ! command -v go >/dev/null 2>&1; then
  "${APT_INSTALL[@]}" golang-go
fi

echo "[install-build-tools] make=$(make --version | head -1)"
echo "[install-build-tools] go=$(go version 2>/dev/null || echo missing)"
echo "[install-build-tools] yarn=$(yarn --version 2>/dev/null || echo missing)"
echo "[install-build-tools] docker=$(docker --version 2>/dev/null || echo missing)"
