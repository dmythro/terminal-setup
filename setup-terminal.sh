#!/bin/bash
# ============================================================
# terminal-setup — macOS terminal setup
# https://github.com/dmythro/terminal-setup
# ============================================================

set -e

REPO_RAW="https://raw.githubusercontent.com/dmythro/terminal-setup/main"

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
    echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dmythro/terminal-setup/main/setup-terminal.sh)"'
    echo "   Or run non-interactively with -y:"
    echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dmythro/terminal-setup/main/setup-terminal.sh)" -- -y'
    exit 1
  fi
fi

# --- Welcome banner ---
echo "terminal-setup — macOS terminal setup"
echo "https://github.com/dmythro/terminal-setup"
echo ""
echo "⚠️  This overwrites ~/.zshrc and ~/.config/starship.toml without backup"
echo "   (plus ~/.tmux.conf or ~/.config/herdr/config.toml if you pick that"
echo "   multiplexer). ~/.zshenv and ~/.zprofile are safe — only a marked"
echo "   block is managed; everything else in them is preserved."
if [[ "$YES_MODE" != "true" ]]; then
  read -p "   Continue? [Y/n] " -n 1 -r CONTINUE < /dev/tty
  echo ""
  if [[ $CONTINUE =~ ^[Nn]$ ]]; then
    echo "   Aborted — nothing was changed."
    exit 0
  fi
fi

# Homebrew 6.0 made "ask mode" the default: `brew install` prints the plan and
# waits for y/n whenever dependencies are involved. Every install below already
# sits behind our own prompt, so suppress the second confirmation. Ignored by
# Homebrew < 6.0.
export HOMEBREW_NO_ASK=1

# --- 1. Install Homebrew if missing ---
if ! command -v brew &>/dev/null; then
  echo "📦 Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# Resolve once — /opt/homebrew on Apple Silicon, /usr/local on Intel.
BREW_PREFIX="$(brew --prefix)"

# Install formulae one at a time, tolerating the ones that can't be installed.
#
# Two reasons this isn't just `brew install a b c`:
#   1. A formula already installed from a different tap makes `brew install`
#      fail outright — e.g. bun from oven-sh/bun shadows homebrew/core/bun:
#      "Formulae with the same name from different taps cannot be installed at
#      the same time." The user already has the package; that should not be an
#      error.
#   2. With `set -e`, any such failure aborted the entire run *before any config
#      was written*, which is the worst possible place to stop — packages half
#      installed and no ~/.zshrc.
#
# Already-installed formulae are skipped rather than upgraded: this script sets
# up a terminal, it has no business forcing version bumps on packages you manage.
BREW_SKIPPED=()
BREW_FAILED=()
brew_install() {
  local pkg
  for pkg in "$@"; do
    if brew list --formula --versions "$pkg" &>/dev/null; then
      BREW_SKIPPED+=("$pkg")
      continue
    fi
    if ! brew install "$pkg"; then
      BREW_FAILED+=("$pkg")
      echo "   ⚠️  $pkg could not be installed — continuing without it"
    fi
  done
}

# --- 2. Core packages ---
echo "📦 Installing core packages..."
brew_install fzf zsh-autosuggestions zsh-syntax-highlighting zsh-completions starship
# compinit refuses group-writable fpath directories with an interactive
# "insecure directories" prompt on every shell start, so fix perms on anything
# .zshrc puts in fpath. Two separate statements: share/ needs the fix even when
# zsh-completions failed to install (its subdirectory then doesn't exist, and
# an unguarded chmod on a missing path would abort the run under `set -e`).
[[ -d "${BREW_PREFIX}/share" ]] && chmod go-w "${BREW_PREFIX}/share" || true
[[ -d "${BREW_PREFIX}/share/zsh-completions" ]] &&
  chmod go-w "${BREW_PREFIX}/share/zsh-completions" || true

