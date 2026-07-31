# AGENTS.md

This file provides guidance to AI coding agents working on this repository.

## What This Is

A GitHub repo ([dmythro/terminal-setup](https://github.com/dmythro/terminal-setup)) containing a one-command macOS terminal setup script. Designed to be run via `/bin/bash -c "$(curl ...)"` on a fresh Mac (same pattern as Homebrew — downloads first, then executes with stdin connected to the terminal). Supports `-y`/`--yes` for non-interactive mode.

## Files

- `setup-terminal.sh` — Interactive setup script that installs packages and writes config files (`~/.zshenv`, `~/.zprofile`, `~/.zshrc`, `~/.tmux.conf`, `~/.config/herdr/config.toml`, `~/.config/starship.toml`)
- `reset-terminal.sh` — Interactive reset script that undoes setup-terminal.sh (removes configs, optionally uninstalls packages)
- `Dmythro.terminal` — Terminal.app profile plist (dark theme, MonaspiceNe NFM 14pt, 120x36)
- `README.md` — User-facing documentation with feature tables, multiplexer + agent comparison charts, keyboard shortcuts, and quick start
- `AGENTS.md` — This file (symlinked as `CLAUDE.md` for Claude Code compatibility)

## Script Structure

The script uses `set -e` and is sequential with interactive prompts (`read -p`). It writes config files inline using **quoted heredocs** (`cat > ~/.file << 'TAG'`) so variables aren't expanded during write. The multiplexer choice uses a `__MUX_TOGGLE__` placeholder in the zshrc heredoc, replaced via `sed -i ''` after writing — this is the only value that needs post-write substitution. (The PATH block in section 9a is the one *unquoted* heredoc, since it has to interpolate `$BREW_PREFIX`; `\$` escapes preserve the runtime variables.)

`REPO_RAW` (line 9) is used to download `Dmythro.terminal` from the repo at runtime (section 12).

Key sections: 1 Homebrew install → `BREW_PREFIX` resolution → 2 core packages (incl. zsh-completions) → 3 multiplexer choice (none/herdr/tmux) → 4 optional dev tools (incl. zoxide, delta) → 5 AI agents (summary text only, nothing installed) → 6 fzf note (no-op) → 7 delta git config → 8 tmux.conf → 8b herdr config.toml → 8c herdr Claude hook → 9a .zshenv + .zprofile (PATH) → 9b .zshrc (interactive config) → 10 starship.toml → 11 Nerd Font → 12 Terminal.app profile import → 13 summary output.

**PATH lives in BOTH `~/.zshenv` and `~/.zprofile`** — this is not redundant, and removing either one breaks a real case:

- `~/.zshenv` is sourced by *every* zsh, including the non-interactive shells AI coding agents spawn. Without it, `zsh -c` can't find brew.
- `~/.zprofile` is needed because macOS ships an `/etc/zprofile` that runs `path_helper`, which **rebuilds PATH from `/etc/paths` and demotes anything `~/.zshenv` prepended to below `/usr/bin`**. It runs *after* `~/.zshenv`, so a login shell (what Terminal.app gives you) would otherwise resolve Apple's `git`/`python3` ahead of Homebrew's. The `.zprofile` copy re-asserts the order after `path_helper`.

Both blocks are written by `install_path_block()` from a single `emit_path_block()` template, bracketed with `# BEGIN/END setup-terminal.sh` markers. The block starts with `typeset -U path fpath` so applying it twice dedupes instead of duplicating. `install_path_block()` **strips any previous block and rewrites it**, so re-running setup converges (matching how `.zshrc`/`.tmux.conf` are overwritten wholesale). It filters on the way out rather than using `sed -i`, which keeps symlinked dotfiles (chezmoi, stow) intact.

**Block removal uses awk, not `sed '/BEGIN/,/END/d'`** — in both `strip_path_block()` here and the matching loop in `reset-terminal.sh`. A sed range whose closing pattern never matches deletes through end of file, so a dotfile that kept the BEGIN marker but lost the END (hand-edited, truncated, partially copied) would lose everything after it. The awk version buffers the block and re-emits it untouched when no END appears. Don't "simplify" it back to sed.

**Symlinked dotfiles are never deleted or replaced.** Both scripts write through a symlink (`cat > "$target"`) rather than over it, reset's "delete if empty" step is gated on `[[ ! -L "$f" ]]`, and reset's removal of `~/.tmux.conf`, `~/.config/starship.toml`, and `~/.config/herdr/config.toml` empties a symlinked file (`: >`) instead of `rm`-ing the link node. A chezmoi/stow-managed `~/.zshenv` holding only the managed block ends up empty after cleanup — deleting it there would break the link the dotfile manager owns. An empty managed file is fine; a missing one is not.

Interactive-only config (completions, plugins, aliases, prompt) stays in `~/.zshrc`, which uses `$HOMEBREW_PREFIX` (exported by `brew shellenv` in `.zshenv`) instead of calling `brew --prefix` three times per shell start.

`reset-terminal.sh` mirrors this structure with per-section interactive prompts. It cleans setup-terminal.sh blocks from both `~/.zshenv` and `~/.zprofile` (preserving other content like cargo or OrbStack, and deleting a file only if the cleanup left it empty) and replaces `~/.zshrc` with a minimal version. Packages are left installed by default since they're inert without configs.

## Package Installation

**All formulae go through `brew_install()`, never a bare `brew install a b c`.** It installs one at a time, skips anything already present, and records failures in `BREW_FAILED` instead of letting them propagate. Two reasons, both learned the hard way:

- A formula already installed from a **different tap** makes `brew install` fail outright — `bun` from `oven-sh/bun` shadows `homebrew/core/bun`, and Homebrew refuses: *"Formulae with the same name from different taps cannot be installed at the same time."* The user already has the package; that is not an error condition.
- Combined with `set -e`, any such failure aborted the run **in section 4 — before a single config file was written**. Packages half-installed, no `~/.zshrc`. The worst place to stop.

Already-installed formulae are **skipped, not upgraded**. A terminal setup script has no business forcing version bumps on packages the user manages; skipped and failed names are both reported in the closing summary so nothing is silently swallowed.

Anything that touches a Homebrew path must tolerate the package being absent — e.g. the `chmod go-w` on `share/zsh-completions` is guarded by a `-d` test, since an unguarded `chmod` on a missing path aborts under `set -e`.

## Homebrew 6.0 Notes

- **Ask mode is the default.** `brew install`/`upgrade` print a plan and wait for `y/n` whenever dependencies are involved and both stdin and stdout are TTYs. Since the script runs from a terminal, this would prompt on nearly every install and would break `-y`. `setup-terminal.sh` exports `HOMEBREW_NO_ASK=1` up front; the flag equivalent (`brew install -y`) is avoided because it doesn't exist on Homebrew < 6.0, whereas an unknown env var is simply ignored.
- **`brew shellenv` no longer exports PATH directly** on macOS 14+. It emits `eval "$(PATH_HELPER_ROOT=<prefix> /usr/libexec/path_helper -s)"` and writes `<prefix>/etc/paths`. Don't assume its output contains a literal `export PATH=` line.
- **Tap trust**: third-party taps must be explicitly trusted and are no longer auto-tapped. The script only uses core formulae/casks, so nothing to do — but don't add a `brew tap` of a third-party tap without handling trust.
- **Intel timeline**: `x86_64` moves to Tier 3 (no new bottles) in September 2026. `BREW_PREFIX` is resolved via `brew --prefix` rather than hardcoding `/opt/homebrew`, so Intel still works while it lasts.

## fzf Shell Integration

Shell integration comes from `source <(fzf --zsh)` in `.zshrc` — not the legacy `$(brew --prefix)/opt/fzf/install` script and not `~/.fzf.zsh`. Homebrew's fzf caveats no longer mention the install script, and the `~/.fzf.zsh` it generates is now just a PATH guard plus that same `fzf --zsh` call. `reset-terminal.sh` still removes `~/.fzf.zsh` to clean up after older runs.

## Multiplexer (none / herdr / tmux)

Section 3 sets `MUX` to one of `none` (default) / `herdr` / `tmux` from a numbered prompt. Everything downstream branches on `"$MUX"` — there is no `INSTALL_TMUX` variable any more. The `.zshrc` heredoc carries a `__MUX_TOGGLE__` placeholder, replaced by `sed -i ''` after writing, that becomes `USE_MUX=<value>`.

**Auto-start is opt-out, not opt-in.** It runs in any terminal except those on the two skip lists in `.zshrc` — an allowlist would silently do nothing in Ghostty, WezTerm, Kitty, Alacritty and anything else not enumerated, which contradicts the README's claim that the setup works in any emulator. To exclude a terminal, add to a list rather than editing the condition.

`NO_MUX_TERMS` — matched against `$TERM_PROGRAM`:

- `WarpTerminal` — already has tabs, splits, and agent notifications; a multiplexer there only adds chrome and fights Warp's block model
- `vscode`, `zed`, `JetBrains-JediTerm` — editor-embedded terminals tied to the editor's own panel

`NO_MUX_VARS` — marker variables, for agent-first terminals that **can't be distinguished by `$TERM_PROGRAM`**:

- `CMUX_WORKSPACE_ID` — [cmux](https://github.com/manaflow-ai/cmux) is built on libghostty and reports as Ghostty, so a `TERM_PROGRAM` check would either miss it or wrongly exclude real Ghostty. Its docs name this variable as the supported detection method.
- `SUPERSET_WORKSPACE_NAME` — [Superset](https://superset.sh), same reasoning.

Both are standalone terminal *applications* (Homebrew casks) in the same category as Warp — they replace the terminal rather than running inside it. **Don't add them as options to the `MUX` prompt**; that's a category error. They belong only on the skip list.

Implementation notes: the `NO_MUX_TERMS` membership test is `(( ${NO_MUX_TERMS[(Ie)$TERM_PROGRAM]} ))` (zsh exact-match index lookup, 0 when absent), guarded by a `-n "$TERM_PROGRAM"` test first. `NO_MUX_VARS` is checked with `${(P)_v}` parameter-name expansion. The block ends with `unset _mux_blocked _v` so it exits 0 — a trailing non-zero status would paint the first Starship prompt red. Remaining guards: `-o interactive` and `-t 1` (skip piped/redirected shells), `-z "$CI"`, `-z "$SSH_TTY"` / `-z "$SSH_CONNECTION"` (no auto-start in SSH sessions — a new session per connection piles up detached sessions; the pre-multiplexer allowlist blocked this implicitly since `$TERM_PROGRAM` is unset over SSH), and `-z "$TMUX"` / `-z "$HERDR_ENV"` to prevent recursive nesting.

**The herdr nesting marker is `HERDR_ENV`, not `HERDR_SESSION`.** herdr's agent guide states "If `HERDR_ENV=1` is set in your environment, you are already running inside a Herdr pane", and herdr uses the same variable internally to refuse nested launches. Other `HERDR_*` names (`HERDR_SESSION`, `HERDR_PANE_ID`, `HERDR_SOCKET_PATH`) appear in the binary but are not the documented pane marker — don't substitute one of those.

herdr specifics:

- Config is `~/.config/herdr/config.toml`, written in section 8b. Validate any edit with `herdr config check` — note it validates TOML shape and known keys, but **not** theme names, so a typo'd theme still reports `ok`.
- Tuned for minimal chrome per the repo owner's preference: `pane_borders`/`pane_gaps` off, `hide_tab_bar_when_single_tab`, sidebar collapsed to `"hidden"`. `Prefix + B` toggles the sidebar; `sidebar_collapsed_mode = "compact"` is the always-visible-rail alternative.
- `[update] version_check = false` because Homebrew owns the binary — otherwise herdr nags about self-updating a brew-managed install.
- Section 8c offers `herdr integration install claude` **only when both `command -v herdr` and `command -v claude` succeed** — herdr's own install may have failed and been tolerated. The hook writes to `~/.claude/hooks/` plus entries in `~/.claude/settings.json`, which is why reset has to remove it through `herdr integration uninstall` rather than by deleting config files. The summary's "hook installed" line is gated on `HERDR_HOOK_INSTALLED` (set only when the install command succeeded), not on the prompt answer.
- **Ownership marker**: on a successful install, setup touches `~/.local/state/setup-terminal/herdr-claude-hook`, and reset removes the hook *only if that marker exists*. The hook file is always named `herdr-agent-state.sh`, so there is no way to distinguish one this script installed from one the user installed by hand — without the marker, `reset -y` would silently delete theirs. The marker deliberately lives outside `~/.config/herdr`, which reset deletes. Don't drop this check. Because hook removal must go through the herdr binary, reset also (a) removes the hook before section 5 uninstalls the herdr package — skipping the uninstall if hook removal fails — and (b) warns with recovery steps when the marker exists but the binary is already gone. Don't reorder section 5 ahead of these guards.
- The generated config is validated with `herdr config check` before `herdr server reload-config`. herdr otherwise accepts a bad file, falls back to defaults, and only warns at startup — so an invalid config would silently not apply.
- Valid integration targets come from `herdr integration install --help`; an unknown target exits 2. `gemini` is *not* one of them.
- `USE_MUX` is written as `USE_MUX=${USE_MUX:-<choice>}` so `USE_MUX=none zsh` overrides per-shell. A plain assignment would clobber an exported value.

## Conventions

- Config sections use `# --- N. Section Name ---` numbered comment style. **Sections inserted later take a letter suffix** — `8b`, `8c`, `9a`, `9b` in `setup-terminal.sh`, `4b` in `reset-terminal.sh` — rather than renumbering everything downstream. Reviewers flag this as inconsistent with the `N.` format; it's deliberate, and keeps diffs to the lines that actually changed.
- Summary output at the end lists all installed features with emoji bullets
- The summary is conditional — only shows sections for packages the user chose to install
- The script is destructive — it overwrites `~/.zshrc`, `~/.tmux.conf`, `~/.config/herdr/config.toml`, and `~/.config/starship.toml` without backup. Don't test on a machine with configs you want to keep. `~/.zshenv` and `~/.zprofile` are the exception: only the marked block is replaced, so unrelated content there survives. Setup states this up front and asks `Continue? [Y/n]` (default yes) before doing anything; `-y` skips the prompt but still prints the warning. Don't remove that notice.
- Optional prompts default to N. Only the dev-tools prompt is auto-accepted under `-y`; the multiplexer, herdr Claude hook, Nerd Font, and Terminal.app profile are all skipped in non-interactive mode because they change shell behavior or are visual preferences.

## Terminal Profile Notes

`Dmythro.terminal` already has `useOptionAsMetaKey` set to `true` in the plist. The script still shows a manual instruction for this (section 12) as a reminder, since Terminal.app may not always respect the plist value on import.

The profile also sets `noWarnProcesses` to `screen`, `tmux`, `herdr` — without it, quitting Terminal.app with a multiplexer running always shows the "terminate running processes?" dialog. Apple's built-in default list covers `screen`/`tmux` but not `herdr`, and **setting the key replaces the default list entirely**, so `screen` and `tmux` must stay listed alongside `herdr`.

## macOS 26 Support

The .zshrc detects macOS 26+ via `sw_vers -productVersion` and sets `COLORTERM=truecolor`. The tmux config uses `tmux-256color` with true color overrides (`Tc`). This enables full 24-bit color in Terminal.app on Tahoe. herdr needs nothing here — it renders through the host terminal and inherits its color support.

## AI Coding Agents

No AI agents are installed or prompted during setup. The final summary lists all available agents with their `brew install` commands for the user to run when ready:
- **OpenCode** (`brew install opencode`) — open source
- **Claude Code** (`brew install --cask claude-code`) — Anthropic
- **Codex** (`brew install --cask codex`) — OpenAI, open source
- **Gemini CLI** (`brew install gemini-cli`) — Google, open source
- **Aider** (`brew install aider`) — multi-model pair programming

The reset script still handles both formula and cask uninstalls for agents that were installed manually.
