# claude-code-token-setup — install/uninstall the CaveCrew subagents.
# Claude Code agents are standalone .md files in ~/.claude/agents/, so install
# is just a file copy — no config merging (unlike opencode.jsonc).

agents_dir := "agents"

# Default: show recipes.
default:
    @just --list

# --- macOS / Linux ---

# Copy all CaveCrew agents into the global Claude Code agents dir.
mac-install:
    mkdir -p ~/.claude/agents
    cp {{agents_dir}}/*.md ~/.claude/agents/
    @echo "Installed CaveCrew agents to ~/.claude/agents/. Restart Claude Code to pick them up."

# Remove the CaveCrew agents from the global agents dir.
mac-uninstall:
    rm -f ~/.claude/agents/cavecrew-investigator.md \
          ~/.claude/agents/cavecrew-builder.md \
          ~/.claude/agents/cavecrew-reviewer.md \
          ~/.claude/agents/cavecrew-investigator-deep.md
    @echo "Removed CaveCrew agents from ~/.claude/agents/."

# --- Windows (PowerShell) ---

win-install:
    powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path $env:USERPROFILE\.claude\agents | Out-Null; Copy-Item {{agents_dir}}\*.md $env:USERPROFILE\.claude\agents\ -Force; Write-Host 'Installed CaveCrew agents. Restart Claude Code to pick them up.'"

win-uninstall:
    powershell -NoProfile -Command "'cavecrew-investigator','cavecrew-builder','cavecrew-reviewer','cavecrew-investigator-deep' | ForEach-Object { Remove-Item -Force -ErrorAction SilentlyContinue \"$env:USERPROFILE\.claude\agents\$_.md\" }; Write-Host 'Removed CaveCrew agents.'"
