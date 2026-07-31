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
  read -p "🗑  Reset config files? (~/.zshrc, ~/.tmux.conf, herdr + starship configs; clean ~/.zshenv, ~/.zprofile) [y/N] " -n 1 -r REMOVE_CONFIGS < /dev/tty
  echo ""
fi
if [[ $REMOVE_CONFIGS =~ ^[Yy]$ ]]; then
  rm -f ~/.tmux.conf
  rm -f ~/.config/starship.toml
  rm -f ~/.config/herdr/config.toml
  rmdir ~/.config/herdr 2>/dev/null || true
  # Remove setup-terminal.sh block from .zshenv/.zprofile (keep other content like cargo)
  for f in ~/.zshenv ~/.zprofile; do
    [[ -f "$f" ]] || continue
    sed -i '' '/^# BEGIN setup-terminal\.sh$/,/^# END setup-terminal\.sh$/d' "$f"
    # Remove empty leading lines
    sed -i '' '/./,$!d' "$f"
    # Drop the file entirely if we left it empty
    [[ -s "$f" ]] || rm -f "$f"
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
    # Hooks live outside herdr's own config (e.g. ~/.claude/hooks plus entries
    # in ~/.claude/settings.json), so they have to be removed through herdr
    # rather than by deleting config files. Names must match
    # `herdr integration install --help` — an unknown target exits 2.
    for agent in pi omp claude codex copilot devin droid kimi opencode kilo hermes qodercli cursor mastracode; do
      herdr integration uninstall "$agent" &>/dev/null || true
    done
    echo "   ✅ herdr server stopped and agent hooks removed"
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
  echo "   ~/.zshenv cleaned (setup-terminal.sh lines removed, other content preserved)"
fi
echo "   Quit Terminal.app (Cmd+Q) and reopen to start fresh."
echo ""
