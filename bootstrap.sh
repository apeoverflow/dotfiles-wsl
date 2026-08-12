#!/usr/bin/env bash
# ~/dotfiles-wsl/bootstrap.sh — one-command setup for a fresh WSL/Ubuntu box:
# install deps → symlink dotfiles → set zsh default → verify. Idempotent.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "════════ 1/4  setup.sh — install dependencies ════════"
"$DIR/setup.sh"

echo "════════ 2/4  install.sh — symlink dotfiles ═════════"
"$DIR/install.sh"

echo "════════ 3/4  default shell → zsh ═══════════════════"
zsh_path="$(command -v zsh || echo /usr/bin/zsh)"
if [ "${SHELL:-}" != "$zsh_path" ]; then
  if chsh -s "$zsh_path" 2>/dev/null; then
    echo "  ✓ default shell set to $zsh_path (takes effect on next login)"
  else
    echo "  • couldn't chsh here — run:  chsh -s $zsh_path   (or  sudo chsh -s $zsh_path \"$USER\")"
  fi
else
  echo "  ✓ default shell already $zsh_path"
fi

echo "════════ 4/4  doctor.sh — verify ════════════════════"
"$DIR/doctor.sh" || true

cat <<'EOF'

──────────────────────────────────────────────────────────────
Bootstrap complete. Start using it now:
  exec zsh          # enter zsh in this tab (new tabs use it after re-login)
  tmux              # then press  Ctrl-Space  then  I   to install tmux plugins
  nvim              # first launch syncs LazyVim plugins (~30s)

Optional — to test the cw orchestration with Claude:
  npm install -g @anthropic-ai/claude-code && claude   # authenticate once
──────────────────────────────────────────────────────────────
EOF
