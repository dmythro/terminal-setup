#!/bin/bash
# =============================================================================
# macOS / Linux Terminal Reset
# Undoes setup-terminal.sh — removes configs and optionally uninstalls packages
# Run: curl -sL https://raw.githubusercontent.com/dmythro/terminal-setup/main/reset-terminal.sh | bash
# =============================================================================

set -e

# --- OS detection ---
case "$(uname -s)" in
  Darwin) IS_MACOS=true;  IS_LINUX=false ;;
  Linux)  IS_MACOS=false; IS_LINUX=true  ;;
  *)      echo "❌ Unsupported OS: $(uname -s)"; exit 1 ;;
esac

echo "🧹 Terminal setup reset"
echo "   This will undo changes made by setup-terminal.sh"
echo ""

# --- 1. Remove config files ---
read -p "🗑  Remove config files? (~/.zshrc, ~/.tmux.conf, ~/.config/starship.toml) [y/N] " -n 1 -r REMOVE_CONFIGS < /dev/tty
echo ""
if [[ $REMOVE_CONFIGS =~ ^[Yy]$ ]]; then
  rm -f ~/.tmux.conf
  rm -f ~/.config/starship.toml
  # Write minimal .zshrc that preserves Homebrew and local bin paths
  cat > ~/.zshrc << 'ZSHRC'
# Minimal .zshrc — preserves Homebrew and local binaries
[[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
ZSHRC
  echo "   ✅ ~/.tmux.conf and starship.toml removed"
  echo "   ✅ ~/.zshrc replaced with minimal version"
fi

# --- 2. Remove fzf key bindings ---
if [[ -f ~/.fzf.zsh ]] || [[ -f ~/.fzf.bash ]]; then
  read -p "🗑  Remove fzf key bindings? (~/.fzf.zsh, ~/.fzf.bash) [y/N] " -n 1 -r REMOVE_FZF < /dev/tty
  echo ""
  if [[ $REMOVE_FZF =~ ^[Yy]$ ]]; then
    rm -f ~/.fzf.zsh ~/.fzf.bash
    echo "   ✅ fzf key bindings removed"
  fi
fi

# --- 3. Reset Terminal.app profile (macOS only) ---
if $IS_MACOS; then
  CURRENT_PROFILE=$(defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null || true)
  if [[ "$CURRENT_PROFILE" == "Dmythro" ]]; then
    read -p "🎨 Reset Terminal.app profile to Basic? [y/N] " -n 1 -r RESET_PROFILE < /dev/tty
    echo ""
    if [[ $RESET_PROFILE =~ ^[Yy]$ ]]; then
      defaults write com.apple.Terminal "Default Window Settings" -string "Basic"
      defaults write com.apple.Terminal "Startup Window Settings" -string "Basic"
      echo "   ✅ Terminal.app profile reset to Basic"
    fi
  fi
fi

# --- 4. Kill tmux if running ---
if command -v tmux &>/dev/null && tmux list-sessions &>/dev/null 2>&1; then
  read -p "🔌 Kill running tmux sessions? [y/N] " -n 1 -r KILL_TMUX < /dev/tty
  echo ""
  if [[ $KILL_TMUX =~ ^[Yy]$ ]]; then
    tmux kill-server 2>/dev/null || true
    echo "   ✅ tmux sessions killed"
  fi
fi

# --- 5. Uninstall packages ---
if $IS_MACOS && command -v brew &>/dev/null; then
  echo ""
  read -p "📦 Uninstall packages installed by setup-terminal.sh? [y/N] " -n 1 -r UNINSTALL_PKGS < /dev/tty
  echo ""
  if [[ $UNINSTALL_PKGS =~ ^[Yy]$ ]]; then
    PKGS=(fzf zsh-autosuggestions zsh-syntax-highlighting zsh-completions starship tmux gh bun ripgrep fd zoxide git-delta aider gemini-cli opencode)
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
elif $IS_LINUX; then
  echo ""
  read -p "📦 Uninstall packages installed by setup-terminal.sh? [y/N] " -n 1 -r UNINSTALL_PKGS < /dev/tty
  echo ""
  if [[ $UNINSTALL_PKGS =~ ^[Yy]$ ]]; then
    APT_PKGS=(fzf zsh-autosuggestions zsh-syntax-highlighting tmux ripgrep fd-find zoxide git-delta xclip gh)
    INSTALLED_APT=()
    for pkg in "${APT_PKGS[@]}"; do
      if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        INSTALLED_APT+=("$pkg")
      fi
    done
    if [[ ${#INSTALLED_APT[@]} -gt 0 ]]; then
      echo "   Removing apt packages: ${INSTALLED_APT[*]}"
      sudo apt remove -y "${INSTALLED_APT[@]}" 2>/dev/null || true
    fi
    # Remove git-cloned zsh-completions
    if [[ -d "$HOME/.zsh/zsh-completions" ]]; then
      echo "   Removing ~/.zsh/zsh-completions..."
      rm -rf "$HOME/.zsh/zsh-completions"
    fi
    # Remove starship if installed via curl
    if command -v starship &>/dev/null && [[ "$(which starship)" == "/usr/local/bin/starship" ]]; then
      echo "   Removing starship..."
      sudo rm -f /usr/local/bin/starship
    fi
    # Remove bun if installed via curl
    if [[ -d "$HOME/.bun" ]]; then
      read -p "   Remove bun (~/.bun)? [y/N] " -n 1 -r REMOVE_BUN < /dev/tty
      echo ""
      if [[ $REMOVE_BUN =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/.bun"
        echo "   ✅ bun removed"
      fi
    fi
    # Remove Nerd Font
    FONT_DIR="$HOME/.local/share/fonts"
    if ls "$FONT_DIR"/*Monasp* &>/dev/null 2>&1; then
      read -p "   Remove Monaspace Nerd Font from $FONT_DIR? [y/N] " -n 1 -r REMOVE_FONT < /dev/tty
      echo ""
      if [[ $REMOVE_FONT =~ ^[Yy]$ ]]; then
        rm -f "$FONT_DIR"/*Monasp*
        fc-cache -fv "$FONT_DIR" >/dev/null 2>&1
        echo "   ✅ Monaspace Nerd Font removed"
      fi
    fi
    echo "   ✅ Packages uninstalled"
  fi
fi

# --- 6. Done ---
echo ""
echo "✅ Reset complete."
if [[ $REMOVE_CONFIGS =~ ^[Yy]$ ]]; then
  echo "   ~/.zshrc replaced with minimal version (Homebrew + ~/.local/bin paths kept)"
fi
if $IS_MACOS; then
  echo "   Quit Terminal.app (Cmd+Q) and reopen to start fresh."
else
  echo "   Close and reopen your terminal to start fresh."
fi
echo ""
