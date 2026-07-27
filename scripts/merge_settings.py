#!/usr/bin/env python3
"""Merge hooks/graphify-hint.json into ~/.claude/settings.json without clobbering
existing settings. Idempotent: our hook is identified by the 'graphify-out'
marker in its command, so re-running is a no-op.

Plugin hooks/commands/skills are NOT handled here — they come bundled with each
plugin and are installed by `claude plugin install`. This script only reproduces
the one user-level hook that lives directly in settings.json.
"""
import json
from pathlib import Path

MARKER = "graphify-out"
SETTINGS = Path.home() / ".claude" / "settings.json"
HOOK_FRAGMENT = Path(__file__).resolve().parent.parent / "hooks" / "graphify-hint.json"


def load_hook():
    frag = json.loads(HOOK_FRAGMENT.read_text())
    return {k: v for k, v in frag.items() if not k.startswith("_")}


def already_present(ups):
    return any(
        MARKER in h.get("command", "")
        for entry in ups
        for h in entry.get("hooks", [])
    )


def main():
    data = json.loads(SETTINGS.read_text()) if SETTINGS.exists() else {}
    ups = data.setdefault("hooks", {}).setdefault("UserPromptSubmit", [])
    if already_present(ups):
        print("graphify hook already present — no change")
        return
    ups.append(load_hook())
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    SETTINGS.write_text(json.dumps(data, indent=2) + "\n")
    print(f"merged graphify hook into {SETTINGS}")


if __name__ == "__main__":
    main()
