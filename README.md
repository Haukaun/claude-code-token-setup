# claude-code-token-setup

A batteries-included, token-efficient [Claude Code](https://claude.com/claude-code) setup — the Claude Code counterpart of [`opencode-token-setup`](https://github.com/Haukaun/opencode-token-setup). Clone it and one command reproduces the whole thing on a fresh machine: subagents, plugins, the graphify knowledge graph, and hooks.

The core idea: route grunt work (locate, edit) to **Haiku** and reserve **Sonnet** for judgment, with every subagent returning caveman-compressed output so the main thread stays cheap. All read agents query the **graphify** graph before touching files.

## What's included

**CaveCrew subagents** (`agents/`, copied to `~/.claude/agents/`):

| Agent | Model | Job |
|---|---|---|
| `cavecrew-investigator` | haiku | Read-only code locator. graphify-first. Compressed `path:line` table. Escalates when ambiguous. |
| `cavecrew-builder` | haiku | Surgical 1-2 file edits. Refuses 3+ files. No shell/push/delete. Returns a diff receipt. |
| `cavecrew-reviewer` | sonnet | Diff/branch review. One line per finding, severity-tagged. |
| `cavecrew-investigator-deep` | sonnet | Cross-module tracing. Spawned only when the investigator escalates. |

**Plugins** (installed from their marketplaces via `claude plugin`; their hooks, commands, and skills come bundled):

- [superpowers](https://github.com/obra/superpowers-marketplace) — brainstorming, writing-plans, TDD, debugging, code-review skills.
- [ponytail](https://github.com/DietrichGebert/ponytail) — lazy-code discipline (YAGNI, stdlib-first).
- [caveman](https://github.com/JuliusBrussee/caveman) — caveman-compresses output, cutting filler tokens.
- [i-have-adhd](https://github.com/ayghri/i-have-adhd) — answer-first, no-burying output style.
- [claude-hud](https://github.com/jarrodwatts/claude-hud) — real-time statusline HUD: context health, tool activity, agent + todo tracking.

**Skills** — [graphify](https://github.com/Haukaun) knowledge graph (own CLI), plus skills installed via the [`npx skills`](https://github.com/vercel-labs/skills) CLI into `~/.claude/skills`:

- [find-skills](https://github.com/mgiovani/cc-arsenal) — discovers and installs the right skill for a task.
- [agent-browser](https://github.com/mgiovani/cc-arsenal) — lets Claude drive a real browser to use any website.
- [skill-creator](https://github.com/anthropics/skills) — Anthropic's own skill for building your own skills.

**rtk** — [rtk-ai/rtk](https://github.com/rtk-ai/rtk), the Rust "token killer": a CLI proxy that compresses shell-command output (60–90% less noise) before it reaches the context. `rtk init -g` installs a transparent hook that rewrites Bash commands automatically.

**Hooks & settings** — merged into `~/.claude/settings.json` (non-clobbering):

- a graphify-first `UserPromptSubmit` hint (active only in projects that have a `graphify-out/`, a fast no-op elsewhere);
- a **security guard** `PreToolUse` hook (`scripts/security_guard.py`, installed to `~/.claude/hooks/`) that inspects every Bash command and **blocks catastrophic ones** (`rm -rf /`, fork bombs, disk wipes, reverse shells, history wiping) while **forcing a confirm on risky-but-legit ones** (`curl … | sh`, `git push --force`, `git reset --hard`, `sudo`, reading secret files, committing staged secrets);
- `"model": "opusplan"` — **Opus while in plan mode, Sonnet for execution**. Since the CLI and desktop app share this file, the model setting applies to both.

(rtk manages its own hook via `rtk init -g`.)

Planning/brainstorming agents are intentionally **not** shipped — superpowers already covers them, and Claude Code has a built-in Plan agent.

## Prerequisites

- [Claude Code](https://claude.com/claude-code) (the `claude` CLI on `PATH`)
- [`just`](https://just.systems) — `brew install just` / `winget install Casey.Just`
- [`uv`](https://astral.sh/uv) — for the graphify install
- Node / `npx` — for the `npx skills` CLI (find-skills, agent-browser, skill-creator)
- [`rtk`](https://github.com/rtk-ai/rtk) — `brew install rtk` (the `mac-install-rtk` recipe does this for you)
- `python3` — for the settings-hook merge (standard on macOS/Linux)

## Install

```sh
git clone <this-repo>
cd claude-code-token-setup

# macOS / Linux
just mac-install-all

# Windows (PowerShell)
just win-install-all
```

Restart Claude Code afterward to load the new agents, plugins, and hooks.

Install piece by piece if you prefer:

```sh
just mac-install-agents     # CaveCrew subagents only
just mac-install-plugins    # superpowers + ponytail + caveman + i-have-adhd + claude-hud
just mac-install-skills     # find-skills, agent-browser, skill-creator (npx skills)
just mac-install-graphify   # graphify CLI + skill
just mac-install-rtk        # rtk binary + transparent Bash-rewrite hook
just mac-install-hooks      # graphify hint hook (idempotent, non-clobbering)
```

`just --list` shows every recipe (each has a `win-` twin).

## Uninstall

```sh
just mac-uninstall-all       # removes everything this repo installed
```

`mac-uninstall-all` reverses the whole setup and tidies up after it:

- **agents / skills** — removes the CaveCrew agent files and the `npx skills` dirs, then prunes the now-empty `~/.claude/{agents,skills,hooks}` dirs.
- **plugins** — uninstalls the four plugins + their marketplaces, and clears ponytail's leftover state markers.
- **rtk** — removes the hook, the binary (if brew-managed), and rtk's config (`~/.config/rtk`).
- **settings** — strips only *this repo's* hooks (matched by the `graphify-out` / `security_guard` markers) and reverts `model` only if it's still `opusplan`; everything else in `settings.json` is left untouched.

It deliberately does **not** touch things it didn't create — your `~/.claude/cache/`, other plugins' caches, or any Obsidian vault. graphify's per-project `graphify-out/` is also left in place (delete it manually, or `graphify uninstall --purge`).

## Security guard

The `PreToolUse` hook (`scripts/security_guard.py`) is a **seatbelt for the Bash tool** — it runs before every command Claude Code tries to execute and returns one of:

- **deny** (hard block): `rm -rf /` `~` `$HOME` and top-level dirs, fork bombs, `dd`/`mkfs` on raw devices, reverse shells (`/dev/tcp`, `nc -e`), recursive `chmod 777 /`, shell-history wiping, and commits whose staged diff looks like it contains a secret (AWS/Google/GitHub/Slack keys, private keys).
- **ask** (force a confirm): `curl … | sh`, `git push --force`, `git reset --hard`, `git clean -f`, `sudo`, partition tools, reading credential files (`~/.ssh/id_*`, `.env`, `~/.aws/credentials`, …), writing shell rc / Claude settings, broad `kill -9`, global package installs, and `rm -rf *` / `.`.
- **pass**: everything else flows through normal permission handling.

Its real value is protecting you **even in auto-accept mode and inside subagents**, where the usual permission prompt is relaxed.

**Honest limits:** it matches command *text*, so obfuscation (base64, variables, aliases) can slip past — it's an accident-stopper, not a defense against a determined adversary. It **fails open** (any parse error → allow) so a bug never bricks your shell, and it only covers the Bash tool. Tune the `DENY_PATTERNS` / `ASK_PATTERNS` lists in the script to taste.

## Obsidian (manual)

Connecting Claude Code to an [Obsidian](https://obsidian.md) vault is **not automated** — the vault path (and, for the REST route, an API key) are machine-specific, so wire it up yourself with an MCP server. Two options:

**A. Filesystem MCP over the vault** (simplest — no Obsidian plugin needed). Point a filesystem MCP server at your vault folder so Claude can read/write notes as `.md` files:

```jsonc
// ~/.claude.json (or project .mcp.json) — under "mcpServers"
"obsidian": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-filesystem", "<YOUR_VAULT_PATH>"]
}
```

**B. Local REST API MCP** (Obsidian-aware — search, backlinks, live edits). Install Obsidian's **Local REST API** community plugin, copy its API key, then add an obsidian MCP server:

```jsonc
"obsidian": {
  "command": "npx",
  "args": ["-y", "obsidian-mcp-server"],
  "env": { "OBSIDIAN_API_KEY": "<YOUR_API_KEY>", "OBSIDIAN_BASE_URL": "https://127.0.0.1:27124" }
}
```

Replace the placeholders and restart Claude Code. Because graphify and the memory system both use `[[wikilinks]]`, notes written into the vault show up in Obsidian's own graph view.

## Usage & cost model

See [`docs/usage.md`](docs/usage.md). Short version: savings come from the main thread **delegating** to the cheap agents — automatically via their descriptions, or explicitly ("use cavecrew-investigator to …") — and from keeping the **graphify** graph fresh (`/graphify --update`) so context lookups hit the graph instead of loading files.
