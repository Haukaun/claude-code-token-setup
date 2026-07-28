# Usage & cost notes

## The cost model

Three levers cut token cost in Claude Code; this setup pulls all of them. The
third — **rtk** — is independent of the other two: it shrinks *shell output*
rather than *how the model works*, so it stacks on top.

1. **Per-agent model routing.** Each subagent pins its own `model:` in
   frontmatter. Grunt work runs on Haiku; only judgment/tracing runs on Sonnet.

   | Agent | Model | Why |
   |---|---|---|
   | `cavecrew-investigator` | haiku | High-volume locate work; cheapest tier |
   | `cavecrew-builder` | haiku | Mechanical 1-2 file edits |
   | `cavecrew-reviewer` | sonnet | Needs judgment on correctness |
   | `cavecrew-investigator-deep` | sonnet | Cross-module tracing; spawned rarely |

2. **Context isolation + compression.** Subagents run in their own context and
   return a caveman-compressed receipt. Your main thread — the priciest model,
   re-sent every turn — stays lean, so it processes far fewer tokens.

3. **Shell-output compression (rtk).** [rtk](https://github.com/rtk-ai/rtk) is a
   CLI proxy that understands 100+ dev commands and strips the noise from their
   output — spinners, green "ok" lines, giant trees — before it ever reaches the
   context (60–90% less on average). `rtk init -g` installs a hook that rewrites
   Bash commands to their rtk equivalents transparently, so every command and
   every subagent benefits with no per-command effort. This is orthogonal to the
   agent-routing lever: routing decides *which model* reads the output; rtk
   decides *how much* output there is to read.

**The savings only materialize if the main thread delegates.** If the main model
does all the grepping and editing itself, model routing buys nothing. Two ways
to make delegation happen:

- **Automatic:** the orchestrator picks an agent by its `description`. The
  descriptions are tuned so "where is X / what calls Y" routes to the
  investigator and "fix this typo / rename this" routes to the builder.
- **Explicit:** tell it — "use cavecrew-investigator to find the callers of
  `foo`", "have cavecrew-builder fix the off-by-one in `bar.ts`".

## Recommended main-model posture

The installer sets `"model": "opusplan"` in `~/.claude/settings.json`, which
picks the right model automatically:

- **Plan mode → Opus.** Genuinely hard reasoning (architecture, tricky
  debugging) runs on the strongest model, but only while you're planning.
- **Everything else → Sonnet.** Routine execution runs on Sonnet, with the
  Haiku subagents doing the heavy lifting under it.

This is shared by the Claude Code CLI and the desktop app (same settings file),
so both follow the same posture. You can still override per-session with
`/model` — but with `opusplan` you rarely need to. Delegate exploration to the
cheap agents regardless of which model the main thread is on.

## graphify is the context path — not grep

All three read agents (`investigator`, `investigator-deep`, `reviewer`) query
the graphify knowledge graph **before** grepping. When `graphify-out/graph.json`
exists, the graph answers "where / what calls / how does X reach Y" without
loading files into context — the single biggest per-query token saver.

Keep the graph fresh so the agents can rely on it:

```
/graphify            # build (first run)
/graphify --update   # after adding or changing files
```

If the graph is stale or missing, the agents say so and fall back to grep — but
you lose the cheap path. Building the graph once per repo pays for itself fast.

## How the agents relate to your existing setup

| Need | Use |
|---|---|
| Brainstorm a feature | superpowers `brainstorming` skill |
| Write an implementation plan | superpowers `writing-plans` + built-in Plan agent |
| Locate code / trace architecture | `cavecrew-investigator` → escalates to `-deep` |
| Small surgical edit | `cavecrew-builder` |
| Review a diff | `cavecrew-reviewer` (or `/code-review`) |
| Keep code lazy/minimal | ponytail (active globally) |
| Cut filler from output | caveman / i-have-adhd |
| Cut shell-output tokens | rtk (transparent Bash hook) |
| Monitor context / tools live | claude-hud statusline |
| Find or build a skill | find-skills / skill-creator |
| Drive a real browser | agent-browser |

No dedicated planner/brainstorm agents ship here — superpowers already covers
those, and duplicating them would be maintenance cost for no gain.
