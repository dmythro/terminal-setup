#!/bin/bash
# =============================================================================
# macOS Terminal Reset
# Undoes setup-terminal.sh — removes configs and optionally uninstalls packages
# Run: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dmythro/terminal-setup/main/reset-terminal.sh)"
# =============================================================================

set -e

# --- Parse flags ---
YES_MODE=false
for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES_MODE=true ;;
  esac
done

# --- TTY detection ---
if [[ "$YES_MODE" != "true" ]]; then
  if ! [[ -t 0 ]] && ! : 2>/dev/null </dev/tty; then
    echo "❌ No interactive terminal detected."
    echo "   Run from an interactive terminal:"
    echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dmythro/terminal-setup/main/reset-terminal.sh)"'
    echo "   Or run non-interactively with -y:"
    echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dmythro/terminal-setup/main/reset-terminal.sh)" -- -y'
    exit 1
  fi
fi

echo "🧹 Terminal setup reset"
echo "   This will undo changes made by setup-terminal.sh"
echo ""

# --- 1. Remove config files ---
if [[ "$YES_MODE" == "true" ]]; then
  REMOVE_CONFIGS=y
  echo "🗑  Resetting config files (auto-yes)..."
else
  read -p "🗑  Reset config files — no backup? Replaces ~/.zshrc, deletes ~/.tmux.conf + herdr/starship configs, cleans ~/.zshenv and ~/.zprofile [y/N] " -n 1 -r REMOVE_CONFIGS < /dev/tty
  echo ""
fi
if [[ $REMOVE_CONFIGS =~ ^[Yy]$ ]]; then
  rm -f ~/.tmux.conf
  rm -f ~/.config/starship.toml
  rm -f ~/.config/herdr/config.toml
  rmdir ~/.config/herdr 2>/dev/null || true
  # Remove the setup-terminal.sh block from .zshenv/.zprofile, keeping other
  # content (cargo, rustup, OrbStack, ...) exactly as-is.
  #
  # Deliberately not `sed '/BEGIN/,/END/d'`: a sed range with no closing match
  # deletes to end of file, so a hand-edited or truncated dotfile that kept the
  # BEGIN marker but lost the END would lose everything after it. awk buffers
  # the block and puts it back untouched when no END turns up.
  for f in ~/.zshenv ~/.zprofile; do
    [[ -f "$f" ]] || continue
    tmp="$(mktemp "${f}.tmp.XXXXXX")"
    awk '
      /^# BEGIN setup-terminal\.sh$/ && !inblk { inblk = 1; buf = $0 ORS; next }
      inblk && /^# END setup-terminal\.sh$/    { inblk = 0; buf = ""; next }
      inblk                                    { buf = buf $0 ORS; next }
                                               { print }
      END { if (inblk) printf "%s", buf }
    ' "$f" > "$tmp"
    # Write back without clobbering a symlinked dotfile (chezmoi, stow)
    if [[ -L "$f" ]]; then
      cat "$tmp" > "$f"
      rm -f "$tmp"
    else
      mv "$tmp" "$f"
    fi
    # Drop the file only if nothing but whitespace is left
    [[ -n "$(tr -d '[:space:]' < "$f")" ]] || rm -f "$f"
  done
  # Write minimal .zshrc (PATH setup is in .zshenv)
  cat > ~/.zshrc << 'ZSHRC'
# Minimal .zshrc
ZSHRC
  echo "   ✅ ~/.tmux.conf, starship.toml and herdr config removed"
  echo "   ✅ ~/.zshenv and ~/.zprofile cleaned (Homebrew/local bin lines removed)"
  echo "   ✅ ~/.zshrc replaced with minimal version"
fi

# --- 2. Remove fzf key bindings ---
if [[ -f ~/.fzf.zsh ]] || [[ -f ~/.fzf.bash ]]; then
  if [[ "$YES_MODE" == "true" ]]; then
    REMOVE_FZF=y
    echo "🗑  Removing fzf key bindings (auto-yes)..."
  else
    read -p "🗑  Remove fzf key bindings? (~/.fzf.zsh, ~/.fzf.bash) [y/N] " -n 1 -r REMOVE_FZF < /dev/tty
    echo ""
  fi
  if [[ $REMOVE_FZF =~ ^[Yy]$ ]]; then
    rm -f ~/.fzf.zsh ~/.fzf.bash
    echo "   ✅ fzf key bindings removed"
  fi
