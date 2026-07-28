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

**Skills** — [graphify](https://github.com/Haukaun) knowledge graph, installed via its own CLI.

**Hooks** — a graphify-first `UserPromptSubmit` hint, merged into `~/.claude/settings.json` only in projects that have a `graphify-out/` (a fast no-op elsewhere).

Planning/brainstorming agents are intentionally **not** shipped — superpowers already covers them, and Claude Code has a built-in Plan agent.

## Prerequisites

- [Claude Code](https://claude.com/claude-code) (the `claude` CLI on `PATH`)
- [`just`](https://just.systems) — `brew install just` / `winget install Casey.Just`
- [`uv`](https://astral.sh/uv) — for the graphify install
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
just mac-install-plugins    # superpowers + ponytail
just mac-install-graphify   # graphify CLI + skill
just mac-install-hooks      # graphify hint hook (idempotent, non-clobbering)
```

`just --list` shows every recipe (each has a `win-` twin).

## Uninstall

```sh
just mac-uninstall-all       # removes agents, plugins, graphify, hook
```

The hook uninstall removes **only** this repo's hook (matched by a `graphify-out` marker) and leaves the rest of your `settings.json` untouched.

## Usage & cost model

See [`docs/usage.md`](docs/usage.md). Short version: savings come from the main thread **delegating** to the cheap agents — automatically via their descriptions, or explicitly ("use cavecrew-investigator to …") — and from keeping the **graphify** graph fresh (`/graphify --update`) so context lookups hit the graph instead of loading files.
