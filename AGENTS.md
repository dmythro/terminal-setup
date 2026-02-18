# AGENTS.md

This file provides guidance to AI coding agents working on this repository.

## What This Is

A GitHub repo ([dmythro/terminal-setup](https://github.com/dmythro/terminal-setup)) containing a one-command macOS / Linux terminal setup script. Designed to be run via `curl | bash` on a fresh Mac or Linux machine (Ubuntu/Debian).

## Files

- `setup-terminal.sh` — Interactive setup script that installs packages and writes config files (`~/.zshrc`, `~/.tmux.conf`, `~/.config/starship.toml`)
- `reset-terminal.sh` — Interactive reset script that undoes setup-terminal.sh (removes configs, optionally uninstalls packages)
- `Dmythro.terminal` — Terminal.app profile plist (dark theme, MonaspiceNe NFM 14pt, 120x36)
- `README.md` — User-facing documentation with feature tables, comparison chart, and quick start
- `AGENTS.md` — This file (symlinked as `CLAUDE.md` for Claude Code compatibility)

## Script Structure

The script uses `set -e` and is sequential with interactive prompts (`read -p`). It writes config files inline using **quoted heredocs** (`cat > ~/.file << 'TAG'`) so variables aren't expanded during write. Two placeholders need post-write substitution: `__TMUX_TOGGLE__` in the zshrc and `__CLIPBOARD_CMD__` in the tmux.conf, both replaced via the `sed_inplace` helper.

**OS detection** uses `uname -s` to set `IS_MACOS`/`IS_LINUX` booleans at the top. macOS uses Homebrew for packages; Linux (Ubuntu/Debian) uses apt, with curl installers for packages not in apt (starship, bun) and a git clone for zsh-completions. The `sed_inplace()` helper wraps `sed -i ''` (BSD) vs `sed -i` (GNU) — it's the only helper function needed.

`REPO_RAW` (line 9) is used to download `Dmythro.terminal` from the repo at runtime (section 12, macOS only).

Key sections: Homebrew install (macOS only) → core packages → optional tmux → optional dev tools (incl. zoxide, delta) → optional AI coding agents → fzf keybindings (macOS only) → delta git config → tmux.conf → .zshrc → starship.toml → Nerd Font → Terminal.app profile import (macOS only) → summary output.

The `.zshrc` is cross-platform — it detects paths at runtime (e.g. `[[ -f /opt/homebrew/bin/brew ]]`) rather than using OS-specific placeholders for plugin paths. Autosuggestions, syntax highlighting, and fzf are sourced from whichever path exists (Homebrew or `/usr/share`).

`reset-terminal.sh` mirrors this structure with per-section interactive prompts. It replaces `~/.zshrc` with a minimal version (preserving Homebrew/local bin paths) rather than deleting it outright. Packages are left installed by default since they're inert without configs. On Linux, it removes apt packages and git-cloned zsh-completions.

## Conventions

- Config sections use `# --- N. Section Name ---` numbered comment style
- Summary output at the end lists all installed features with emoji bullets
- The summary is conditional — only shows sections for packages the user chose to install
- The script is destructive — it overwrites `~/.zshrc`, `~/.tmux.conf`, and `~/.config/starship.toml` without backup. Don't test on a machine with configs you want to keep.
- AI coding agent prompts default to Y for OpenCode and Claude Code, N for the rest
- Terminal.app profile import (section 12) is macOS-only — silently skipped on Linux
- Nerd Font install uses `brew --cask` on macOS, downloads from GitHub releases on Linux

## Terminal Profile Notes

`Dmythro.terminal` already has `useOptionAsMetaKey` set to `true` in the plist. The script still shows a manual instruction for this (section 12) as a reminder, since Terminal.app may not always respect the plist value on import.

## macOS 26 Support

The .zshrc detects macOS 26+ via `sw_vers -productVersion` and sets `COLORTERM=truecolor`. The tmux config uses `tmux-256color` with true color overrides (`Tc`). This enables full 24-bit color in Terminal.app on Tahoe.

## AI Coding Agents

No AI agents are installed or prompted during setup. The final summary lists all available agents with their `brew install` commands for the user to run when ready:
- **OpenCode** (`brew install opencode`) — open source
- **Claude Code** (`brew install --cask claude-code`) — Anthropic
- **Codex** (`brew install --cask codex`) — OpenAI, open source
- **Gemini CLI** (`brew install gemini-cli`) — Google, open source
- **Aider** (`brew install aider`) — multi-model pair programming

The reset script still handles both formula and cask uninstalls for agents that were installed manually (macOS). On Linux, the reset script removes apt packages, git-cloned zsh-completions, and optionally bun and Nerd Fonts.
