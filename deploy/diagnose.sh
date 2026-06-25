#!/usr/bin/env bash
# Run from deploy/: bash diagnose.sh
exec bash "$(cd "$(dirname "$0")/.." && pwd)/scripts/stack-diagnose.sh"