# --- 3. Optional multiplexer (none / herdr / tmux) ---
#
# A multiplexer does three separable jobs: layout (tabs/splits), persistence
# (detach/reattach), and agent-state awareness. Warp already does layout and
# agent notifications natively, so a multiplexer there is redundant — the
# auto-start in .zshrc below skips Warp and editor terminals for that reason.
echo ""
if [[ "$YES_MODE" == "true" ]]; then
  MUX=none
else
  echo "🖥  Terminal multiplexer — persistent sessions, tabs and splits in one window:"
  echo "     1) none   — your terminal already does tabs (default; right choice for Warp)"
  echo "     2) herdr  — agent-aware: sidebar + notifications for Claude Code, Codex, etc."
  echo "     3) tmux   — the classic; pick this if you also use it on remote servers"
  read -p "   Choose [1/2/3] " -n 1 -r MUX_CHOICE < /dev/tty
  echo ""
  case "$MUX_CHOICE" in
    2) MUX=herdr ;;
    3) MUX=tmux ;;
    *) MUX=none ;;
  esac
fi

case "$MUX" in
  herdr|tmux)
    brew_install "$MUX"
    if command -v "$MUX" &>/dev/null; then
      echo "   ✅ $MUX ready"
    else
      # Config still gets written; the .zshrc auto-start guard checks for the
      # binary, so nothing breaks — it just won't start until you install it.
      echo "   ⚠️  $MUX is not available — install it later with: brew install $MUX"
    fi
    ;;
  *)
    echo "   ⏭  No multiplexer — using your terminal's own tabs"
    ;;
esac

# --- 4. Optional dev tools ---
echo ""
if [[ "$YES_MODE" == "true" ]]; then
  INSTALL_DEV=y
  echo "📦 Installing dev tools (auto-yes)..."
else
  read -p "📦 Install dev tools? (gh, bun, ripgrep, fd, zoxide, delta) [y/N] " -n 1 -r INSTALL_DEV < /dev/tty
  echo ""
fi
if [[ $INSTALL_DEV =~ ^[Yy]$ ]]; then
  brew_install gh bun ripgrep fd zoxide git-delta
  echo "   ✅ Dev tools done"
fi

# --- 5. AI coding agents (listed in summary, not installed) ---

# --- 6. fzf shell integration ---
# Nothing to install: modern fzf ships `fzf --zsh`, sourced from .zshrc below.
# (The old ~/.fzf.zsh install script is legacy and no longer in brew's caveats.)

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
if [[ "$MUX" == "tmux" ]]; then
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

# --- Clear current pane: clear screen + wipe scrollback ---
bind -n C-k send-keys C-l \; clear-history

# --- Auto-destroy session on detach (no orphaned sessions) ---
set -g destroy-unattached on

# --- Pane borders ---
set -g pane-border-style "fg=colour238"
set -g pane-active-border-style "fg=cyan"
TMUX
# Reload config if inside tmux (new settings take effect without restart)
[[ -n "$TMUX" ]] && tmux source-file ~/.tmux.conf 2>/dev/null || true
fi

# --- 8b. Write herdr config (if herdr selected) ---
if [[ "$MUX" == "herdr" ]]; then
echo "📝 Writing ~/.config/herdr/config.toml..."
mkdir -p ~/.config/herdr
cat > ~/.config/herdr/config.toml << 'HERDR'
# =============================================================================
# herdr Config — minimal chrome, agent notifications
# Validate changes with: herdr config check   •   Reload: Ctrl+B then Shift+R
# =============================================================================

# Notification setup is configured below, so skip the first-run wizard.
onboarding = false

[theme]
# Matches the Dracula theme used by fzf and delta elsewhere in this setup.
name = "dracula"

[theme.custom]
# Let herdr's panels inherit the terminal background instead of painting
# their own — keeps it visually flush with the Terminal.app profile.
panel_bg = "reset"

[update]
# herdr is installed via Homebrew, so let `brew upgrade` own the version
# rather than having herdr nag about updating itself.
version_check = false

