#!/usr/bin/env python3
"""One-off VM verification via SSH (reads root_password from terraform.tfvars)."""
import re
import sys
import time
from pathlib import Path

import paramiko

IP = sys.argv[1] if len(sys.argv) > 1 else ""
TFVARS = Path(__file__).resolve().parents[1] / "terraform" / "terraform.tfvars"

if not IP:
    print("Usage: verify-vm-ssh.py <public_ip>", file=sys.stderr)
    sys.exit(1)

text = TFVARS.read_text(encoding="utf-8")
match = re.search(r'root_password\s*=\s*"([^"]*)"', text)
if not match:
    print("root_password not found in terraform.tfvars", file=sys.stderr)
    sys.exit(1)
password = match.group(1)

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

print(f"Waiting for SSH on {IP}...")
for i in range(48):
    try:
        client.connect(
            IP,
            username="root",
            password=password,
            timeout=20,
            banner_timeout=40,
            auth_timeout=30,
        )
        print(f"SSH connected (attempt {i + 1})")
        break
    except Exception as exc:
        print(f"  attempt {i + 1}: {type(exc).__name__}")
        time.sleep(10)
else:
    print("SSH timeout", file=sys.stderr)
    sys.exit(1)


def run(cmd: str, timeout: int = 120) -> tuple[int, str]:
    _, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode(errors="replace")
    err = stderr.read().decode(errors="replace")
    code = stdout.channel.recv_exit_status()
    print(f"\n=== {cmd} (exit {code}) ===")
    if out.strip():
        print(out.rstrip().encode("ascii", errors="replace").decode())
    if err.strip():
        print(err.rstrip().encode("ascii", errors="replace").decode())
    return code, out


print("\nPolling cloud-init (up to ~15 min)...")
for _ in range(45):
    _, out = run("cloud-init status 2>/dev/null | head -1")
    line = out.strip()
    if "status: done" in line:
        print("\n>>> cloud-init DONE")
        break
    if "status: error" in line:
        print("\n>>> cloud-init ERROR (dumping logs)")
        break
    time.sleep(20)

for cmd in [
    "cloud-init status --long",
    "tail -50 /var/log/pmm-agentic-flow-bootstrap.log",
    "systemctl is-active orchestrator nginx ngrok || true",
    "curl -sf http://127.0.0.1:8080/orchestrator/health; echo",
    "curl -sf http://127.0.0.1:8787/orchestrator/health; echo",
    "ls -l /dev/disk/by-id/scsi-0Linode_Volume_* 2>/dev/null; mount | grep agentic || true",
    "journalctl -u ngrok -n 15 --no-pager",
    "journalctl -u orchestrator -n 10 --no-pager",
]:
    run(cmd)

client.close()
print("\n=== VERIFY COMPLETE ===")
