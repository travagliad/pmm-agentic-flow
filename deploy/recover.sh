#!/usr/bin/env bash
# Run from deploy/: bash recover.sh
exec bash "$(cd "$(dirname "$0")/.." && pwd)/scripts/linode-recover.sh"