[terminal]
# "auto" = login shells on macOS, so ~/.zprofile PATH ordering applies in panes.
shell_mode = "auto"
# New panes/tabs inherit the current directory.
new_cwd = "follow"

[ui]
# --- Minimal chrome: no borders, no gaps, no tab bar until there are 2 tabs ---
pane_borders = false
pane_gaps = false
hide_tab_bar_when_single_tab = true

# --- Agent sidebar: narrow status rail, Ctrl+B then B expands it ---
# The sidebar has no auto-show behaviour — unlike the tab bar above, it never
# appears on its own however many agents are running. So "hidden" means you'd
# have to remember it exists; "compact" keeps a ~2-3 column rail of agent-state
# dots visible instead. Set sidebar_collapsed_mode = "hidden" for zero width,
# or sidebar_start_collapsed = false to start fully expanded.
sidebar_start_collapsed = true
sidebar_collapsed_mode = "compact"

# Drag to select copies straight to the clipboard (matches the tmux config).
copy_on_select = true

[ui.toast]
# Agent state changes become real macOS notifications — the reason to run
# herdr under Terminal.app at all. Use "herdr" for in-app toasts instead.
delivery = "system"

[keys]
# herdr ships `switch_workspace` unset, so out of the box there is no direct
# chord for workspaces at all — Prefix + 1..9 switches *tabs*, and if each
# workspace holds a single tab that looks like nothing happening. The only
# routes would be the picker (Prefix + w) or navigate mode (Prefix + g).
# This is herdr's own suggested binding for it.
switch_workspace = "prefix+shift+1..9"

# =============================================================================
# Keys (defaults unless listed above — prefix is Ctrl+B, same as tmux)
#   Prefix + c        new tab            Prefix + n / p     next / prev tab
#   Prefix + 1..9     switch tab         Prefix + Shift+1..9 switch workspace
#   Prefix + Shift+N  new workspace      Prefix + w         workspace picker
#   Prefix + Shift+W  rename workspace   Prefix + g         navigate mode
#   Prefix + minus    split down         Prefix + v         split right
#   Prefix + x        close pane         Prefix + z         zoom pane
#   Prefix + hjkl     navigate panes     Prefix + r         resize mode
#   Prefix + b        toggle sidebar     Prefix + q         detach
#   Prefix + ?        help (authoritative — check here first)
#
# To switch tabs without the prefix, uncomment (terminal-dependent):
# [keys.indexed]
# tabs = "ctrl"
# =============================================================================
HERDR

# Validate before reloading. `herdr config check` catches TOML errors and
# unknown keys; herdr itself would otherwise accept the file, fall back to
# defaults for anything invalid, and only warn at startup — leaving the config
# silently not doing what it says. (Note: it does not validate theme names.)
# The command -v guard keeps a missing binary (tolerated install failure) from
# being misreported as a validation failure — exit 127 would land in the else
# branch and tell the user to run a command that doesn't exist.
if ! command -v herdr &>/dev/null; then
  echo "   ⏭  Config written; herdr isn't installed yet, so it was not validated."
  echo "      After installing, check it with: herdr config check"
elif herdr config check &>/dev/null; then
  # Reload if a herdr server is already running
  herdr server reload-config &>/dev/null || true
else
  echo "   ⚠️  ~/.config/herdr/config.toml did not validate — run: herdr config check"
fi
fi

