# Terminal Setup

A curated one-command macOS terminal setup for **zsh** and the native **Terminal.app**. Installs a fast, modern shell environment with sensible defaults — optimized for speed and AI coding agents.

While it includes an optional Terminal.app dark theme profile, the shell configuration works in **any terminal emulator** — [iTerm2](https://iterm2.com), [Ghostty](https://ghostty.org), [Alacritty](https://alacritty.org), [Kitty](https://sw.kovidez.net/kitty/), [WezTerm](https://wezfurlong.org/wezterm/), VS Code integrated terminal, etc. The zsh config, prompt, and plugins are terminal-agnostic.

## Quick Start

```bash
curl -sL https://raw.githubusercontent.com/dmythro/terminal-setup/main/setup-terminal.sh | bash
```

To undo everything:

```bash
curl -sL https://raw.githubusercontent.com/dmythro/terminal-setup/main/reset-terminal.sh | bash
```

## What You Get

### Core (always installed)

| Package | What it does |
|---------|-------------|
| [Homebrew](https://brew.sh) | macOS package manager (installed if missing) |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder — `Ctrl+R` for history, `Ctrl+T` for files |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-like ghost text suggestions from history |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Commands turn green/red as you type |
| [Starship](https://starship.rs) | Fast cross-shell prompt — git branch, status, language versions, exec time |

Plus a hand-tuned `~/.zshrc` with:

- **50K command history** with deduplication and cross-session sharing
- **Prefix history search** — type `git` then `↑` to find matching commands
- **Tab completion** with case-insensitive matching and menu selection
- **Option+Arrow** word jumping, **Option+Delete** word-boundary stops at `/`, `.`, `-`
- **Option+Enter** for multiline editing (useful with AI agents)
- Smart terminal tab titles showing current directory and command
- Aliases: `ll`, `gs`, `gl`, `gd`, `..`, `...`

### Optional — tmux

| Package | What it does |
|---------|-------------|
| [tmux](https://github.com/tmux/tmux) | Terminal multiplexer — split panes, persistent sessions, tabs |

Includes a mouse-friendly `~/.tmux.conf`:

- Auto-starts per terminal session (toggle with `USE_TMUX=false` in `~/.zshrc`)
- **Mouse support**: drag to copy (goes to macOS clipboard), drag borders to resize, scroll
- `Prefix + \|` / `Prefix + -` for vertical/horizontal splits
- `Prefix + hjkl` for pane navigation (arrow keys unbound to avoid zsh conflicts)
- `Prefix + HJKL` for pane resizing
- 50K scrollback, 256-color support, no escape delay

### Optional — Dev Tools

| Package | What it does |
|---------|-------------|
| [gh](https://cli.github.com) | GitHub CLI — PRs, issues, repos from the terminal |
| [bun](https://bun.sh) | Fast JS/TS runtime, bundler, and package manager |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`) | Fast recursive search (also powers fzf file search) |
| [fd](https://github.com/sharkdp/fd) | Fast `find` alternative (also powers fzf directory search) |

### Optional — AI Coding Agents

The setup includes an optional section for installing AI coding agent CLIs via Homebrew. Each agent is offered individually so you can pick the ones you use.

| Agent | Install | Open Source | Provider |
|-------|---------|:-----------:|----------|
| [OpenCode](https://opencode.ai) | `brew install opencode` | Yes (MIT) | Independent |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `brew install --cask claude-code` | No | Anthropic |
| [Codex](https://github.com/openai/codex) | `brew install --cask codex` | Yes (Apache 2.0) | OpenAI |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `brew install gemini-cli` | Yes (Apache 2.0) | Google |
| [Aider](https://aider.chat) | `brew install aider` | Yes (Apache 2.0) | Independent |

> Each agent requires its own API key or login. See the respective docs for setup.

### Optional — Terminal.app Profile

A dark theme profile (`Dmythro.terminal`) imported directly into Terminal.app:

- Dark background, Menlo Regular 14pt, 120x36 window
- Set as default profile on import
- `Use Option as Meta key` pre-configured in the plist (may need manual toggle — the script will remind you)

## AI Coding Agents Comparison

A brief comparison to help you choose. All are terminal-based agents that can edit files, run commands, and work with your codebase.

| | OpenCode | Claude Code | Codex | Gemini CLI | Aider |
|---|:--------:|:-----------:|:-----:|:----------:|:-----:|
| Default model | Multi-model | Claude Sonnet | GPT-4.1 | Gemini 2.5 Pro | Multi-model |
| Multi-model support | 10+ models | Claude family | OpenAI family | Gemini family | 30+ models |
| Agentic (edits + runs) | Yes | Yes | Yes | Yes | Yes |
| Git integration | Yes | Yes | Yes | Yes | Yes |
| MCP support | Yes | Yes | Yes | Yes | No |
| Open source | Yes (MIT) | No | Yes (Apache 2.0) | Yes (Apache 2.0) | Yes (Apache 2.0) |
| Pricing | API usage | API usage | API usage | Free tier + API | API usage |

> Last updated: February 2026. Agent capabilities evolve quickly — check the official docs for current features.

## Why This Setup

Setting up a productive terminal on a fresh Mac takes time. This script does it in one command with interactive prompts — no frameworks, no plugin managers, no bloat. Just Homebrew packages and plain config files.

The zsh configuration is optimized for working with AI coding agents:

- **Option+Enter** inserts a literal newline for multiline command editing
- **Large scrollback** (50K lines in both zsh and tmux) for reviewing agent output
- **Fast prompt** ([Starship](https://starship.rs) is written in Rust) that doesn't slow down rapid command execution
- **ripgrep + fd** integration for agents that rely on fast file search
- **tmux** for persistent sessions that survive disconnects

## Files

| File | Purpose |
|------|---------|
| `setup-terminal.sh` | Interactive setup — installs packages, writes configs |
| `reset-terminal.sh` | Interactive reset — removes configs, optionally uninstalls packages |
| `Dmythro.terminal` | Terminal.app profile plist (dark theme) |
| `AGENTS.md` | Instructions for AI coding agents working on this repo |

## Reset

The reset script interactively undoes everything:

```bash
curl -sL https://raw.githubusercontent.com/dmythro/terminal-setup/main/reset-terminal.sh | bash
```

- Replaces `~/.zshrc` with a minimal version (keeps Homebrew and `~/.local/bin` paths)
- Removes `~/.tmux.conf` and `~/.config/starship.toml`
- Optionally resets Terminal.app profile to Basic
- Optionally uninstalls all Homebrew packages added by the setup

## Roadmap

- [ ] Interactive TUI installer via `npx` / `bunx` (checkboxes, step previews, config presets)
- [ ] Profile presets (minimal, full, agent-focused)
- [ ] Linux support
- [ ] Dotfile backup before overwriting

## License

MIT
