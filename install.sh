#!/usr/bin/env bash
# ~/dotfiles/install.sh — symlink every tracked file in home/ into $HOME.
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

echo "linked/repointed: $linked"
[[ "$backed" -gt 0 ]] && echo "backed up $backed original(s) to: $BACKUP"
echo "done."