# --- 8c. Optional Claude Code state hook for herdr ---
# Only offered when Claude Code is actually installed. The hook reports exact
# blocked/working/done state instead of herdr guessing from terminal output.
# Requires the herdr binary too — its install may have failed above, and the
# summary points at `herdr integration install claude` for catching up later.
HERDR_HOOK_INSTALLED=false
if [[ "$MUX" == "herdr" ]] && command -v herdr &>/dev/null && command -v claude &>/dev/null; then
  echo ""
  if [[ "$YES_MODE" == "true" ]]; then
    INSTALL_HERDR_HOOK=n
  else
    read -p "🔔 Claude Code detected — install herdr's state hook? (writes ~/.claude/hooks) [y/N] " -n 1 -r INSTALL_HERDR_HOOK < /dev/tty
    echo ""
  fi
  if [[ $INSTALL_HERDR_HOOK =~ ^[Yy]$ ]]; then
    if herdr integration install claude; then
      # Record that *we* installed it. The hook is always named
      # herdr-agent-state.sh, so reset cannot otherwise tell a hook this script
      # installed from one the user installed themselves — and without this
      # marker `reset -y` would silently remove theirs. Kept outside
      # ~/.config/herdr because reset deletes that directory.
      mkdir -p ~/.local/state/setup-terminal
      touch ~/.local/state/setup-terminal/herdr-claude-hook
      HERDR_HOOK_INSTALLED=true
      echo "   ✅ Claude Code state hook installed"
    else
      echo "   ⚠️  Hook install failed — retry later with: herdr integration install claude"
    fi
  fi
fi

# --- 9a. Write PATH block to .zshenv + .zprofile ---
#
# Both files are needed, and the split is not redundant:
#   ~/.zshenv   — sourced by EVERY zsh, including the non-interactive shells AI
#                 coding agents spawn. Without it, `zsh -c` can't find brew.
#   ~/.zprofile — macOS ships an /etc/zprofile that runs `path_helper`, which
#                 rebuilds PATH from /etc/paths and pushes everything ~/.zshenv
#                 prepended BELOW /usr/bin. That runs after ~/.zshenv, so a
#                 login shell (what Terminal.app gives you) would otherwise get
#                 Apple's git/python ahead of Homebrew's. Re-assert after it.
#
# `typeset -U path fpath` keeps entries unique, so applying the block twice is
# idempotent rather than duplicating every entry.

emit_path_block() {
  cat << PATHBLOCK
# BEGIN setup-terminal.sh
$1
typeset -U path fpath
[[ -x ${BREW_PREFIX}/bin/brew ]] && eval "\$(${BREW_PREFIX}/bin/brew shellenv 2>/dev/null)"
path=("\$HOME/.local/bin" ${BREW_PREFIX}/bin ${BREW_PREFIX}/sbin \$path)
export PATH
# END setup-terminal.sh
PATHBLOCK
}

# Echo $1 with any complete BEGIN/END setup-terminal.sh block removed.
# Deliberately not `sed '/BEGIN/,/END/d'`: a sed range with no closing match
# deletes to end of file, so a hand-edited or truncated dotfile that kept the
# BEGIN marker but lost the END would lose everything after it. awk buffers the
# block and puts it back untouched when no END turns up.
strip_path_block() {
  awk '
    /^# BEGIN setup-terminal\.sh$/ && !inblk { inblk = 1; buf = $0 ORS; next }
    inblk && /^# END setup-terminal\.sh$/    { inblk = 0; buf = ""; next }
    inblk                                    { buf = buf $0 ORS; next }
                                             { print }
    END { if (inblk) printf "%s", buf }
  ' "$1"
}

install_path_block() {
  local target="$1" comment="$2" tmp
  touch "$target"
  tmp="$(mktemp "${target}.tmp.XXXXXX")"
  emit_path_block "$comment" > "$tmp"
  # Append the user's own content, dropping any block a previous run wrote so
  # re-running picks up changes. Filtering on the way out (rather than `sed -i`)
  # keeps symlinked dotfiles — chezmoi, stow — intact.
  strip_path_block "$target" >> "$tmp"
  if [[ -L "$target" ]]; then
    cat "$tmp" > "$target"
    rm -f "$tmp"
  else
    mv "$tmp" "$target"
  fi
}

echo "📝 Updating ~/.zshenv and ~/.zprofile..."
install_path_block ~/.zshenv \
  '# PATH for ALL zsh invocations, including the non-interactive shells
