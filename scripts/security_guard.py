#!/usr/bin/env python3
"""PreToolUse security guard for Claude Code's Bash tool.

Reads the tool call as JSON on stdin and either blocks it ("deny") or forces a
confirmation ("ask") when the command matches a dangerous pattern. Anything that
doesn't match is passed through untouched (exit 0, no output) so normal
permission handling still applies.

Design notes / limits:
  * This matches command TEXT. It stops catastrophic accidents; it is NOT a
    defense against a determined adversary (obfuscation, base64, aliases, env
    indirection can slip past). Treat it as a seatbelt, not a firewall.
  * It fails OPEN: any parsing error or unexpected input exits 0 (allow), so a
    bug here never bricks your shell.
  * It only inspects the Bash tool. Reads via the Read/Grep tools are not
    covered (that content stays in Claude's context anyway).

Tiers (all enabled):
  1. DENY  — catastrophic, ~zero false positives.
  2. ASK   — risky but sometimes legit; forces a confirm.
  3. ASK/DENY — opinionated extras (staged-secret commit scan, broad kills,
     global installs).
"""
import json
import re
import subprocess
import sys


# ---------------------------------------------------------------------------
# Tier 1 — hard DENY (regex, reason). Case-insensitive.
# ---------------------------------------------------------------------------
DENY_PATTERNS = [
    # Fork bomb (classic and near variants).
    (r":\s*\(\s*\)\s*\{.*\|\s*:\s*&", "fork bomb"),
    (r"\|\s*:\s*&\s*\}\s*;\s*:", "fork bomb"),
    # Disk / device destroyers.
    (r"\bdd\b[^\n]*\bof=/dev/(sd|nvme|disk|hd|mmcblk|vd|rdisk)", "dd writing to a raw disk device"),
    (r"\bmkfs(\.\w+)?\b", "mkfs (formatting a filesystem)"),
    (r">\s*/dev/(sd|nvme|disk|hd|mmcblk|vd|rdisk)", "redirect onto a raw disk device"),
    # Reverse / bind shells.
    (r">&?\s*/dev/(tcp|udp)/", "reverse shell via /dev/tcp"),
    (r"\bnc\b[^\n]*\s-e\b", "netcat with -e (reverse shell)"),
    (r"\bncat\b[^\n]*--exec\b", "ncat --exec (reverse shell)"),
    (r"\b(bash|sh|zsh)\b\s+-i\b[^\n]*(/dev/tcp|>&)", "interactive shell piped to a socket"),
    # Recursive permission / ownership nukes on system roots.
    (r"\bchmod\b\s+-R?\s*[0-7]*7{2,3}\s+/(?:\s|$)", "chmod -R 777 on /"),
    (r"\bchmod\b\s+-R\b[^\n]*\s(/|/etc|/usr|/bin|/System|~|\$\{?HOME\}?)(\s|$|/)", "recursive chmod on a system path"),
    (r"\bchown\b\s+-R\b[^\n]*\s(/|/etc|/usr|/bin|/System)(\s|$|/)", "recursive chown on a system path"),
    # History / detection-evasion wiping.
    (r"\bhistory\b\s+-c\b", "clearing shell history"),
    (r"\bunset\s+HISTFILE\b", "disabling shell history"),
    (r"\brm\b[^\n]*\.(bash|zsh|sh)_history", "deleting shell history"),
    (r">\s*~?/?\.(bash|zsh|sh)_history\b", "truncating shell history"),
    (r"\bshred\b", "shred (unrecoverable wipe)"),
]

# ---------------------------------------------------------------------------
# Tier 2/3 — ASK (force a confirm).
# ---------------------------------------------------------------------------
ASK_PATTERNS = [
    # Pipe-to-shell from the internet.
    (r"\b(curl|wget)\b[^|\n]*\|\s*(sudo\s+)?(sh|bash|zsh)\b", "piping a downloaded script straight into a shell"),
    # Git data-loss / history rewrites.
    (r"\bgit\b[^\n]*\bpush\b[^\n]*(--force(?!-with-lease)|\s-f\b)", "git force push"),
    (r"\bgit\b[^\n]*\breset\b[^\n]*--hard\b", "git reset --hard (discards changes)"),
    (r"\bgit\b[^\n]*\bclean\b[^\n]*-[a-eg-z]*f", "git clean -f (deletes untracked files)"),
    (r"\bgit\b\s+checkout\s+\.\s*$", "git checkout . (discards working changes)"),
    (r"\bgit\b\s+restore\s+\.", "git restore . (discards working changes)"),
    # Privilege escalation.
    (r"\bsudo\b", "sudo (privilege escalation)"),
    # Disk-partition tools.
    (r"\b(fdisk|parted|gdisk|sgdisk)\b", "a disk-partitioning tool"),
    # Reading credential/secret files.
    (r"\b(cat|less|more|head|tail|cp|scp|rsync|base64|xxd|tar|zip|nc)\b[^\n]*"
     r"(\.ssh/id_|id_rsa|id_ed25519|\.aws/credentials|\.env(\b|\.)|\.pem\b|\.p12\b|"
     r"\.npmrc|\.pypirc|\.docker/config\.json|\.kube/config|\.claude/settings)",
     "reading a credential/secret file"),
    # Clobbering shell / tool config.
    (r">>?\s*~?/?\.(zshrc|bashrc|bash_profile|profile|zprofile)\b", "writing to a shell rc file"),
    (r">>?\s*[^\n]*\.claude/settings", "writing to Claude Code settings"),
    # Broad process kills.
    (r"\bkill\b\s+-(9|KILL)\s+-1\b", "kill -9 -1 (kills all your processes)"),
    (r"\bpkill\b\s+-(9|KILL)\b", "pkill -9"),
    (r"\bkillall\b\s+-(9|KILL)\b", "killall -9"),
    # Global package installs.
    (r"\bnpm\b\s+(i|install|add)\b[^\n]*\s-g\b", "global npm install"),
    (r"\b(yarn\s+global\s+add|pnpm\s+add\s+-g)\b", "global package install"),
    (r"\bsudo\s+(pip3?|pip)\s+install\b", "sudo pip install"),
]

