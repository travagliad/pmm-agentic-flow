#!/usr/bin/env bash
# Print public IPv4 (never IPv6 — Linode URL is https://<ipv4>/).
set -euo pipefail
curl -4 -fsSL https://ifconfig.me/ip 2>/dev/null \
  || curl -4 -fsSL https://ipv4.icanhazip.com 2>/dev/null \
  || (ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}') \
  || hostname -I | awk '{for(i=1;i<=NF;i++) if ($i ~ /^\d+\.\d+\.\d+\.\d+$/) {print $i; exit}}'
