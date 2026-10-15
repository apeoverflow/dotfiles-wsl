#!/usr/bin/env bash
# ~/dotfiles-wsl/install.sh — symlink every tracked file in home/ into $HOME,
# then register the Copilot CLI hooks.
# Idempotent: safe to re-run. Existing real files are backed up first; existing
# symlinks are just repointed. After this runs, editing e.g. ~/.zshrc edits the
# repo copy directly — no copying, just `git commit`.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DOTFILES/home"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

[[ -d "$SRC" ]] || { echo "no home/ dir in $DOTFILES" >&2; exit 1; }

linked=0 backed=0
while IFS= read -r f; do
  rel="${f#"$SRC"/}"
  target="$HOME/$rel"
  mkdir -p "$(dirname "$target")"

  # already the correct symlink? nothing to do
  if [[ -L "$target" && "$(readlink "$target")" == "$f" ]]; then
    continue
  fi
  # a real file/dir is in the way → back it up
  if [[ -e "$target" && ! -L "$target" ]]; then
    mkdir -p "$(dirname "$BACKUP/$rel")"
    mv "$target" "$BACKUP/$rel"
    backed=$((backed+1))
  fi
  ln -sfn "$f" "$target"
  linked=$((linked+1))
done < <(find "$SRC" -type f)

# Drop symlinks left behind by files since removed from home/ (e.g. the old
# ~/.claude/settings.json, claude-dash). Only touches links into this repo.
pruned=0
while IFS= read -r l; do
  dest="$(readlink "$l")"
  if [[ "$dest" == "$SRC"/* && ! -e "$dest" ]]; then rm -f "$l"; pruned=$((pruned+1)); fi
done < <(find "$HOME" -maxdepth 1 -type l; find "$HOME/.claude" "$HOME/.local/bin" "$HOME/.tmux" "$HOME/.config" -maxdepth 3 -type l 2>/dev/null)

# Register the hooks with GitHub Copilot CLI (the only agent on WSL). Merged
# into ~/.copilot/settings.json rather than symlinked — Copilot writes its own
# state there. Replaces only our entries (bash path under ~/.claude/hooks/), so
# re-runs are no-ops and any other hooks you've added are kept.
register_copilot_hooks() {
  local dir="${COPILOT_HOME:-$HOME/.copilot}" hooks="$HOME/.claude/hooks"
  local cfg="$dir/settings.json" tmp
  command -v jq >/dev/null 2>&1 || { echo "copilot hooks: skipped (jq missing)"; return 0; }
  mkdir -p "$dir"
  [[ -s "$cfg" ]] || echo '{}' > "$cfg"
  tmp="$(mktemp)"
  if jq --arg h "$hooks" '
      def ours($ev; $script; $t):
        .hooks[$ev] = ([(.hooks[$ev] // [])[] | select((.bash // .command // "") | startswith($h + "/") | not)]
                       + [{type: "command", bash: ($h + "/" + $script), timeoutSec: $t}]);
      .hooks = (.hooks // {})
      | ours("agentStop";    "on-stop.sh";          8)
      | ours("notification"; "on-notification.sh";  5)
      | ours("sessionStart"; "on-session-start.sh"; 3)
    ' "$cfg" > "$tmp"; then
    if cmp -s "$tmp" "$cfg"; then rm -f "$tmp"; echo "copilot hooks: already registered"
    else cat "$tmp" > "$cfg"; rm -f "$tmp"; echo "copilot hooks: registered in $cfg"; fi
  else
    rm -f "$tmp"; echo "copilot hooks: $cfg isn't plain JSON — left untouched; add hooks by hand" >&2
  fi
}
register_copilot_hooks

# WezTerm is a Windows app, so its config goes in the Windows profile, not WSL
# $HOME. Copied, not symlinked — Windows can't follow a WSL symlink.
install_wezterm_config() {
  local src="$DOTFILES/windows/.wezterm.lua" winhome
  command -v cmd.exe >/dev/null 2>&1 || { echo "wezterm: skipped (not WSL)"; return 0; }
  winhome="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  [[ -n "$winhome" ]] && winhome="$(wslpath "$winhome")" || { echo "wezterm: skipped (no %USERPROFILE%)"; return 0; }
  if cmp -s "$src" "$winhome/.wezterm.lua"; then echo "wezterm: config up to date"; return 0; fi
  if [[ -e "$winhome/.wezterm.lua" ]]; then
    mkdir -p "$BACKUP"; cp "$winhome/.wezterm.lua" "$BACKUP/.wezterm.lua"; backed=$((backed+1))
  fi
  cp "$src" "$winhome/.wezterm.lua" && echo "wezterm: config → $winhome/.wezterm.lua"
}
install_wezterm_config

echo "linked/repointed: $linked"
[[ "$pruned" -gt 0 ]] && echo "removed $pruned stale symlink(s)"
[[ "$backed" -gt 0 ]] && echo "backed up $backed original(s) to: $BACKUP"
echo "done."
