# Plan: Add Linux Support to Terminal Setup Scripts

## Context

The scripts currently only work on macOS. Users want to run the same setup on Linux. The approach: detect the OS, use **apt** on Linux (not Homebrew/Linuxbrew) since that's what Linux users expect, and use **Homebrew** on macOS as before. Target: Ubuntu/Debian (apt). The architecture allows adding dnf/pacman later.

Key insight: make the `.zshrc` itself cross-platform by checking which paths exist at runtime — no placeholders needed for plugin paths.

## Files to Modify

- `setup-terminal.sh` — main changes
- `reset-terminal.sh` — mirror changes
- `README.md` — update for Linux
- `AGENTS.md` — update for Linux

## Package Availability on apt (Ubuntu 24.04)

| Package | apt? | apt name | Notes |
|---------|------|----------|-------|
| zsh | Yes | `zsh` | |
| fzf | Yes | `fzf` | Shell integration at `/usr/share/doc/fzf/examples/` |
| zsh-autosuggestions | Yes | `zsh-autosuggestions` | Source at `/usr/share/zsh-autosuggestions/` |
| zsh-syntax-highlighting | Yes | `zsh-syntax-highlighting` | Source at `/usr/share/zsh-syntax-highlighting/` |
| zsh-completions | **No** | — | Git clone from GitHub |
| starship | **No** | — | Official curl installer |
| tmux | Yes | `tmux` | |
| gh | **No** | — | Official apt repo setup |
| bun | **No** | — | Official curl installer |
| ripgrep | Yes | `ripgrep` | |
| fd | Yes | `fd-find` | Binary is `fdfind`, needs alias |
| zoxide | Yes | `zoxide` | |
| git-delta | Yes | `git-delta` | |
| xclip | Yes | `xclip` | For tmux clipboard on Linux |

---

## Changes: setup-terminal.sh

### 1. Header + OS detection (after `set -e`)
- Update header comment: "macOS / Linux Terminal Setup"
- Add OS detection booleans: `IS_MACOS` / `IS_LINUX` via `uname -s`

### 2. Helper function
- `sed_inplace()` — wraps `sed -i ''` (BSD) vs `sed -i` (GNU). Only helper needed.

### 3. Package installation (Sections 1-2, 4)

**Section 1 — Homebrew (macOS only):**
```bash
if $IS_MACOS; then
  # existing Homebrew install logic unchanged
fi
```

**Section 2 — Core packages:**
```bash
if $IS_MACOS; then
  brew install fzf zsh-autosuggestions zsh-syntax-highlighting zsh-completions starship
  chmod go-w "$(brew --prefix)/share/zsh-completions" "$(brew --prefix)/share"
else
  sudo apt update
  sudo apt install -y zsh fzf zsh-autosuggestions zsh-syntax-highlighting xclip
  # zsh-completions: clone from GitHub (not in apt)
  [[ ! -d "$HOME/.zsh/zsh-completions" ]] && \
    git clone --depth 1 https://github.com/zsh-users/zsh-completions ~/.zsh/zsh-completions
  # starship: not in apt on 24.04
  command -v starship &>/dev/null || curl -sS https://starship.rs/install.sh | sh -s -- -y
fi
```

**Section 3 — tmux:**
```bash
if $IS_MACOS; then brew install tmux; else sudo apt install -y tmux; fi
```

**Section 4 — Dev tools:**
```bash
if $IS_MACOS; then
  brew install gh bun ripgrep fd zoxide git-delta
else
  sudo apt install -y ripgrep fd-find zoxide git-delta
  # gh: official apt repo
  if ! command -v gh &>/dev/null; then
    # (official keyring + repo setup, then sudo apt install gh)
  fi
  # bun: official installer
  command -v bun &>/dev/null || curl -fsSL https://bun.sh/install | bash
  # fd alias hint (binary is fdfind on Debian/Ubuntu)
fi
```

### 4. fzf keybindings (Section 6)
```bash
if $IS_MACOS; then
  yes | $(brew --prefix)/opt/fzf/install --key-bindings --completion --no-update-rc 2>/dev/null || true
fi
# On Linux, fzf shell integration is sourced directly in .zshrc from /usr/share/doc/fzf/examples/
```

### 5. tmux.conf clipboard (Section 8)
- Use `__CLIPBOARD_CMD__` placeholder for the 6 `pbcopy` instances
- After writing heredoc, replace with `sed_inplace`:
  - macOS: `pbcopy`
  - Linux: `xclip -selection clipboard` (or `xsel`/`wl-copy` if found)
- Update comment from "macOS clipboard" to "system clipboard"

### 6. .zshrc — make it cross-platform at runtime (Section 9)

**Key idea:** Instead of placeholders, write a .zshrc that detects paths at runtime. This keeps the heredoc readable.

**Homebrew shellenv (line 168):**
```zsh
# --- Homebrew (macOS) ---
[[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
```
This silently does nothing on Linux. Clean.

