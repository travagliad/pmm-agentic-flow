#!/usr/bin/env bash
# Mount Linode block volume (if attached) and wire persistence paths.
set -euo pipefail

AGENT_USER="${AGENT_USER:-agentcanvas}"
MOUNT="/mnt/agentic-data"
MARKER="${MOUNT}/.volume_initialized"

if [ ! -b /dev/sdb ]; then
  echo "[mount-data] no block volume attached, using local disk"
  exit 0
fi

if ! blkid /dev/sdb >/dev/null 2>&1; then
  mkfs.ext4 -L agentic-data /dev/sdb
fi

mkdir -p "$MOUNT"
if ! mountpoint -q "$MOUNT"; then
  mount /dev/sdb "$MOUNT"
fi
grep -q agentic-data /etc/fstab || echo 'LABEL=agentic-data /mnt/agentic-data ext4 defaults 0 2' >> /etc/fstab

mkdir -p "${MOUNT}/openhands" "${MOUNT}/orchestrator"
touch "$MARKER"

OH="/home/${AGENT_USER}/.openhands"
if [ ! -L "$OH" ]; then
  rm -rf "$OH"
  ln -s "${MOUNT}/openhands" "$OH"
fi
mkdir -p "${MOUNT}/openhands/storage" "${MOUNT}/openhands/workspaces" \
  "${MOUNT}/openhands/automation" "${MOUNT}/openhands/agent-canvas"
chown -R "${AGENT_USER}:${AGENT_USER}" "${MOUNT}/openhands"

ORCH="/var/lib/pmm-agentic-flow/orchestrator"
if [ ! -L "$ORCH" ]; then
  rm -rf "$ORCH"
  ln -s "${MOUNT}/orchestrator" "$ORCH"
fi
mkdir -p "${MOUNT}/orchestrator"

echo "[mount-data] persistence on ${MOUNT}"
