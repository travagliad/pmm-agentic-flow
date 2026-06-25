#!/usr/bin/env bash
# Run from deploy/: bash open-firewall.sh
exec bash "$(cd "$(dirname "$0")/.." && pwd)/scripts/open-linode-firewall.sh"
