#!/usr/bin/env python3
"""Remove the graphify-hint hook (identified by the 'graphify-out' marker) from
~/.claude/settings.json. Leaves every other setting and hook untouched.
Idempotent: a no-op if the hook isn't there.
"""
import json
from pathlib import Path

MARKER = "graphify-out"
SETTINGS = Path.home() / ".claude" / "settings.json"


def main():
    if not SETTINGS.exists():
        print("no settings.json — nothing to purge")
        return
    data = json.loads(SETTINGS.read_text())
    ups = data.get("hooks", {}).get("UserPromptSubmit")
    if not ups:
        print("no UserPromptSubmit hooks — nothing to purge")
        return
    kept = [
        e for e in ups
        if not any(MARKER in h.get("command", "") for h in e.get("hooks", []))
    ]
    if len(kept) == len(ups):
        print("graphify hook not found — nothing to purge")
        return
    if kept:
        data["hooks"]["UserPromptSubmit"] = kept
    else:
        data["hooks"].pop("UserPromptSubmit")
        if not data["hooks"]:
            data.pop("hooks")
    SETTINGS.write_text(json.dumps(data, indent=2) + "\n")
    print(f"removed graphify hook from {SETTINGS}")


if __name__ == "__main__":
    main()
