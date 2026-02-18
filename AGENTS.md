# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A GitHub Gist (ID: `3ca5d026a1f0616507ab49bf331ee87c`) containing a one-command macOS Terminal.app setup script. Designed to be run via `curl | bash` on a fresh Mac.

## Files

- `setup-terminal.sh` — Interactive setup script that installs packages and writes config files (`~/.zshrc`, `~/.tmux.conf`, `~/.config/starship.toml`)
- `reset-terminal.sh` — Interactive reset script that undoes setup-terminal.sh (removes configs, optionally uninstalls packages)
- `Dmythro.terminal` — Terminal.app profile plist (dark theme, Menlo Regular 14pt, 120x36)

## Updating the Gist

After editing files locally, push changes with:
```
gh gist edit 3ca5d026a1f0616507ab49bf331ee87c -f setup-terminal.sh setup-terminal.sh
```
For the reset script:
```
gh gist edit 3ca5d026a1f0616507ab49bf331ee87c -f reset-terminal.sh reset-terminal.sh
```
For the terminal profile:
```
gh gist edit 3ca5d026a1f0616507ab49bf331ee87c -f Dmythro.terminal Dmythro.terminal
```

## Script Structure

The script uses `set -e` and is sequential with interactive prompts (`read -p`). It writes config files inline using **quoted heredocs** (`cat > ~/.file << 'TAG'`) so variables aren't expanded during write. The tmux toggle uses a `__TMUX_TOGGLE__` placeholder in the zshrc heredoc, replaced via `sed -i ''` after writing — this is the only value that needs post-write substitution.

`GIST_RAW` (line 12) is used to download `Dmythro.terminal` from the gist at runtime (section 9).

Key sections: Homebrew install → core packages → optional tmux → optional dev tools → fzf keybindings → tmux.conf → .zshrc → starship.toml → Terminal.app profile import → summary output.

`reset-terminal.sh` mirrors this structure with per-section interactive prompts. It replaces `~/.zshrc` with a minimal version (preserving Homebrew/local bin paths) rather than deleting it outright. Packages are left installed by default since they're inert without configs.

## Conventions

- Config sections use `# --- N. Section Name ---` numbered comment style
- Summary output at the end lists all installed features with emoji bullets
- The summary is conditional — only shows sections for packages the user chose to install
- The script is destructive — it overwrites `~/.zshrc`, `~/.tmux.conf`, and `~/.config/starship.toml` without backup. Don't test on a machine with configs you want to keep.

## Terminal Profile Notes

`Dmythro.terminal` already has `useOptionAsMetaKey` set to `true` in the plist. The script still shows a manual instruction for this (section 10) as a reminder, since Terminal.app may not always respect the plist value on import.
