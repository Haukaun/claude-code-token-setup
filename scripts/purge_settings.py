#!/usr/bin/env python3
"""Revert this repo's user-level settings.json bits in ~/.claude/settings.json:

  - Remove the graphify-hint hook (identified by the 'graphify-out' marker).
  - Remove the security-guard hook (identified by the 'security_guard' marker).
  - Remove "model" only if it still equals our installed value ("opusplan"),
    so a user's own explicit choice is never touched.

Leaves every other setting untouched. Idempotent: a no-op if none are present.
"""
import json
from pathlib import Path

MARKER = "graphify-out"
GUARD_MARKER = "security_guard"
MODEL = "opusplan"
SETTINGS = Path.home() / ".claude" / "settings.json"


def strip_hook(data, event, marker):
    """Drop entries under hooks[event] whose command carries `marker`."""
    entries = data.get("hooks", {}).get(event)
    if not entries:
        return False
    kept = [
        e for e in entries
        if not any(marker in h.get("command", "") for h in e.get("hooks", []))
    ]
    if len(kept) == len(entries):
        return False
    if kept:
        data["hooks"][event] = kept
    else:
        data["hooks"].pop(event)
        if not data["hooks"]:
            data.pop("hooks")
    return True


def main():
    if not SETTINGS.exists():
        print("no settings.json — nothing to purge")
        return
    data = json.loads(SETTINGS.read_text())
    changed = False

    if strip_hook(data, "UserPromptSubmit", MARKER):
        changed = True
        print("removed graphify hook")
    if strip_hook(data, "PreToolUse", GUARD_MARKER):
        changed = True
        print("removed security-guard hook")

    if data.get("model") == MODEL:
        data.pop("model")
        changed = True
        print(f'removed "model": "{MODEL}"')

    if not changed:
        print("nothing to purge")
        return
    SETTINGS.write_text(json.dumps(data, indent=2) + "\n")
    print(f"wrote {SETTINGS}")


if __name__ == "__main__":
    main()