# Secret shapes scanned in staged diffs before a commit (Tier 3).
SECRET_PATTERNS = [
    (r"AKIA[0-9A-Z]{16}", "AWS access key"),
    (r"-----BEGIN [A-Z ]*PRIVATE KEY-----", "private key"),
    (r"xox[baprs]-[A-Za-z0-9-]{10,}", "Slack token"),
    (r"AIza[0-9A-Za-z_\-]{35}", "Google API key"),
    (r"gh[pousr]_[A-Za-z0-9]{30,}", "GitHub token"),
    (r"(?i)(api[_-]?key|secret|token|password|access[_-]?key)"
     r"[\"']?\s*[:=]\s*[\"']?[A-Za-z0-9_\-/+]{16,}", "hardcoded secret assignment"),
]

# rm targets: system-fatal → deny; cwd-wipe → ask.
_RM_DENY_EXACT = {"/", "/*", "~", "~/", "$HOME", "${HOME}", "$HOME/", "${HOME}/",
                  "~/*", "$HOME/*", "${HOME}/*"}
_RM_ASK_EXACT = {".", "./", "..", "../", "*"}


def _decision(decision, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": f"security-guard: {reason}",
    }}))
    sys.exit(0)


def _rm_target_severity(op):
    o = op.strip().strip("\"'")
    if o in _RM_DENY_EXACT:
        return "deny"
    if o in _RM_ASK_EXACT:
        return "ask"
    # Absolute single-level dir (e.g. /etc, /usr, /Users, optional trailing /*).
    if re.fullmatch(r"/[A-Za-z0-9._-]+/?\*?", o):
        return "deny"
    # ~ or $HOME with a trailing wildcard.
    if re.fullmatch(r"(~|\$\{?HOME\}?)/\*?", o):
        return "deny"
    return None


def check_rm(cmd):
    """Return ('deny'|'ask', reason) for a dangerous rm, else None."""
    worst = None
    for seg in re.split(r"[;&|]+|\s&&\s|\s\|\|\s", cmd):
        tokens = seg.strip().split()
        idx = next((i for i, t in enumerate(tokens)
                    if t.split("/")[-1] == "rm"), None)
        if idx is None:
            continue
        flags, operands, end_opts = "", [], False
        for t in tokens[idx + 1:]:
            if t == "--":
                end_opts = True
            elif not end_opts and t.startswith("--"):
                flags += {"--recursive": "r", "--force": "f"}.get(t, "")
            elif not end_opts and t.startswith("-") and len(t) > 1:
                flags += t[1:]
            else:
                operands.append(t)
        if "r" not in flags.lower():
            continue  # non-recursive rm is not catastrophic
        for op in operands:
            sev = _rm_target_severity(op)
            if sev == "deny":
                return "deny", f"rm -r targeting {op!r}"
            if sev == "ask":
                worst = worst or ("ask", f"rm -r targeting {op!r}")
    return worst


def check_commit_secrets(cmd):
    """If this is a git commit, scan the staged diff for secrets (Tier 3)."""
    if not re.search(r"\bgit\b[^\n]*\bcommit\b", cmd):
        return None
    try:
        diff = subprocess.run(
            ["git", "diff", "--cached", "-U0"],
            capture_output=True, text=True, timeout=5,
        ).stdout[:200_000]
    except Exception:
        return None  # not a repo / git missing → fail open
    for pat, label in SECRET_PATTERNS:
        if re.search(pat, diff):
            return f"staged changes look like they contain a {label}"
    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # unparseable → fail open

    if payload.get("tool_name") != "Bash":
        sys.exit(0)
    cmd = (payload.get("tool_input") or {}).get("command", "")
    if not cmd:
        sys.exit(0)

    # rm first (structured check).
    rm = check_rm(cmd)
    if rm and rm[0] == "deny":
        _decision("deny", f"blocked catastrophic delete — {rm[1]}")

    # Tier 1 hard blocks.
    for pat, reason in DENY_PATTERNS:
        if re.search(pat, cmd, re.IGNORECASE):
            _decision("deny", f"blocked — {reason}")

    # Tier 3 staged-secret commit scan (block).
    secret = check_commit_secrets(cmd)
    if secret:
        _decision("deny", f"blocked commit — {secret}")

    # Ask tier (rm cwd-wipe + Tier 2/3 patterns).
    if rm and rm[0] == "ask":
        _decision("ask", f"confirm — {rm[1]}")
    for pat, reason in ASK_PATTERNS:
        if re.search(pat, cmd, re.IGNORECASE):
            _decision("ask", f"confirm — {reason}")

    sys.exit(0)  # no match → normal handling


if __name__ == "__main__":
    main()