# that AI coding agents spawn.'
install_path_block ~/.zprofile \
  '# Re-assert PATH after macOS /etc/zprofile runs path_helper, which would
# otherwise demote Homebrew and ~/.local/bin below /usr/bin.'

# --- 9b. Write .zshrc ---
echo "📝 Writing ~/.zshrc..."

# Multiplexer to auto-start (none / herdr / tmux)
MUX_TOGGLE="$MUX"

cat > ~/.zshrc << 'ZSHRC'
# =============================================================================
# Zsh Config
# =============================================================================

# --- Multiplexer auto-start ---
# Values: none | herdr | tmux. Edit the default below to change it permanently,
# or override per-shell from the environment: `USE_MUX=none zsh` — hence the
# `:-` default rather than a plain assignment, which would clobber it.
#
# Opt-out rather than opt-in, so it works in Terminal.app, iTerm, Ghostty,
# WezTerm, Kitty, Alacritty and anything else without needing an entry here.
# Two skip lists, because not every terminal is identifiable the same way:
#
#   NO_MUX_TERMS — matched against $TERM_PROGRAM
#     WarpTerminal                already has tabs, splits, agent notifications
#     vscode / zed / JetBrains    editor-embedded, tied to the editor's panel
#
#   NO_MUX_VARS — marker variables, for apps that don't report a distinct
#     $TERM_PROGRAM. cmux is built on libghostty and reports as Ghostty, so
#     $TERM_PROGRAM can't distinguish it; its docs name CMUX_WORKSPACE_ID as
#     the supported way to detect it. Both cmux and Superset are agent-first
#     terminals with their own vertical tabs and notifications, so a
#     multiplexer inside them is the Warp situation again.
USE_MUX=${USE_MUX:-__MUX_TOGGLE__}
NO_MUX_TERMS=(WarpTerminal vscode zed JetBrains-JediTerm)
NO_MUX_VARS=(CMUX_WORKSPACE_ID SUPERSET_WORKSPACE_NAME)

_mux_blocked=0
[[ -n "$TERM_PROGRAM" ]] && (( ${NO_MUX_TERMS[(Ie)$TERM_PROGRAM]} )) && _mux_blocked=1
for _v in $NO_MUX_VARS; do [[ -n "${(P)_v}" ]] && _mux_blocked=1; done

# SSH sessions are skipped too: a fresh session per connection silently piles
# up detached sessions server-side, and anyone who wants tmux over SSH already
# starts it deliberately (usually to attach, not to spawn).
if (( ! _mux_blocked )) && [[ -o interactive ]] && [[ -t 1 ]] && [[ -z "$CI" ]] &&
   [[ -z "$SSH_TTY" && -z "$SSH_CONNECTION" ]] &&
   [[ -z "$TMUX" && -z "$HERDR_ENV" ]]; then
  case "$USE_MUX" in
    tmux)  command -v tmux  &>/dev/null && tmux new-session ;;
    herdr) command -v herdr &>/dev/null && herdr ;;
  esac
fi
unset _mux_blocked _v

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

# --- Homebrew prefix ---
# Exported by ~/.zshenv via `brew shellenv`; the fallback only runs if that
# file is missing. Avoids three `brew --prefix` subprocesses per shell start.
: ${HOMEBREW_PREFIX:=$(brew --prefix 2>/dev/null)}

