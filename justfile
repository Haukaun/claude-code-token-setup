# claude-code-token-setup — install/uninstall the full setup:
#   agents  → copied into ~/.claude/agents/
#   plugins → installed from their marketplaces via `claude plugin`
#   skills  → graphify installed via its own CLI; plugin skills come with plugins
#   hooks   → graphify hint merged into ~/.claude/settings.json (plugin hooks
#             come with plugins); commands also ship inside their plugins
#
# headroom is intentionally NOT part of *-install-all: it pulls a ~2GB PyPI
# stack (torch/ML) and is a CLI-only proxy. Opt in with `just mac-install-headroom`.

agents_dir := "agents"

# Default: show recipes.
default:
    @just --list

# =====================================================================
# macOS / Linux
# =====================================================================

# Everything except headroom (agents + plugins + graphify + hooks).
mac-install-all: mac-install-plugins mac-install-graphify mac-install-agents mac-install-hooks
    @echo "Done. Restart Claude Code to load agents, plugins, and hooks."

# CaveCrew subagents → ~/.claude/agents/
mac-install-agents:
    mkdir -p ~/.claude/agents
    cp {{agents_dir}}/*.md ~/.claude/agents/
    @echo "Installed CaveCrew agents."

# superpowers + ponytail from their marketplaces.
mac-install-plugins:
    claude plugin marketplace add obra/superpowers-marketplace || true
    claude plugin marketplace add DietrichGebert/ponytail || true
    claude plugin install superpowers
    claude plugin install ponytail
    @echo "Installed plugins (their hooks/commands/skills come bundled)."

# graphify CLI + skill (knowledge graph). Requires uv (https://astral.sh/uv).
mac-install-graphify:
    uv tool install graphifyy || pip install graphifyy
    graphify install --platform claude
    @echo "Installed graphify CLI + skill."

# graphify hint hook → ~/.claude/settings.json (idempotent, non-clobbering).
mac-install-hooks:
    python3 scripts/merge_settings.py

# Optional, heavy (~2GB): headroom context-compression proxy.
mac-install-headroom:
    claude plugin marketplace add chopratejas/headroom || true
    claude plugin install headroom
    uv tool install "headroom-ai[all]" || pip install "headroom-ai[all]"
    @echo "Installed headroom. It is CLI-only — run `headroom doctor`, then `headroom wrap claude`."

# --- uninstalls ---

mac-uninstall-all: mac-uninstall-hooks mac-uninstall-agents mac-uninstall-graphify mac-uninstall-plugins
    @echo "Removed setup (headroom untouched — use mac-uninstall-headroom)."

mac-uninstall-agents:
    rm -f ~/.claude/agents/cavecrew-investigator.md \
          ~/.claude/agents/cavecrew-builder.md \
          ~/.claude/agents/cavecrew-reviewer.md \
          ~/.claude/agents/cavecrew-investigator-deep.md
    @echo "Removed CaveCrew agents."

mac-uninstall-plugins:
    claude plugin uninstall superpowers || true
    claude plugin uninstall ponytail || true
    claude plugin marketplace remove superpowers-marketplace || true
    claude plugin marketplace remove ponytail || true
    @echo "Removed plugins + marketplaces."

mac-uninstall-graphify:
    graphify uninstall || true
    @echo "Removed graphify (all platforms). Add --purge manually to delete graphify-out/."

mac-uninstall-hooks:
    python3 scripts/purge_settings.py

mac-uninstall-headroom:
    claude plugin uninstall headroom || true
    claude plugin marketplace remove headroom-marketplace || true
    uv tool uninstall headroom-ai || true
    @echo "Removed headroom."

# =====================================================================
# Windows (PowerShell)
# =====================================================================

win-install-all: win-install-plugins win-install-graphify win-install-agents win-install-hooks
    @echo "Done. Restart Claude Code."

win-install-agents:
    powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path $env:USERPROFILE\.claude\agents | Out-Null; Copy-Item {{agents_dir}}\*.md $env:USERPROFILE\.claude\agents\ -Force; Write-Host 'Installed CaveCrew agents.'"

win-install-plugins:
    -claude plugin marketplace add obra/superpowers-marketplace
    -claude plugin marketplace add DietrichGebert/ponytail
    claude plugin install superpowers
    claude plugin install ponytail

win-install-graphify:
    powershell -NoProfile -Command "uv tool install graphifyy; graphify install --platform windows"

win-install-hooks:
    python scripts/merge_settings.py

win-install-headroom:
    -claude plugin marketplace add chopratejas/headroom
    claude plugin install headroom
    powershell -NoProfile -Command "uv tool install 'headroom-ai[all]'"

win-uninstall-all: win-uninstall-hooks win-uninstall-agents win-uninstall-graphify win-uninstall-plugins
    @echo "Removed setup (headroom untouched)."

win-uninstall-agents:
    powershell -NoProfile -Command "'cavecrew-investigator','cavecrew-builder','cavecrew-reviewer','cavecrew-investigator-deep' | ForEach-Object { Remove-Item -Force -ErrorAction SilentlyContinue \"$env:USERPROFILE\.claude\agents\$_.md\" }; Write-Host 'Removed CaveCrew agents.'"

win-uninstall-plugins:
    -claude plugin uninstall superpowers
    -claude plugin uninstall ponytail
    -claude plugin marketplace remove superpowers-marketplace
    -claude plugin marketplace remove ponytail

win-uninstall-graphify:
    -graphify uninstall

win-uninstall-hooks:
    python scripts/purge_settings.py

win-uninstall-headroom:
    -claude plugin uninstall headroom
    -claude plugin marketplace remove headroom-marketplace
    -powershell -NoProfile -Command "uv tool uninstall headroom-ai"
