#!/usr/bin/env python3
"""Verify public endpoints after terraform apply (no SSH)."""
import sys
import time
import urllib.request

BASE = sys.argv[1].rstrip("/")
HEADERS = {"ngrok-skip-browser-warning": "1", "User-Agent": "pmm-agentic-flow-verify/1.0"}


def get(path: str) -> tuple[int, str]:
    req = urllib.request.Request(f"{BASE}{path}", headers=HEADERS)
    with urllib.request.urlopen(req, timeout=25) as resp:
        return resp.status, resp.read(8000).decode(errors="replace")


def main() -> int:
    print(f"Polling {BASE} (up to 15 min)...")
    for i in range(45):
        try:
            orch_status, orch_body = get("/orchestrator/health")
            ui_status, ui_body = get("/")
            print(f"  attempt {i + 1}: orchestrator={orch_status} ui={ui_status}")
            if orch_status == 200 and '"ok"' in orch_body:
                if ui_status == 200 and "Cannot GET /" not in ui_body and len(ui_body) > 200:
                    print("\nOK orchestrator:", orch_body.strip()[:120])
                    print("OK canvas UI: HTML", len(ui_body), "bytes")
                    return 0
        except Exception as exc:
            print(f"  attempt {i + 1}: {exc}")
        time.sleep(20)
    print("\nFAILED: endpoints not ready", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