**Completions fpath (line 199):**
```zsh
# --- Tab completion ---
# Homebrew zsh-completions (macOS)
[[ -d "$(brew --prefix 2>/dev/null)/share/zsh-completions" ]] && FPATH="$(brew --prefix)/share/zsh-completions:$FPATH"
# Git-cloned zsh-completions (Linux)
[[ -d "$HOME/.zsh/zsh-completions/src" ]] && fpath=($HOME/.zsh/zsh-completions/src $fpath)
autoload -Uz compinit && compinit
```

**Autosuggestions (line 207):**
```zsh
# Fish-like autosuggestions (grey ghost text, → to accept)
for _f in {$(brew --prefix 2>/dev/null),/usr}/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [[ -f "$_f" ]] && source "$_f" && break
done
```

**Syntax highlighting (line 212):**
```zsh
for _f in {$(brew --prefix 2>/dev/null),/usr}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  [[ -f "$_f" ]] && source "$_f" && break
done
```

**fzf (line 215):**
```zsh
# fzf fuzzy search (Ctrl+R for history, Ctrl+T for files)
if [[ -f ~/.fzf.zsh ]]; then
  source ~/.fzf.zsh
elif [[ -d /usr/share/doc/fzf/examples ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
  source /usr/share/doc/fzf/examples/completion.zsh
fi
```

**Zoxide (line 223):** Already cross-platform (`command -v zoxide`). No change.

**tmux auto-start (line 176):** Add `$DISPLAY` / `$WAYLAND_DISPLAY` checks:
```zsh
if [[ "$USE_TMUX" == "true" ]] && command -v tmux &>/dev/null && [[ -z "$TMUX" ]] && \
   [[ "$TERM_PROGRAM" == "Apple_Terminal" || "$TERM_PROGRAM" == "iTerm.app" || -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
```

**macOS 26 true color (line 229):** Wrap in `COLORTERM` check (Linux terminals usually set it):
```zsh
if [[ -z "$COLORTERM" ]] && [[ "$(sw_vers -productVersion 2>/dev/null)" == 26.* ]]; then
  export COLORTERM=truecolor
fi
```

**fd alias:** Add near other aliases:
```zsh
command -v fdfind &>/dev/null && ! command -v fd &>/dev/null && alias fd='fdfind'
```

**Local binaries:** Add `~/.bun/bin` to PATH for Linux bun install:
```zsh
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
```

### 7. sed -i call (line 262)
- Use `sed_inplace` for `__TMUX_TOGGLE__` replacement (only remaining placeholder)
- Add `__CLIPBOARD_CMD__` replacement for tmux.conf if tmux was installed

### 8. Font install (Section 11)
- macOS: `brew install --cask font-monaspice-nerd-font` (unchanged)
- Linux: download from `github.com/ryanoasis/nerd-fonts/releases` to `~/.local/share/fonts`, run `fc-cache -fv`

### 9. Terminal.app profile (Section 12)
- Wrap entire section in `if $IS_MACOS` — silently skipped on Linux

### 10. Summary output (Section 13)
- "Quit Terminal.app (Cmd+Q)" → "Close and reopen your terminal" on Linux
- Option as Meta key reminder → macOS only
- "Cmd+D" tmux note → macOS only
- Font message → "installed to ~/.local/share/fonts" on Linux
- AI agents: `--cask` → `npm` for claude-code/codex on Linux
- "another Mac" → "another machine" on Linux
- Add `chsh -s $(which zsh)` reminder on Linux if shell isn't zsh

---

## Changes: reset-terminal.sh

### 1. OS detection + `sed_inplace` helper (same as setup)

### 2. Minimal .zshrc (Section 1)
Replace hardcoded `/opt/homebrew` with the same runtime-check pattern:
```zsh
[[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 3. Terminal.app profile reset (Section 3)
- Wrap `defaults read/write` block in `if $IS_MACOS`

### 4. Package uninstall (Section 5)
- macOS: existing brew/cask uninstall (unchanged)
- Linux: `sudo apt remove` for apt-installed packages, `rm -rf ~/.zsh/zsh-completions`, prompt to remove nerd font from `~/.local/share/fonts`

### 5. Summary text (Section 6)
- "Cmd+Q" → conditional macOS/Linux text

---

## Changes: README.md

- Header: "one-command macOS terminal setup" → "one-command macOS & Linux terminal setup"
- Homebrew row: "macOS package manager" → "macOS package manager (Linux uses apt)"
- tmux clipboard: "macOS clipboard" → "system clipboard"
- Terminal.app profile section: note "(macOS only)"
- Nerd Fonts install commands: add Linux alternative
- "fresh Mac" → "fresh Mac or Linux machine"
- Roadmap: `- [x] Linux support`

## Changes: AGENTS.md

- "macOS terminal setup script" → "macOS / Linux terminal setup script"
- Document OS detection and `sed_inplace` helper
- Note: macOS uses Homebrew, Linux uses apt
- Note which sections are macOS-only

---

## Verification

1. Read through both scripts checking all conditional blocks
2. Verify no leftover `__CLIPBOARD_CMD__` placeholders in output files
3. Verify .zshrc plugin source paths work on both OS (path-exists checks)
4. macOS: should behave identically to current version
5. Linux: verify apt install, font download, skipped Terminal.app section, fzf integration paths
