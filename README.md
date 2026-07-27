# claude-code-token-setup

Token-efficient CaveCrew subagents for [Claude Code](https://claude.com/claude-code) — the Claude Code counterpart of [`opencode-token-setup`](https://github.com/Haukaun/opencode-token-setup).

Four specialized subagents route grunt work (locate, edit) to **Haiku** and reserve **Sonnet** for judgment, each returning caveman-compressed output so your main thread stays cheap. All read agents query the **graphify** knowledge graph before touching files.

## What's included

| Agent | Model | Job |
|---|---|---|
| `cavecrew-investigator` | haiku | Read-only code locator. graphify-first. Compressed `path:line` table. Escalates when ambiguous. |
| `cavecrew-builder` | haiku | Surgical 1-2 file edits. Refuses 3+ files. No shell/push/delete. Returns a diff receipt. |
| `cavecrew-reviewer` | sonnet | Diff/branch review. One line per finding, severity-tagged. |
| `cavecrew-investigator-deep` | sonnet | Cross-module tracing. Spawned only when the investigator escalates. |

Planning and brainstorming are intentionally **not** included — the [superpowers](https://github.com/obra/superpowers-marketplace) plugin already ships `brainstorming` + `writing-plans`, and Claude Code has a built-in Plan agent.

## Prerequisites

- [Claude Code](https://claude.com/claude-code)
- [`just`](https://just.systems) (`brew install just` / `winget install Casey.Just`)
- [graphify](https://github.com/Haukaun/opencode-token-setup) CLI on `PATH` (the agents call `graphify query/path/explain`; without it they fall back to grep)

## Install

```sh
git clone <this-repo>
cd claude-code-token-setup

# macOS / Linux
just mac-install

# Windows (PowerShell)
just win-install
```

Install copies `agents/*.md` into `~/.claude/agents/`. Restart Claude Code to pick them up. There is no config merging — Claude Code loads agent `.md` files directly.

## Uninstall

```sh
just mac-uninstall   # or: just win-uninstall
```

## Usage & cost model

See [`docs/usage.md`](docs/usage.md). The short version: the savings come from the main thread **delegating** to the cheap agents (either automatically via their descriptions, or explicitly — "use cavecrew-investigator to …"), and from keeping the **graphify** graph fresh (`/graphify --update`) so context lookups hit the graph instead of loading files.

## Relation to your global setup

Complements, doesn't replace: **superpowers** (brainstorm/plan/TDD/debug/review skills), **ponytail** (lazy-code discipline), **graphify** (knowledge graph). These agents just add a cheap, compressed locate/edit/review tier on top.
