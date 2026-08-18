# claude-code-token-setup — install/uninstall the full setup:
#   agents  → copied into ~/.claude/agents/
#   plugins → installed from their marketplaces via `claude plugin`
#   skills  → graphify (own CLI) + find-skills/agent-browser/skill-creator via
#             the `npx skills` CLI into ~/.claude/skills; plugin skills come with plugins
#   rtk     → Rust CLI-output token-killer + its transparent Bash-rewrite hook
#   hooks   → graphify hint + Bash security guard merged into
#             ~/.claude/settings.json (plugin hooks come with plugins);
#             commands also ship inside their plugins

agents_dir := "agents"

# Default: show recipes.
default:
    @just --list

# =====================================================================
# macOS / Linux
# =====================================================================

# Agents + plugins + skills + graphify + rtk + hooks.
mac-install-all: mac-install-plugins mac-install-skills mac-install-graphify mac-install-rtk mac-install-agents mac-install-hooks
    @echo "Done. Restart Claude Code to load agents, plugins, skills, rtk, and hooks."

# CaveCrew subagents → ~/.claude/agents/
mac-install-agents:
    mkdir -p ~/.claude/agents
    cp {{agents_dir}}/*.md ~/.claude/agents/
    @echo "Installed CaveCrew agents."

# superpowers + ponytail + caveman + i-have-adhd + claude-hud from their marketplaces.
mac-install-plugins:
    claude plugin marketplace add obra/superpowers-marketplace || true
    claude plugin marketplace add DietrichGebert/ponytail || true
    claude plugin marketplace add JuliusBrussee/caveman || true
    claude plugin marketplace add ayghri/i-have-adhd || true
    claude plugin marketplace add jarrodwatts/claude-hud || true
    claude plugin install superpowers
    claude plugin install ponytail
    claude plugin install caveman@caveman
    claude plugin install i-have-adhd@i-have-adhd
    claude plugin install claude-hud@claude-hud
    @echo "Installed plugins (their hooks/commands/skills come bundled)."

# Skills via the `npx skills` CLI (github.com/vercel-labs/skills), installed into
# the user-global ~/.claude/skills. Requires Node/npx. -g/--global is required —
# without it the CLI installs project-level, nesting a stray .claude/skills under cwd.
mac-install-skills:
    mkdir -p ~/.claude/skills
    npx -y skills add mgiovani/cc-arsenal --skill find-skills --agent claude-code -g -y
    npx -y skills add mgiovani/cc-arsenal --skill agent-browser --agent claude-code -g -y
    npx -y skills add anthropics/skills --skill skill-creator --agent claude-code -g -y
    npx -y skills add addyosmani/agent-skills --skill frontend-ui-engineering --agent claude-code -g -y
    @echo "Installed skills (find-skills, agent-browser, skill-creator, frontend-ui-engineering)."

# rtk — Rust CLI-output token-killer + its transparent Bash-rewrite hook.
# https://github.com/rtk-ai/rtk . `rtk init -g` writes the global Claude hook.
mac-install-rtk:
    brew install rtk || curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh
    rtk init -g --auto-patch
    @echo "Installed rtk + global hook. Restart Claude Code; verify with 'rtk init --show'."

# graphify CLI + skill (knowledge graph). Requires uv (https://astral.sh/uv).
mac-install-graphify:
    uv tool install graphifyy || pip install graphifyy
    graphify install --platform claude
    @echo "Installed graphify CLI + skill."

# graphify hint hook + security guard + "model": "opusplan" → ~/.claude/settings.json
# (idempotent, non-clobbering; model applies to CLI and desktop alike).
mac-install-hooks:
    mkdir -p ~/.claude/hooks
    cp scripts/security_guard.py ~/.claude/hooks/
    python3 scripts/merge_settings.py

# --- uninstalls ---

mac-uninstall-all: mac-uninstall-hooks mac-uninstall-agents mac-uninstall-graphify mac-uninstall-rtk mac-uninstall-skills mac-uninstall-plugins
    @echo "Removed setup."

mac-uninstall-agents:
    rm -f ~/.claude/agents/cavecrew-investigator.md \
          ~/.claude/agents/cavecrew-builder.md \
          ~/.claude/agents/cavecrew-reviewer.md \
          ~/.claude/agents/cavecrew-investigator-deep.md
    -rmdir ~/.claude/agents 2>/dev/null
    @echo "Removed CaveCrew agents."

mac-uninstall-plugins:
    claude plugin uninstall superpowers || true
    claude plugin uninstall ponytail || true
    claude plugin uninstall caveman || true
    claude plugin uninstall i-have-adhd || true
    claude plugin uninstall claude-hud || true
    claude plugin marketplace remove superpowers-marketplace || true
    claude plugin marketplace remove ponytail || true
    claude plugin marketplace remove caveman || true
    claude plugin marketplace remove i-have-adhd || true
    claude plugin marketplace remove claude-hud || true
    # Leftover ponytail state markers (safe: only touches ponytail's own files).
    rm -f ~/.claude/.ponytail-active ~/.claude/.ponytail-statusline-nudged
    @echo "Removed plugins + marketplaces."

# Best-effort: dir names follow whatever each skill CLI created under ~/.claude/skills.
mac-uninstall-skills:
    rm -rf ~/.claude/skills/find-skills ~/.claude/skills/agent-browser \
           ~/.claude/skills/skill-creator ~/.claude/skills/frontend-ui-engineering
    -rmdir ~/.claude/skills 2>/dev/null
    @echo "Removed skills (best-effort)."

# Best-effort: remove the rtk hook, the binary if brew-managed, and rtk's config.
mac-uninstall-rtk:
    rtk init -g --uninstall || true
    brew uninstall rtk || true
    rm -rf ~/.config/rtk "$HOME/Library/Application Support/rtk"
    @echo "Removed rtk hook + binary + config (best-effort)."

mac-uninstall-graphify:
    graphify uninstall || true
    @echo "Removed graphify (all platforms). Add --purge manually to delete graphify-out/."

mac-uninstall-hooks:
    python3 scripts/purge_settings.py
    rm -f ~/.claude/hooks/security_guard.py
    -rmdir ~/.claude/hooks 2>/dev/null

# =====================================================================
# Windows (PowerShell)
# =====================================================================

win-install-all: win-install-plugins win-install-skills win-install-graphify win-install-rtk win-install-agents win-install-hooks
    @echo "Done. Restart Claude Code."

win-install-agents:
    powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path \$env:USERPROFILE\.claude\agents | Out-Null; Copy-Item {{agents_dir}}\*.md \$env:USERPROFILE\.claude\agents\ -Force; Write-Host 'Installed CaveCrew agents.'"

win-install-plugins:
    -claude plugin marketplace add obra/superpowers-marketplace
    -claude plugin marketplace add DietrichGebert/ponytail
    -claude plugin marketplace add JuliusBrussee/caveman
    -claude plugin marketplace add ayghri/i-have-adhd
    -claude plugin marketplace add jarrodwatts/claude-hud
    claude plugin install superpowers
    claude plugin install ponytail
    claude plugin install caveman@caveman
    claude plugin install i-have-adhd@i-have-adhd
    claude plugin install claude-hud@claude-hud

# Skills via `npx skills` into %USERPROFILE%\.claude\skills. Requires Node/npx. -g/--global
# is required — without it the CLI installs project-level, nesting a stray .claude\skills under cwd.
win-install-skills:
    powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path \$env:USERPROFILE\.claude\skills | Out-Null; Set-Location \$env:USERPROFILE; npx -y skills add mgiovani/cc-arsenal --skill find-skills --agent claude-code -g -y; npx -y skills add mgiovani/cc-arsenal --skill agent-browser --agent claude-code -g -y; npx -y skills add anthropics/skills --skill skill-creator --agent claude-code -g -y; npx -y skills add addyosmani/agent-skills --skill frontend-ui-engineering --agent claude-code -g -y"

win-install-graphify:
    powershell -NoProfile -Command "uv tool install graphifyy; graphify install --platform windows"

# rtk — download the Windows release zip, put rtk.exe on ~\.local\bin (on PATH), then init the hook.
# See https://github.com/rtk-ai/rtk/releases . Falls back to cargo install if present.
win-install-rtk:
    powershell -NoProfile -Command "if (Get-Command rtk -ErrorAction SilentlyContinue) { Write-Host 'rtk already installed.' } elseif (Get-Command cargo -ErrorAction SilentlyContinue) { cargo install --git https://github.com/rtk-ai/rtk } else { $ErrorActionPreference='Stop'; $bin = \"$env:USERPROFILE\.local\bin\"; New-Item -ItemType Directory -Force -Path $bin | Out-Null; $zip = Join-Path $env:TEMP 'rtk.zip'; $url = (Invoke-RestMethod https://api.github.com/repos/rtk-ai/rtk/releases/latest).assets | Where-Object { $_.name -like '*pc-windows-msvc.zip' } | Select-Object -First 1 -ExpandProperty browser_download_url; Invoke-WebRequest -Uri $url -OutFile $zip; Expand-Archive -Path $zip -DestinationPath $bin -Force; Remove-Item $zip; if (($env:PATH -split ';') -notcontains $bin) { [Environment]::SetEnvironmentVariable('Path', \"$([Environment]::GetEnvironmentVariable('Path','User'));$bin\", 'User'); $env:PATH += \";$bin\" }; Write-Host \"Installed rtk.exe to $bin\" }"
    rtk init -g --auto-patch

win-install-hooks:
    powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path \$env:USERPROFILE\.claude\hooks | Out-Null; Copy-Item scripts\security_guard.py \$env:USERPROFILE\.claude\hooks\ -Force"
    uv run --no-project python scripts/merge_settings.py

win-uninstall-all: win-uninstall-hooks win-uninstall-agents win-uninstall-graphify win-uninstall-rtk win-uninstall-skills win-uninstall-plugins
    @echo "Removed setup."

win-uninstall-agents:
    powershell -NoProfile -Command "'cavecrew-investigator','cavecrew-builder','cavecrew-reviewer','cavecrew-investigator-deep' | ForEach-Object { Remove-Item -Force -ErrorAction SilentlyContinue \"\$env:USERPROFILE\.claude\agents\\\$_.md\" }; Write-Host 'Removed CaveCrew agents.'"

win-uninstall-plugins:
    -claude plugin uninstall superpowers
    -claude plugin uninstall ponytail
    -claude plugin uninstall caveman
    -claude plugin uninstall i-have-adhd
    -claude plugin uninstall claude-hud
    -claude plugin marketplace remove superpowers-marketplace
    -claude plugin marketplace remove ponytail
    -claude plugin marketplace remove caveman
    -claude plugin marketplace remove i-have-adhd
    -claude plugin marketplace remove claude-hud
    powershell -NoProfile -Command "'.ponytail-active','.ponytail-statusline-nudged' | ForEach-Object { Remove-Item -Force -ErrorAction SilentlyContinue \"\$env:USERPROFILE\.claude\\\$_\" }"

win-uninstall-skills:
    powershell -NoProfile -Command "'find-skills','agent-browser','skill-creator','frontend-ui-engineering' | ForEach-Object { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue \"\$env:USERPROFILE\.claude\skills\\\$_\" }"

win-uninstall-rtk:
    -rtk init -g --uninstall
    powershell -NoProfile -Command "Remove-Item -Recurse -Force -ErrorAction SilentlyContinue \"\$env:APPDATA\rtk\", \"\$env:USERPROFILE\.config\rtk\""

win-uninstall-graphify:
    -graphify uninstall

win-uninstall-hooks:
    uv run --no-project python scripts/purge_settings.py
    powershell -NoProfile -Command "Remove-Item -Force -ErrorAction SilentlyContinue \$env:USERPROFILE\.claude\hooks\security_guard.py"
