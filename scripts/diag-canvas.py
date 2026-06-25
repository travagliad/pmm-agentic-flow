#!/usr/bin/env python3
import re
import sys
from pathlib import Path

import paramiko

ip = sys.argv[1]
tfvars = Path(__file__).resolve().parents[1] / "terraform" / "terraform.tfvars"
password = re.search(r'root_password\s*=\s*"([^"]*)"', tfvars.read_text()).group(1)
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(ip, username="root", password=password, timeout=30)
cmds = [
    "systemctl is-active agent-canvas || true",
    "systemctl status agent-canvas --no-pager -l | head -30",
    "journalctl -u agent-canvas -n 30 --no-pager",
    "curl -sI http://127.0.0.1:8000/ | head -8",
    "sudo -u agentcanvas test -r /etc/pmm-agentic-flow/env; echo env_readable=$?",
    "which agent-canvas; ls -la /usr/bin/agent-canvas /usr/local/bin/agent-canvas 2>&1",
]
for cmd in cmds:
    _, stdout, stderr = client.exec_command(cmd, timeout=60)
    print(f"\n=== {cmd} ===\n{stdout.read().decode()}{stderr.read().decode()}")
client.close()
