#!/bin/bash
# =============================================================================
# macOS / Linux Terminal Setup
# Run: curl -sL https://raw.githubusercontent.com/dmythro/terminal-setup/main/setup-terminal.sh | bash
# =============================================================================

set -e

REPO_RAW="https://raw.githubusercontent.com/dmythro/terminal-setup/main"

# --- OS detection ---
case "$(uname -s)" in
  Darwin) IS_MACOS=true;  IS_LINUX=false ;;
  Linux)  IS_MACOS=false; IS_LINUX=true  ;;
  *)      echo "❌ Unsupported OS: $(uname -s)"; exit 1 ;;
esac

# --- Helper: cross-platform sed -i ---
sed_inplace() {
  if $IS_MACOS; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

echo "🚀 Setting up terminal..."

# --- 1. Install Homebrew if missing (macOS only) ---
if $IS_MACOS; then
  if ! command -v brew &>/dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

# --- 2. Core packages ---
echo "📦 Installing core packages..."
if $IS_MACOS; then
  brew install fzf zsh-autosuggestions zsh-syntax-highlighting zsh-completions starship
  chmod go-w "$(brew --prefix)/share/zsh-completions" "$(brew --prefix)/share"
else
  sudo apt update
  sudo apt install -y zsh fzf zsh-autosuggestions zsh-syntax-highlighting xclip
  # zsh-completions: not in apt, clone from GitHub
  if [[ ! -d "$HOME/.zsh/zsh-completions" ]]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-completions ~/.zsh/zsh-completions
  fi
  # starship: not in apt on 24.04
  command -v starship &>/dev/null || curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# --- 3. Optional tmux ---
echo ""
read -p "📦 Install tmux for split panes? (auto-starts per session) [y/N] " -n 1 -r INSTALL_TMUX < /dev/tty
echo ""
if [[ $INSTALL_TMUX =~ ^[Yy]$ ]]; then
  if $IS_MACOS; then brew install tmux; else sudo apt install -y tmux; fi
  echo "   ✅ tmux installed"
fi

# --- 4. Optional dev tools ---
echo ""
read -p "📦 Install dev tools? (gh, bun, ripgrep, fd, zoxide, delta) [y/N] " -n 1 -r INSTALL_DEV < /dev/tty
echo ""
if [[ $INSTALL_DEV =~ ^[Yy]$ ]]; then
  if $IS_MACOS; then
    brew install gh bun ripgrep fd zoxide git-delta
  else
    sudo apt install -y ripgrep fd-find zoxide git-delta
    # gh: official apt repo
    if ! command -v gh &>/dev/null; then
      (type -p wget >/dev/null || sudo apt install -y wget) \
        && sudo mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && wget -nv -O "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
        && sudo apt update \
        && sudo apt install -y gh
      rm -f "$out"
    fi
    # bun: official installer
    command -v bun &>/dev/null || curl -fsSL https://bun.sh/install | bash
  fi
  echo "   ✅ Dev tools installed"
fi

# --- 5. AI coding agents (listed in summary, not installed) ---

# --- 6. Install fzf key bindings (macOS only — Linux sources from /usr/share in .zshrc) ---
if $IS_MACOS; then
  yes | $(brew --prefix)/opt/fzf/install --key-bindings --completion --no-update-rc 2>/dev/null || true
fi

# --- 7. Configure git to use delta (if installed) ---
if command -v delta &>/dev/null; then
  echo "📝 Configuring git to use delta for diffs..."
  git config --global core.pager delta
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.navigate true
  git config --global delta.dark true
  git config --global delta.line-numbers true
  git config --global delta.syntax-theme Dracula
  git config --global merge.conflictstyle zdiff3
fi

# --- 8. Write tmux.conf (if tmux selected) ---
if [[ $INSTALL_TMUX =~ ^[Yy]$ ]]; then
echo "📝 Writing ~/.tmux.conf..."
cat > ~/.tmux.conf << 'TMUX'
# =============================================================================
# tmux Config — mouse-first, no arrow key conflicts
# =============================================================================

# --- Mouse support (resize panes by dragging borders, click to select) ---
set -g mouse on

# --- Terminal colors (true color) ---
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:Tc,tmux-256color:Tc"

# --- No delay on Escape (important for zsh/vim) ---
set -sg escape-time 0

# --- Start window/pane numbering at 1 ---
set -g base-index 1
setw -g pane-base-index 1

# --- Renumber windows when one is closed ---
set -g renumber-windows on

# --- Increase scrollback ---
set -g history-limit 50000

# --- Split panes with | and - (easier to remember) ---
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# --- New window keeps current path ---
bind c new-window -c "#{pane_current_path}"

# --- Prefix + hjkl to navigate panes (no arrow conflicts) ---
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# --- Prefix + HJKL to resize panes (no arrow conflicts) ---
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# --- Unbind arrow-based resize (prevents conflicts with zsh) ---
unbind C-Up
unbind C-Down
unbind C-Left
unbind C-Right
unbind M-Up
unbind M-Down
unbind M-Left
unbind M-Right

# --- Status bar ---
set -g status-style "bg=default,fg=white"
set -g status-left "#[fg=cyan,bold] #S "
set -g status-right "#[fg=yellow]%H:%M "
set -g status-left-length 20
set -g window-status-current-style "fg=cyan,bold"
set -g window-status-style "fg=colour244"

# --- Window titles (passed to terminal tab) ---
set -g set-titles on
set -g set-titles-string "#{pane_title}"
setw -g automatic-rename on

# --- Clipboard (all copy operations go to system clipboard) ---
set -s copy-command "__CLIPBOARD_CMD__"

# Mouse drag copies to clipboard
bind -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "__CLIPBOARD_CMD__"
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "__CLIPBOARD_CMD__"

# Keyboard copy
bind -T copy-mode Enter send-keys -X copy-pipe-and-cancel "__CLIPBOARD_CMD__"
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "__CLIPBOARD_CMD__"
bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "__CLIPBOARD_CMD__"

# --- Pane borders ---
set -g pane-border-style "fg=colour238"
set -g pane-active-border-style "fg=cyan"
TMUX

# Replace clipboard placeholder with OS-appropriate command
if $IS_MACOS; then
  CLIP_CMD="pbcopy"
else
  if command -v wl-copy &>/dev/null; then
    CLIP_CMD="wl-copy"
  elif command -v xclip &>/dev/null; then
    CLIP_CMD="xclip -selection clipboard"
  elif command -v xsel &>/dev/null; then
    CLIP_CMD="xsel --clipboard --input"
  else
    CLIP_CMD="xclip -selection clipboard"
  fi
fi
sed_inplace "s|__CLIPBOARD_CMD__|$CLIP_CMD|g" ~/.tmux.conf

# Reload config if inside tmux (new settings take effect without restart)
[[ -n "$TMUX" ]] && tmux source-file ~/.tmux.conf 2>/dev/null || true
fi

# --- 9. Write .zshrc ---
echo "📝 Writing ~/.zshrc..."

# Determine tmux toggle value
if [[ $INSTALL_TMUX =~ ^[Yy]$ ]]; then
  TMUX_TOGGLE="true"
else
  TMUX_TOGGLE="false"
fi

cat > ~/.zshrc << 'ZSHRC'
# =============================================================================
# Zsh Config
# =============================================================================

# --- Homebrew (macOS) ---
[[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

# --- Local binaries (claude, bun, etc.) ---
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# --- tmux auto-start ---
# Set USE_TMUX=false in ~/.zshrc to disable tmux auto-start
USE_TMUX=__TMUX_TOGGLE__
if [[ "$USE_TMUX" == "true" ]] && command -v tmux &>/dev/null && [[ -z "$TMUX" ]] && \
   [[ "$TERM_PROGRAM" == "Apple_Terminal" || "$TERM_PROGRAM" == "iTerm.app" || -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
  tmux new-session && exit
fi

# --- History ---
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE          # prefix with space to skip history

# --- Up/Down prefix search (type "git" then ↑ to search git commands) ---
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

# --- Tab completion ---
# Homebrew zsh-completions (macOS)
[[ -d "$(brew --prefix 2>/dev/null)/share/zsh-completions" ]] && FPATH="$(brew --prefix)/share/zsh-completions:$FPATH"
# Git-cloned zsh-completions (Linux)
[[ -d "$HOME/.zsh/zsh-completions/src" ]] && fpath=($HOME/.zsh/zsh-completions/src $fpath)
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# --- Plugins ---
# Fish-like autosuggestions (grey ghost text, → to accept)
for _f in {$(brew --prefix 2>/dev/null),/usr}/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [[ -f "$_f" ]] && source "$_f" && break
done
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Syntax highlighting (commands turn green/red as you type)
for _f in {$(brew --prefix 2>/dev/null),/usr}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  [[ -f "$_f" ]] && source "$_f" && break
done

# fzf fuzzy search (Ctrl+R for history, Ctrl+T for files)
if [[ -f ~/.fzf.zsh ]]; then
  source ~/.fzf.zsh
elif [[ -d /usr/share/doc/fzf/examples ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
  source /usr/share/doc/fzf/examples/completion.zsh
fi
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9,fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9,info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6,marker:#ff79c6'

# Use ripgrep/fd with fzf if available
command -v rg &>/dev/null && export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
command -v fd &>/dev/null && export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'

# --- Zoxide (smart cd) ---
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# --- Starship prompt ---
eval "$(starship init zsh)"

# --- True color support (macOS 26+) ---
if [[ -z "$COLORTERM" ]] && [[ "$(sw_vers -productVersion 2>/dev/null)" == 26.* ]]; then
  export COLORTERM=truecolor
fi

# --- Terminal title ---
precmd()  { print -Pn "\e]0;%1~ · zsh\a" }
preexec() { print -Pn "\e]0;%1~ · ${1%% *}\a" }

# --- Aliases ---
alias ll='ls -lAh --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias gs='git status'
alias gl='git log --oneline -20'
alias gd='git diff'
command -v fdfind &>/dev/null && ! command -v fd &>/dev/null && alias fd='fdfind'

# --- Word boundaries (stop at /, ., - like macOS) ---
WORDCHARS=''

# --- Keybindings ---
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^W' backward-kill-word
bindkey '^\b' backward-kill-word        # Option+Backspace
bindkey '^[[3;3~' kill-word              # Option+Delete (forward)
bindkey '^[[1;3D' backward-word          # Option+Left
bindkey '^[[1;3C' forward-word           # Option+Right
bindkey '^U' backward-kill-line           # Ctrl+U — delete to start of line
bindkey '^[^H' backward-kill-line         # Option+Shift+Backspace
bindkey '\e^M' self-insert                # Option+Enter — insert newline (multiline editing)
ZSHRC

# Replace tmux toggle placeholder with actual value
sed_inplace "s/__TMUX_TOGGLE__/$TMUX_TOGGLE/" ~/.zshrc

# --- 10. Starship config ---
mkdir -p ~/.config
cat > ~/.config/starship.toml << 'STARSHIP'
format = """
$directory$git_branch$git_status$bun$python$rust$cmd_duration
$character"""

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"

[directory]
truncation_length = 3
style = "bold cyan"

[git_branch]
symbol = " "
style = "bold purple"

[git_status]
style = "bold red"

[cmd_duration]
min_time = 2_000
show_milliseconds = false
style = "bold yellow"

[bun]
symbol = "🥟 "

[python]
symbol = " "

[rust]
symbol = " "
STARSHIP

# --- 11. Optional Nerd Font ---
echo ""
read -p "🔤 Install Monaspace Nerd Font? (icons for Starship + dev tools) [y/N] " -n 1 -r INSTALL_FONT < /dev/tty
echo ""
if [[ $INSTALL_FONT =~ ^[Yy]$ ]]; then
  if $IS_MACOS; then
    brew install --cask font-monaspice-nerd-font
  else
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Monaspace.tar.xz"
    echo "   Downloading Monaspace Nerd Font..."
    curl -fsSL "$FONT_URL" -o /tmp/Monaspace.tar.xz
    tar -xf /tmp/Monaspace.tar.xz -C "$FONT_DIR"
    rm -f /tmp/Monaspace.tar.xz
    fc-cache -fv "$FONT_DIR" >/dev/null 2>&1
  fi
  echo "   ✅ Monaspace Nerd Font installed"
fi

# --- 12. Terminal.app profile (macOS only) ---
if $IS_MACOS; then
  echo ""
  read -p "🎨 Import Dmythro Terminal.app profile? (dark theme, MonaspiceNe NFM 14pt) [y/N] " -n 1 -r INSTALL_PROFILE < /dev/tty
  echo ""
  if [[ $INSTALL_PROFILE =~ ^[Yy]$ ]]; then
    curl -sL "${REPO_RAW}/Dmythro.terminal" -o /tmp/Dmythro.terminal
    open /tmp/Dmythro.terminal
    sleep 1
    defaults write com.apple.Terminal "Default Window Settings" -string "Dmythro"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Dmythro"
    echo "   ✅ Profile imported and set as default"
  fi
fi

# --- 13. Done ---
echo ""
if $IS_MACOS && [[ $INSTALL_PROFILE =~ ^[Yy]$ ]]; then
echo "⚠️  Manual step for Option+Arrow word jumping:"
echo "   Terminal.app → Settings → Profiles → Dmythro → Keyboard"
echo "   ✅ Check 'Use Option as Meta key'"
echo ""
fi
if $IS_MACOS; then
  echo "✅ Done! Quit Terminal.app (Cmd+Q) and reopen to see all changes."
else
  echo "✅ Done! Close and reopen your terminal to see all changes."
fi
echo ""
echo "📋 What you got:"
echo "   • Prefix history search — type 'git' then ↑ to search"
echo "   • Ctrl+R — fuzzy search all history (fzf)"
echo "   • Grey ghost suggestions — → to accept (fish-style)"
echo "   • Syntax highlighting — commands turn green/red as you type"
echo "   • Starship prompt — git branch, status, bun version, exec time"
echo "   • Option+← / Option+→ for word jumping"
echo "   • Option+Delete stops at /, ., - (macOS-like word boundaries)"
echo "   • Option+Enter for multiline commands (useful with code agents)"
echo "   • Tab/window title shows current dir and command"
if $IS_MACOS && [[ $INSTALL_PROFILE =~ ^[Yy]$ ]]; then
echo "   • Dark theme with MonaspiceNe NFM 14pt"
fi
if [[ $INSTALL_FONT =~ ^[Yy]$ ]]; then
if $IS_MACOS && [[ $INSTALL_PROFILE =~ ^[Yy]$ ]]; then
echo "   • Monaspace Nerd Font installed (already set in profile)"
elif $IS_MACOS; then
echo "   • Monaspace Nerd Font installed — set it in Terminal.app:"
echo "     Settings > Profiles > Font > Change > MonaspiceNe Nerd Font"
else
echo "   • Monaspace Nerd Font installed to ~/.local/share/fonts"
fi
fi
if [[ $INSTALL_TMUX =~ ^[Yy]$ ]]; then
echo ""
echo "   tmux (Prefix = Ctrl+B):"
echo "   • Auto-starts per session — set USE_TMUX=false in ~/.zshrc to disable"
echo "   • Mouse: drag to copy (goes to clipboard), drag borders to resize, scroll to browse"
echo "   • Prefix + |    split vertical"
echo "   • Prefix + -    split horizontal"
echo "   • Prefix + hjkl navigate panes"
echo "   • Prefix + HJKL resize panes (arrow keys unbound — no zsh conflicts)"
echo "   • Prefix + z    zoom/unzoom pane"
echo "   • Prefix + x    close pane"
echo "   • Prefix + c    new window  •  Prefix + n/p  next/prev window"
if $IS_MACOS; then
echo "   • Note: Cmd+D is Terminal.app's own split (horizontal only, shared session) — use tmux instead"
fi
fi
if [[ $INSTALL_DEV =~ ^[Yy]$ ]]; then
echo "   • Dev tools: gh, bun, ripgrep (rg), fd, zoxide (z), delta"
echo "   • fzf uses rg/fd for faster file/dir search"
echo "   • z — smart cd that learns your frequent directories"
echo "   • git diff/log now uses delta with syntax highlighting"
fi
echo ""
echo "   🤖 AI coding agents — install any when ready:"
if $IS_MACOS; then
echo "      brew install opencode          # open-source terminal agent"
echo "      brew install --cask claude-code # Anthropic"
echo "      brew install --cask codex       # OpenAI (open source)"
echo "      brew install gemini-cli         # Google (open source)"
echo "      brew install aider              # multi-model pair programming"
else
echo "      npm install -g @anthropic-ai/claude-code  # Anthropic"
echo "      npm install -g @openai/codex              # OpenAI (open source)"
echo "      pip install aider-chat                    # multi-model pair programming"
echo "      # OpenCode: see https://opencode.ai"
echo "      # Gemini CLI: see https://github.com/google-gemini/gemini-cli"
fi
echo ""
if $IS_LINUX && [[ "$SHELL" != *"/zsh" ]]; then
echo "⚠️  Your default shell is not zsh. Run this to switch:"
echo "   chsh -s \$(which zsh)"
echo ""
fi
if $IS_MACOS; then
echo "💡 To use on another Mac, run:"
else
echo "💡 To use on another machine, run:"
fi
echo "   curl -sL https://raw.githubusercontent.com/dmythro/terminal-setup/main/setup-terminal.sh | bash"