# --- Tab completion ---
# Extra completions from zsh-completions
fpath=($HOMEBREW_PREFIX/share/zsh-completions $fpath)
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# --- Plugins ---
# Fish-like autosuggestions (grey ghost text, → to accept)
[[ -r $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
  source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Syntax highlighting (commands turn green/red as you type)
[[ -r $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
  source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# fzf fuzzy search (Ctrl+R for history, Ctrl+T for files)
command -v fzf &>/dev/null && source <(fzf --zsh)
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9,fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9,info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6,marker:#ff79c6'

# Use ripgrep/fd with fzf if available
command -v rg &>/dev/null && export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
command -v fd &>/dev/null && export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'

# --- Zoxide (smart cd) ---
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# --- Starship prompt ---
# Guarded like every other tool here: setup tolerates a failed install, so a
# missing starship must mean the default prompt, not an error on every shell.
command -v starship &>/dev/null && eval "$(starship init zsh)"

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

# --- Ctrl+K — clear screen + scrollback (non-tmux fallback) ---
# Use zsh's own clear-screen (what Ctrl+L runs) rather than printing \e[2J:
# it clears the screen *and* records that the screen is now blank, so the
# prompt repaints from scratch. Clearing behind ZLE's back leaves its model
# stale and the next redraw emits cursor moves relative to content that is no
# longer there — stray glyphs left over the screen. \e[3J then drops the
# scrollback (terminfo's `clear` doesn't), after `zle -R` has flushed the
# repaint so the two writes can't interleave.
function clear-screen-and-scrollback() {
  zle .clear-screen
  zle -R
  printf '\e[3J' >"$TTY"
}
zle -N clear-screen-and-scrollback
bindkey '^K' clear-screen-and-scrollback
ZSHRC

# Replace multiplexer placeholder with actual value
sed -i '' "s/__MUX_TOGGLE__/$MUX_TOGGLE/" ~/.zshrc

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
if [[ "$YES_MODE" == "true" ]]; then
  INSTALL_FONT=n
else
  read -p "🔤 Install Monaspace Nerd Font? (icons for Starship + dev tools) [y/N] " -n 1 -r INSTALL_FONT < /dev/tty
  echo ""
fi
# FONT_INSTALLED feeds the closing summary — the prompt answer alone isn't
# enough, since a failed cask install is tolerated and the warning about it
# will have scrolled away by the time the summary prints.
FONT_INSTALLED=false
if [[ $INSTALL_FONT =~ ^[Yy]$ ]]; then
  if brew list --cask --versions font-monaspice-nerd-font &>/dev/null; then
    FONT_INSTALLED=true
    echo "   ✔︎ Monaspace Nerd Font already installed"
  elif brew install --cask font-monaspice-nerd-font; then
    FONT_INSTALLED=true
    echo "   ✅ Monaspace Nerd Font installed"
  else
    echo "   ⚠️  Monaspace Nerd Font could not be installed — continuing"
  fi
fi

# --- 12. Terminal.app profile (optional) ---
echo ""
if [[ "$YES_MODE" == "true" ]]; then
  INSTALL_PROFILE=n
else
  read -p "🎨 Import Dmythro Terminal.app profile? (dark theme, MonaspiceNe NFM 14pt) [y/N] " -n 1 -r INSTALL_PROFILE < /dev/tty
  echo ""
fi
if [[ $INSTALL_PROFILE =~ ^[Yy]$ ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ "${BASH_SOURCE[0]}" == /* ]] && [[ -f "${SCRIPT_DIR}/Dmythro.terminal" ]]; then
    cp "${SCRIPT_DIR}/Dmythro.terminal" /tmp/Dmythro.terminal
  else
    curl -fsSL "${REPO_RAW}/Dmythro.terminal" -o /tmp/Dmythro.terminal
  fi
  # Overwrite, don't accumulate: Terminal.app never replaces an existing
  # profile on import — a re-run's import lands as "Dmythro 1", "Dmythro 2", …
  # while the default keeps pointing at the stale original. Delete previous
  # copies first so the import gets the clean name. All profile surgery goes
  # through AppleScript, which edits Terminal's *in-memory* settings; a
  # `defaults write` would be silently clobbered when Terminal.app quits and
  # flushes its cached prefs back to disk.
  osascript -e '
    tell application "Terminal"
      repeat with s in (get settings sets)
        set n to name of s
        if n is "Dmythro" or n starts with "Dmythro " then delete s
      end repeat
    end tell' &>/dev/null || true

  open /tmp/Dmythro.terminal

  # Wait for Terminal.app to import the profile (up to 5 seconds)
  PROFILE_IMPORTED=false
  for i in {1..10}; do
    if [[ "$(osascript -e 'tell application "Terminal" to exists settings set "Dmythro"' 2>/dev/null)" == "true" ]]; then
      PROFILE_IMPORTED=true
      break
    fi
    sleep 0.5
  done

  if [[ "$PROFILE_IMPORTED" == "true" ]]; then
    osascript -e '
      tell application "Terminal"
        set default settings to settings set "Dmythro"
        set startup settings to settings set "Dmythro"
      end tell' &>/dev/null || true
    echo "   ✅ Profile imported and set as default (previous copies replaced)"
  else
    echo "   ⚠️  Profile import timed out. Open /tmp/Dmythro.terminal manually,"
    echo "      then set it as default in Terminal → Settings → Profiles."
  fi
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
if (( ${#BREW_SKIPPED[@]} )); then
  echo ""
  echo "   ⏭  Already installed, left untouched: ${BREW_SKIPPED[*]}"
  echo "      (upgrade those yourself with: brew upgrade <name>)"
fi
if (( ${#BREW_FAILED[@]} )); then
  echo ""
  echo "   ⚠️  Could not install: ${BREW_FAILED[*]}"
  echo "      Everything else was still configured. A common cause is the same"
  echo "      formula existing in two taps — check with: brew info <name>"
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
if [[ $INSTALL_PROFILE =~ ^[Yy]$ ]]; then
echo "   • Dark theme with MonaspiceNe NFM 14pt"
fi
if [[ "$FONT_INSTALLED" == "true" ]]; then
if [[ $INSTALL_PROFILE =~ ^[Yy]$ ]]; then
echo "   • Monaspace Nerd Font installed (already set in profile)"
else
echo "   • Monaspace Nerd Font installed — set it in Terminal.app:"
echo "     Settings > Profiles > Font > Change > MonaspiceNe Nerd Font"
fi
elif [[ $INSTALL_FONT =~ ^[Yy]$ ]]; then
echo "   • Monaspace Nerd Font FAILED to install — retry with:"
echo "     brew install --cask font-monaspice-nerd-font"
fi
if [[ "$MUX" == "herdr" ]]; then
echo ""
echo "   herdr (Prefix = Ctrl+B):"
echo "   • Auto-starts in your terminal — set USE_MUX=none in ~/.zshrc to disable"
echo "   • Skipped in Warp and editor terminals (see NO_MUX_TERMS in ~/.zshrc)"
echo "   • Minimal chrome: no pane borders, tab bar hidden until you open a 2nd tab"
echo "   • Prefix + b    toggle the agent sidebar (blocked / working / done / idle)"
echo "   • Prefix + c    new tab  •  Prefix + n/p  next/prev  •  Prefix + 1..9  jump"
echo "   • Prefix + -    split down  •  Prefix + v  split right  •  Prefix + x  close"
echo "   • Prefix + hjkl navigate panes  •  Prefix + z  zoom  •  Prefix + r  resize"
echo "   • Prefix + q    detach (agents keep running)  •  Prefix + ?  help"
echo "   • Agent state changes raise macOS notifications"
echo "   • Config: ~/.config/herdr/config.toml — validate with 'herdr config check'"
if [[ "$HERDR_HOOK_INSTALLED" == "true" ]]; then
echo "   • Claude Code state hook installed — exact state, not output guessing"
elif command -v claude &>/dev/null; then
echo "   • For exact Claude Code state: herdr integration install claude"
fi
fi
if [[ "$MUX" == "tmux" ]]; then
echo ""
echo "   tmux (Prefix = Ctrl+B):"
echo "   • Auto-starts in your terminal — set USE_MUX=none in ~/.zshrc to disable"
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
echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dmythro/terminal-setup/main/setup-terminal.sh)"'