fi

# --- 3. Reset Terminal.app profile ---
CURRENT_PROFILE=$(defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null || true)
if [[ "$CURRENT_PROFILE" == "Dmythro" ]]; then
  if [[ "$YES_MODE" == "true" ]]; then
    RESET_PROFILE=y
    echo "🎨 Resetting Terminal.app profile to Basic (auto-yes)..."
  else
    read -p "🎨 Reset Terminal.app profile to Basic? [y/N] " -n 1 -r RESET_PROFILE < /dev/tty
    echo ""
  fi
  if [[ $RESET_PROFILE =~ ^[Yy]$ ]]; then
    defaults write com.apple.Terminal "Default Window Settings" -string "Basic"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Basic"
    echo "   ✅ Terminal.app profile reset to Basic"
  fi
fi

# --- 4. Kill tmux if running ---
if command -v tmux &>/dev/null && tmux list-sessions &>/dev/null 2>&1; then
  if [[ "$YES_MODE" == "true" ]]; then
    KILL_TMUX=y
    echo "🔌 Killing tmux sessions (auto-yes)..."
  else
    read -p "🔌 Kill running tmux sessions? [y/N] " -n 1 -r KILL_TMUX < /dev/tty
    echo ""
  fi
  if [[ $KILL_TMUX =~ ^[Yy]$ ]]; then
    tmux kill-server 2>/dev/null || true
    echo "   ✅ tmux sessions killed"
  fi
fi

# --- 4b. Stop herdr server + remove agent hooks ---
if command -v herdr &>/dev/null; then
  if [[ "$YES_MODE" == "true" ]]; then
    STOP_HERDR=y
    echo "🔌 Stopping herdr server and removing agent hooks (auto-yes)..."
  else
    read -p "🔌 Stop herdr server and remove its agent hooks? [y/N] " -n 1 -r STOP_HERDR < /dev/tty
    echo ""
  fi
  if [[ $STOP_HERDR =~ ^[Yy]$ ]]; then
    herdr server stop &>/dev/null || true
    # Only `claude` — that is the sole integration setup-terminal.sh installs,
    # and reset's contract is to undo setup, not to remove hooks you added by
    # hand for other agents (which -y would then delete without asking).
    # The hook lives outside herdr's own config (~/.claude/hooks plus entries
    # in ~/.claude/settings.json), so it has to go through herdr rather than
    # by deleting config files.
    herdr integration uninstall claude &>/dev/null || true
    # Best-effort, like the tmux and brew steps: both commands are no-ops when
    # there is no server running / no hook installed. Worded so it doesn't
    # claim to have removed something that was never there.
    echo "   ✅ herdr server stopped and Claude Code hook cleared (if present)"
  fi
fi

# --- 5. Uninstall Homebrew packages ---
if command -v brew &>/dev/null; then
  echo ""
  if [[ "$YES_MODE" == "true" ]]; then
    UNINSTALL_PKGS=n
  else
    read -p "📦 Uninstall packages installed by setup-terminal.sh? [y/N] " -n 1 -r UNINSTALL_PKGS < /dev/tty
    echo ""
  fi
  if [[ $UNINSTALL_PKGS =~ ^[Yy]$ ]]; then
    PKGS=(fzf zsh-autosuggestions zsh-syntax-highlighting zsh-completions starship tmux herdr gh bun ripgrep fd zoxide git-delta aider gemini-cli opencode)
    CASKS=(claude-code codex font-monaspice-nerd-font)
    for pkg in "${PKGS[@]}"; do
      if brew list "$pkg" &>/dev/null; then
        echo "   Removing $pkg..."
        brew uninstall "$pkg" 2>/dev/null || true
      fi
    done
    for cask in "${CASKS[@]}"; do
      if brew list --cask "$cask" &>/dev/null; then
        echo "   Removing $cask..."
        brew uninstall --cask "$cask" 2>/dev/null || true
      fi
    done
    echo "   ✅ Packages uninstalled"
  fi
fi

# --- 6. Done ---
echo ""
echo "✅ Reset complete."
if [[ $REMOVE_CONFIGS =~ ^[Yy]$ ]]; then
  echo "   ~/.zshrc replaced with minimal version"
  echo "   ~/.zshenv and ~/.zprofile cleaned (setup-terminal.sh block removed, other content preserved)"
fi
echo "   Quit Terminal.app (Cmd+Q) and reopen to start fresh."
echo ""
