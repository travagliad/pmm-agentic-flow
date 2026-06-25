#!/usr/bin/env bash
# Mount Linode block volume (if attached) and wire orchestrator persistence.
# Do NOT use /dev/sdb — on Linode Ubuntu it is often the swap disk.
set -euo pipefail

MOUNT="/mnt/agentic-data"
MARKER="${MOUNT}/.volume_initialized"
VOLUME_LABEL="${DATA_VOLUME_LABEL:-agentic-data}"

resolve_data_volume() {
  local id dev fstype dtype

  for id in /dev/disk/by-id/scsi-0Linode_Volume_*; do
    [ -e "$id" ] || continue
    echo "$id"
    return 0
  done

  for dev in /dev/sd? /dev/vd?; do
    [ -b "$dev" ] || continue
    [ "$dev" = /dev/sda ] && continue
    dtype=$(lsblk -no TYPE "$dev" 2>/dev/null | head -1 || true)
    [ "$dtype" = "disk" ] || continue
    fstype=$(blkid -o value -s TYPE "$dev" 2>/dev/null || true)
    [ "$fstype" = "swap" ] && continue
    if [ -z "$fstype" ] || [ "$fstype" = "ext4" ]; then
      echo "$dev"
      return 0
    fi
  done
  return 1
}

VOLUME=""
for _ in $(seq 1 24); do
  if VOLUME=$(resolve_data_volume); then
    break
  fi
  sleep 5
done

if [ -z "$VOLUME" ]; then
  echo "[mount-data] no block volume attached, using local disk"
  exit 0
fi

echo "[mount-data] using volume ${VOLUME}"

if ! blkid -L "$VOLUME_LABEL" >/dev/null 2>&1; then
  if ! blkid "$VOLUME" >/dev/null 2>&1; then
    mkfs.ext4 -L "$VOLUME_LABEL" "$VOLUME"
  else
    fstype=$(blkid -o value -s TYPE "$VOLUME")
    if [ "$fstype" = "swap" ]; then
      echo "[mount-data] ERROR: ${VOLUME} is swap — refusing to mount" >&2
      exit 1
    fi
    if [ "$fstype" != "ext4" ]; then
      echo "[mount-data] formatting ${VOLUME} (was ${fstype:-unknown})"
      mkfs.ext4 -L "$VOLUME_LABEL" "$VOLUME"
    fi
  fi
fi

mkdir -p "$MOUNT"
if ! mountpoint -q "$MOUNT"; then
  mount "LABEL=${VOLUME_LABEL}" "$MOUNT"
fi
grep -q "$VOLUME_LABEL" /etc/fstab || echo "LABEL=${VOLUME_LABEL} ${MOUNT} ext4 defaults 0 2" >> /etc/fstab

mkdir -p "${MOUNT}/orchestrator"
touch "$MARKER"

# Runner VMs only: Agent Canvas user + openhands paths
AGENT_USER="${AGENT_USER:-agentcanvas}"
if id "$AGENT_USER" >/dev/null 2>&1; then
  mkdir -p "${MOUNT}/openhands"
  OH="/home/${AGENT_USER}/.openhands"
  if [ ! -L "$OH" ]; then
    rm -rf "$OH"
    ln -s "${MOUNT}/openhands" "$OH"
  fi
  mkdir -p "${MOUNT}/openhands/storage" "${MOUNT}/openhands/workspaces" \
    "${MOUNT}/openhands/automation" "${MOUNT}/openhands/agent-canvas"
  chown -R "${AGENT_USER}:${AGENT_USER}" "${MOUNT}/openhands"
fi

ORCH="/var/lib/pmm-agentic-flow/orchestrator"
if [ ! -L "$ORCH" ]; then
  rm -rf "$ORCH"
  ln -s "${MOUNT}/orchestrator" "$ORCH"
fi
mkdir -p "${MOUNT}/orchestrator"

echo "[mount-data] persistence on ${MOUNT}"
