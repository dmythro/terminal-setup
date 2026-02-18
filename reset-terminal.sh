#!/bin/bash
# =============================================================================
# macOS Terminal Reset
# Undoes setup-terminal.sh — removes configs and optionally uninstalls packages
# Run: curl -sL https://raw.githubusercontent.com/dmythro/terminal-setup/main/reset-terminal.sh | bash
# =============================================================================

set -e

echo "🧹 Terminal setup reset"
echo "   This will undo changes made by setup-terminal.sh"
echo ""

# --- 1. Remove config files ---
read -p "🗑  Remove config files? (~/.zshrc, ~/.tmux.conf, ~/.config/starship.toml) [y/N] " -n 1 -r REMOVE_CONFIGS
echo ""
if [[ $REMOVE_CONFIGS =~ ^[Yy]$ ]]; then
  rm -f ~/.tmux.conf
  rm -f ~/.config/starship.toml
  # Write minimal .zshrc that preserves Homebrew and local bin paths
  cat > ~/.zshrc << 'ZSHRC'
# Minimal .zshrc — preserves Homebrew and local binaries
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
export PATH="$HOME/.local/bin:$PATH"
ZSHRC
  echo "   ✅ ~/.tmux.conf and starship.toml removed"
  echo "   ✅ ~/.zshrc replaced with minimal version"
fi

# --- 2. Remove fzf key bindings ---
if [[ -f ~/.fzf.zsh ]] || [[ -f ~/.fzf.bash ]]; then
  read -p "🗑  Remove fzf key bindings? (~/.fzf.zsh, ~/.fzf.bash) [y/N] " -n 1 -r REMOVE_FZF
  echo ""
  if [[ $REMOVE_FZF =~ ^[Yy]$ ]]; then
    rm -f ~/.fzf.zsh ~/.fzf.bash
    echo "   ✅ fzf key bindings removed"
  fi
fi

# --- 3. Reset Terminal.app profile ---
CURRENT_PROFILE=$(defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null || true)
if [[ "$CURRENT_PROFILE" == "Dmythro" ]]; then
  read -p "🎨 Reset Terminal.app profile to Basic? [y/N] " -n 1 -r RESET_PROFILE
  echo ""
  if [[ $RESET_PROFILE =~ ^[Yy]$ ]]; then
    defaults write com.apple.Terminal "Default Window Settings" -string "Basic"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Basic"
    echo "   ✅ Terminal.app profile reset to Basic"
  fi
fi

# --- 4. Kill tmux if running ---
if command -v tmux &>/dev/null && tmux list-sessions &>/dev/null 2>&1; then
  read -p "🔌 Kill running tmux sessions? [y/N] " -n 1 -r KILL_TMUX
  echo ""
  if [[ $KILL_TMUX =~ ^[Yy]$ ]]; then
    tmux kill-server 2>/dev/null || true
    echo "   ✅ tmux sessions killed"
  fi
fi

# --- 5. Uninstall Homebrew packages ---
if command -v brew &>/dev/null; then
  echo ""
  read -p "📦 Uninstall packages installed by setup-terminal.sh? [y/N] " -n 1 -r UNINSTALL_PKGS
  echo ""
  if [[ $UNINSTALL_PKGS =~ ^[Yy]$ ]]; then
    PKGS=(fzf zsh-autosuggestions zsh-syntax-highlighting starship tmux gh bun ripgrep fd aider gemini-cli opencode)
    CASKS=(claude-code codex)
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
  echo "   ~/.zshrc replaced with minimal version (Homebrew + ~/.local/bin paths kept)"
fi
echo "   Quit Terminal.app (Cmd+Q) and reopen to start fresh."
echo ""
