#!/usr/bin/env bash
# PMM In Progress toolchain on control plane / runners (lint + partial build).
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
APT_INSTALL=(apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

apt-get update
"${APT_INSTALL[@]}" make build-essential git curl ca-certificates

if ! command -v docker >/dev/null 2>&1; then
  "${APT_INSTALL[@]}" docker.io
  systemctl enable --now docker 2>/dev/null || true
fi

# Node/yarn must exist before this script (install-control-plane runs first).
if ! command -v node >/dev/null 2>&1; then
  echo "[install-build-tools] FATAL: node missing — run install-control-plane.sh first" >&2
  exit 1
fi

if ! command -v yarn >/dev/null 2>&1; then
  echo "[install-build-tools] installing yarn via npm"
  npm install -g yarn@1.22.22
fi

if ! command -v go >/dev/null 2>&1; then
  echo "[install-build-tools] installing golang-go"
  "${APT_INSTALL[@]}" golang-go || true
fi

if ! command -v go >/dev/null 2>&1; then
  echo "[install-build-tools] installing Go from go.dev"
  GO_VER=1.24.2
  ARCH=$(dpkg --print-architecture)
  case "$ARCH" in
    amd64) GO_ARCH=amd64 ;;
    arm64) GO_ARCH=arm64 ;;
    *) echo "unsupported arch $ARCH" >&2; exit 1 ;;
  esac
  curl -fsSL "https://go.dev/dl/go${GO_VER}.linux-${GO_ARCH}.tar.gz" -o /tmp/go.tar.gz
  rm -rf /usr/local/go
  tar -C /usr/local -xzf /tmp/go.tar.gz
  ln -sf /usr/local/go/bin/go /usr/local/bin/go
  ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
fi

for cmd in make go yarn node; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[install-build-tools] FATAL: $cmd not on PATH after install" >&2
    exit 1
  fi
done

echo "[install-build-tools] make=$(make --version | head -1)"
echo "[install-build-tools] go=$(go version)"
echo "[install-build-tools] yarn=$(yarn --version)"
echo "[install-build-tools] node=$(node --version)"
