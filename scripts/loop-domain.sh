#!/usr/bin/env bash
# Compute the standard PMM Agent Canvas hostname (sslip.io, no manual DNS).
# Pattern: {prefix}.{ip-with-dashes}.sslip.io  (default prefix: pmmagents)
set -euo pipefail

prefix="${DOMAIN_PREFIX:-pmmagents}"
ip="${1:-$(curl -fsSL https://ifconfig.me/ip 2>/dev/null || hostname -I | awk '{print $1}')}"
echo "${prefix}.${ip//./-}.sslip.io"
