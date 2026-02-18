#!/bin/bash
# =============================================================================
# macOS Terminal Setup
# Run: curl -sL https://raw.githubusercontent.com/dmythro/terminal-setup/main/setup-terminal.sh | bash
# =============================================================================

set -e

REPO_RAW="https://raw.githubusercontent.com/dmythro/terminal-setup/main"

echo "🚀 Setting up terminal..."

# --- 1. Install Homebrew if missing ---
if ! command -v brew &>/dev/null; then
  echo "📦 Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- 2. Core packages ---
echo "📦 Installing core packages..."
brew install fzf zsh-autosuggestions zsh-syntax-highlighting zsh-completions starship
chmod go-w "$(brew --prefix)/share/zsh-completions" "$(brew --prefix)/share"

# --- 3. Optional tmux ---
echo ""
read -p "📦 Install tmux for split panes? (auto-starts per session) [y/N] " -n 1 -r INSTALL_TMUX < /dev/tty
echo ""
if [[ $INSTALL_TMUX =~ ^[Yy]$ ]]; then
  brew install tmux
  echo "   ✅ tmux installed"
fi

# --- 4. Optional dev tools ---
echo ""
read -p "📦 Install dev tools? (gh, bun, ripgrep, fd, zoxide, delta) [y/N] " -n 1 -r INSTALL_DEV < /dev/tty
echo ""
if [[ $INSTALL_DEV =~ ^[Yy]$ ]]; then
  brew install gh bun ripgrep fd zoxide git-delta
  echo "   ✅ Dev tools installed"
fi

# --- 5. AI coding agents (listed in summary, not installed) ---

# --- 6. Install fzf key bindings ---
yes | $(brew --prefix)/opt/fzf/install --key-bindings --completion --no-update-rc 2>/dev/null || true

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

# --- Window titles (passed to Terminal.app tab) ---
set -g set-titles on
set -g set-titles-string "#{pane_title}"
setw -g automatic-rename on

# --- Clipboard (all copy operations go to macOS clipboard) ---
set -s copy-command "pbcopy"

# Mouse drag copies to clipboard
bind -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"

# Keyboard copy
bind -T copy-mode Enter send-keys -X copy-pipe-and-cancel "pbcopy"
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "pbcopy"

# --- Pane borders ---
set -g pane-border-style "fg=colour238"
set -g pane-active-border-style "fg=cyan"
TMUX
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

# --- Homebrew ---
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true

# --- Local binaries (claude, etc.) ---
export PATH="$HOME/.local/bin:$PATH"

# --- tmux auto-start ---
# Set USE_TMUX=false in ~/.zshrc to disable tmux auto-start
USE_TMUX=__TMUX_TOGGLE__
if [[ "$USE_TMUX" == "true" ]] && command -v tmux &>/dev/null && [[ -z "$TMUX" ]] && [[ "$TERM_PROGRAM" == "Apple_Terminal" || "$TERM_PROGRAM" == "iTerm.app" ]]; then
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
# Extra completions from zsh-completions
FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# --- Plugins ---
# Fish-like autosuggestions (grey ghost text, → to accept)
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Syntax highlighting (commands turn green/red as you type)
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# fzf fuzzy search (Ctrl+R for history, Ctrl+T for files)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9,fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9,info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6,marker:#ff79c6'

# Use ripgrep/fd with fzf if available
command -v rg &>/dev/null && export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
command -v fd &>/dev/null && export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'

# --- Zoxide (smart cd) ---
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# --- Starship prompt ---
eval "$(starship init zsh)"

# --- True color support (macOS 26+) ---
if [[ "$(sw_vers -productVersion 2>/dev/null)" == 26.* ]]; then
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
sed -i '' "s/__TMUX_TOGGLE__/$TMUX_TOGGLE/" ~/.zshrc

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
  brew install --cask font-monaspice-nerd-font
  echo "   ✅ Monaspace Nerd Font installed"
fi

# --- 12. Terminal.app profile (optional) ---
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

# --- 13. Done ---
echo ""
if [[ $INSTALL_PROFILE =~ ^[Yy]$ ]]; then
echo "⚠️  Manual step for Option+Arrow word jumping:"
echo "   Terminal.app → Settings → Profiles → Dmythro → Keyboard"
echo "   ✅ Check 'Use Option as Meta key'"
echo ""
fi
echo "✅ Done! Quit Terminal.app (Cmd+Q) and reopen to see all changes."
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
if [[ $INSTALL_PROFILE =~ ^[Yy]$ ]]; then
echo "   • Dark theme with MonaspiceNe NFM 14pt"
fi
if [[ $INSTALL_FONT =~ ^[Yy]$ ]]; then
if [[ $INSTALL_PROFILE =~ ^[Yy]$ ]]; then
echo "   • Monaspace Nerd Font installed (already set in profile)"
else
echo "   • Monaspace Nerd Font installed — set it in Terminal.app:"
echo "     Settings > Profiles > Font > Change > MonaspiceNe Nerd Font"
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
echo "   • Note: Cmd+D is Terminal.app's own split (horizontal only, shared session) — use tmux instead"
fi
if [[ $INSTALL_DEV =~ ^[Yy]$ ]]; then
echo "   • Dev tools: gh, bun, ripgrep (rg), fd, zoxide (z), delta"
echo "   • fzf uses rg/fd for faster file/dir search"
echo "   • z — smart cd that learns your frequent directories"
echo "   • git diff/log now uses delta with syntax highlighting"
fi
echo ""
echo "   🤖 AI coding agents — install any when ready:"
echo "      brew install opencode          # open-source terminal agent"
echo "      brew install --cask claude-code # Anthropic"
echo "      brew install --cask codex       # OpenAI (open source)"
echo "      brew install gemini-cli         # Google (open source)"
echo "      brew install aider              # multi-model pair programming"
echo ""
echo "💡 To use on another Mac, run:"
echo "   curl -sL https://raw.githubusercontent.com/dmythro/terminal-setup/main/setup-terminal.sh | bash"
