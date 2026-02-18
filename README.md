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

## Features

- Fuzzy search for history, files, and directories (fzf)
- Fish-like autosuggestions and syntax highlighting
- Extended tab completions for hundreds of tools
- Prefix history search — type a command then press `↑`
- 50K command history with deduplication and cross-session sharing
- Fast cross-shell prompt with git info and exec time (Starship)
- macOS-native word jumping and deletion (Option+Arrow, Option+Delete)
- Multiline command editing with Option+Enter
- Optional: tmux with mouse support, split panes, and clipboard integration
- Optional: dev tools — gh, bun, ripgrep, fd, zoxide, delta
- Optional: Terminal.app dark theme profile
- macOS 26 Tahoe true color support

## What You Get

### Core (always installed)

| Package | What it does |
|---------|-------------|
| [Homebrew](https://brew.sh) | macOS package manager (installed if missing) |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder — `Ctrl+R` for history, `Ctrl+T` for files |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-like ghost text suggestions from history |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Commands turn green/red as you type |
| [zsh-completions](https://github.com/zsh-users/zsh-completions) | Extended tab completions for hundreds of tools |
| [Starship](https://starship.rs) | Fast cross-shell prompt — git branch, status, language versions, exec time |

Plus a hand-tuned `~/.zshrc` with:

- **50K command history** with deduplication and cross-session sharing
- Smart terminal tab titles showing current directory and command
- Aliases: `ll`, `gs`, `gl`, `gd`, `..`, `...`

### Optional — tmux

| Package | What it does |
|---------|-------------|
| [tmux](https://github.com/tmux/tmux) | Terminal multiplexer — split panes, persistent sessions, tabs |

Includes a mouse-friendly `~/.tmux.conf`:

- Auto-starts per terminal session (toggle with `USE_TMUX=false` in `~/.zshrc`)
- Mouse support: drag to select and copy, drag borders to resize, scroll to browse
- 50K scrollback, true color support, no escape delay
- See [Keyboard Shortcuts](#keyboard-shortcuts) for keybindings

### Optional — Dev Tools

| Package | What it does |
|---------|-------------|
| [gh](https://cli.github.com) | GitHub CLI — PRs, issues, repos from the terminal |
| [bun](https://bun.sh) | Fast JS/TS runtime, bundler, and package manager |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`) | Fast recursive search (also powers fzf file search) |
| [fd](https://github.com/sharkdp/fd) | Fast `find` alternative (also powers fzf directory search) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) (`z`) | Smart `cd` — learns your frequent directories |
| [delta](https://github.com/dandavison/delta) | Beautiful `git diff` with syntax highlighting and line numbers |

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

- Dark background, MonaspiceNe NFM 14pt, 120x36 window
- Set as default profile on import
- `Use Option as Meta key` pre-configured in the plist (may need manual toggle — the script will remind you)

## Keyboard Shortcuts

### Shell (with or without tmux)

These are zsh-level bindings — they work in any terminal, with or without tmux.

| Key | Action |
|-----|--------|
| `Ctrl+R` | Fuzzy search history (fzf) |
| `Ctrl+T` | Fuzzy find files (fzf) |
| `Alt+C` | Fuzzy find and cd into directory (fzf) |
| `↑` / `↓` | Prefix history search (type first, then arrow) |
| `→` | Accept autosuggestion |
| `Tab` | Menu-driven completion |
| `Ctrl+A` / `Ctrl+E` | Beginning / end of line |
| `Ctrl+W` | Delete word backward |
| `Ctrl+U` | Delete to start of line |
| `Option+←` / `Option+→` | Jump word backward / forward |
| `Option+Delete` | Delete word forward (stops at `/` `.` `-`) |
| `Option+Backspace` | Delete word backward |
| `Option+Shift+Backspace` | Delete to start of line |
| `Option+Enter` | Insert literal newline (multiline editing) |

> Requires **Use Option as Meta Key** enabled in Terminal.app (Settings > Profiles > Keyboard). The included terminal profile has this pre-configured.

### tmux (Prefix = `Ctrl+B`)

These only work inside a tmux session. For the full list of default tmux keys, see [tmuxcheatsheet.com](https://tmuxcheatsheet.com).

| Key | Action |
|-----|--------|
| `Prefix + \|` | Split pane vertically |
| `Prefix + -` | Split pane horizontally |
| `Prefix + h/j/k/l` | Navigate panes (left/down/up/right) |
| `Prefix + H/J/K/L` | Resize panes by 5 (repeatable) |
| `Prefix + c` | New window (keeps current path) |
| `Prefix + n` / `p` | Next / previous window |
| `Prefix + z` | Zoom/unzoom pane |
| `Prefix + x` | Close pane |

> Arrow keys are intentionally unbound in tmux to avoid conflicts with Option+Arrow word jumping in zsh.

### Clipboard

| Context | How to copy |
|---------|-------------|
| **tmux** | Mouse drag to select — automatically copied to macOS clipboard on release. Or `Prefix + [` to enter copy mode, select text, press `Enter` or `y` to copy. |
| **Terminal.app** | Native selection with `Cmd+C` to copy (standard macOS behavior) |

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

## macOS 26 Tahoe

macOS 26 (Tahoe) introduced the [first major Terminal.app update in 24 years](https://www.macworld.com/article/2809620/macos-26-includes-a-new-look-for-the-terminal-app.html):

- **24-bit true color** — colors render exactly as specified (no more 256-color approximation)
- **Powerline font support** — Starship and other prompt tools can display icons and glyphs natively
- **Liquid Glass themes** — new built-in visual design

This setup automatically detects macOS 26+ and enables `COLORTERM=truecolor` for full color support. The tmux config uses `tmux-256color` with true color overrides.

> **Check your version:** Apple menu > About This Mac, or run `sw_vers -productVersion` in Terminal. macOS 26.3 is the [current stable release](https://support.apple.com/en-us/122868) (February 2026).

### Nerd Fonts

To get the most out of Starship's icons and glyphs on macOS 26, use a [Nerd Font](https://www.nerdfonts.com) — a regular coding font patched with thousands of extra glyphs (file icons, git symbols, language logos). The fonts below all support **programming ligatures** and are available via Homebrew:

> **Note:** Terminal.app on macOS 26 only renders `calt` (contextual alternates) — it does not support `liga`/`dlig` ligatures. For full ligature rendering, use [iTerm2](https://iterm2.com), [Kitty](https://sw.kovidgoyal.net/kitty/), or [WezTerm](https://wezfurlong.org/wezterm/).

| Font | By | Ligatures | Box Drawing | Install |
|------|----|:---------:|:-----------:|---------|
| [Geist Mono](https://www.programmingfonts.org/#geistmono) | Vercel | Yes (SS11) | Partial | `brew install --cask font-geist-mono-nerd-font` |
| [Cascadia Code](https://www.programmingfonts.org/#cascadiacode) | Microsoft | Yes | Complete | `brew install --cask font-caskaydia-mono-nerd-font` |
| [Monaspace](https://monaspace.githubnext.com) | GitHub | Yes | Complete | `brew install --cask font-monaspice-nerd-font` |
| [Iosevka](https://www.programmingfonts.org/#iosevka) | Belleve Invis | Yes | Complete | `brew install --cask font-iosevka-nerd-font` |

**Geist Mono** — ligatures are off by default; enable Stylistic Set 11 (SS11) in your terminal's font settings. Box drawing characters were added in v1.5.0 but [some intersections are missing](https://github.com/vercel/geist-font/issues/64) (e.g. `├`), causing fallback to the system font — TUI apps with tables (lazygit, btop, opencode) may show gaps at those points. **Cascadia Code** and **Monaspace** have complete box drawing and render gapless tables.

**Monaspace** — 5 variants (Neon, Argon, Xenon, Radon, Krypton) with "texture healing" for readability and variable weight support.

**Iosevka** — extremely narrow and customizable, good for small screens and split panes.

After installing, set the font in Terminal.app: **Settings > Profiles > Font > Change**.

> Preview and compare fonts at [programmingfonts.org](https://www.programmingfonts.org).

## Why This Setup

Setting up a productive terminal on a fresh Mac takes time. This script does it in one command with interactive prompts — no frameworks, no plugin managers, no bloat. Just Homebrew packages and plain config files.

The zsh configuration is optimized for working with AI coding agents:

- **Option+Enter** inserts a literal newline for multiline command editing
- **Large scrollback** (50K lines in both zsh and tmux) for reviewing agent output
- **Fast prompt** ([Starship](https://starship.rs) is written in Rust) that doesn't slow down rapid command execution
- **ripgrep + fd** integration for agents that rely on fast file search
- **zoxide** for quick directory jumping across project repos
- **delta** for readable diffs when reviewing agent-generated changes
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
