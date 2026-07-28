#!/usr/bin/env python3
"""Merge this repo's user-level settings.json bits into ~/.claude/settings.json
without clobbering existing settings:

  1. The graphify-hint UserPromptSubmit hook (identified by the 'graphify-out'
     marker in its command, so re-running is a no-op).
  2. The security-guard PreToolUse hook (identified by the 'security_guard'
     marker). The referenced script is copied to ~/.claude/hooks/ by the
     install recipe before this runs.
  3. "model": "opusplan" — Opus while in plan mode, Sonnet for everything else.
     Only set when absent, so an explicit user choice is never overwritten.
     (settings.json is shared by the Claude Code CLI and the desktop app, so
     this applies to both.)

Plugin hooks/commands/skills are NOT handled here — they come bundled with each
plugin and are installed by `claude plugin install`.
"""
import json
from pathlib import Path

MARKER = "graphify-out"
GUARD_MARKER = "security_guard"
MODEL = "opusplan"
SETTINGS = Path.home() / ".claude" / "settings.json"
HOOKS_DIR = Path(__file__).resolve().parent.parent / "hooks"
HOOK_FRAGMENT = HOOKS_DIR / "graphify-hint.json"
GUARD_FRAGMENT = HOOKS_DIR / "security-guard.json"


def load_fragment(path):
    frag = json.loads(path.read_text())
    return {k: v for k, v in frag.items() if not k.startswith("_")}


def has_marker(entries, marker):
    return any(
        marker in h.get("command", "")
        for entry in entries
        for h in entry.get("hooks", [])
    )


def main():
    data = json.loads(SETTINGS.read_text()) if SETTINGS.exists() else {}
    changed = False

    ups = data.setdefault("hooks", {}).setdefault("UserPromptSubmit", [])
    if has_marker(ups, MARKER):
        print("graphify hook already present — no change")
    else:
        ups.append(load_fragment(HOOK_FRAGMENT))
        changed = True
        print("merged graphify hook")

    pre = data["hooks"].setdefault("PreToolUse", [])
    if has_marker(pre, GUARD_MARKER):
        print("security-guard hook already present — no change")
    else:
        pre.append(load_fragment(GUARD_FRAGMENT))
        changed = True
        print("merged security-guard hook")

    existing_model = data.get("model")
    if existing_model is None:
        data["model"] = MODEL
        changed = True
        print(f'set "model": "{MODEL}"')
    elif existing_model != MODEL:
        print(f'model already set to "{existing_model}" — left as-is '
              f'(set it to "{MODEL}" for Opus-plan / Sonnet-execute)')

    if not changed:
        return
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    SETTINGS.write_text(json.dumps(data, indent=2) + "\n")
    print(f"wrote {SETTINGS}")


if __name__ == "__main__":
    main()
