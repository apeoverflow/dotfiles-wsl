#!/usr/bin/env bash
# ~/dotfiles-wsl/doctor.sh — verify the WSL environment has what the dotfiles need.
# Safe, read-only. Run on the VM/work machine after setup.sh + install.sh.
# Check the same PATH the shell will use (bat/fd get symlinked here by setup.sh).
export PATH="$HOME/.local/bin:$PATH"
ok=0; miss=0; warn=0
chk()  { if command -v "$1" >/dev/null 2>&1; then printf '  \033[32m✓\033[0m %-16s %s\n' "$1" "$(command -v "$1")"; ok=$((ok+1));
         else printf '  \033[31m✗\033[0m %-16s MISSING%s\n' "$1" "${2:+  — $2}"; miss=$((miss+1)); fi; }
warnc(){ if command -v "$1" >/dev/null 2>&1; then printf '  \033[32m✓\033[0m %-16s %s\n' "$1" "$(command -v "$1")"; ok=$((ok+1));
         else printf '  \033[33m•\033[0m %-16s optional%s\n' "$1" "${2:+ — $2}"; warn=$((warn+1)); fi; }
dir()  { if [ -e "$1" ]; then printf '  \033[32m✓\033[0m %s\n' "$1"; ok=$((ok+1)); else printf '  \033[31m✗\033[0m %s MISSING\n' "$1"; miss=$((miss+1)); fi; }
link() { if [ -L "$2" ]; then printf '  \033[32m✓\033[0m %-20s -> %s\n' "${2/#$HOME/~}" "$(readlink "$2")"; ok=$((ok+1));
         else printf '  \033[31m✗\033[0m %-20s not a symlink (run install.sh)\n' "${2/#$HOME/~}"; miss=$((miss+1)); fi; }

echo "── core ─────────────────────────";      for t in zsh tmux git jq fzf uuidgen lsof node; do chk "$t"; done
echo "── modern CLI ───────────────────";      for t in eza bat fd rg ag btop lazygit; do chk "$t"; done
echo "── WSL interop ──────────────────"
if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
  chk wslview "apt install wslu"; chk clip.exe "Windows interop on PATH?"; warnc powershell.exe "for toast notifications"
else
  printf '  \033[33m•\033[0m %-16s N/A — not running under WSL (present on the real work box)\n' wslview
  printf '  \033[33m•\033[0m %-16s N/A — not running under WSL\n' clip.exe
  warn=$((warn+2))
fi
echo "── notifications ────────────────"
if command -v notify-send >/dev/null 2>&1 || command -v powershell.exe >/dev/null 2>&1; then echo "  ✓ a notifier is available"; ok=$((ok+1)); else printf '  \033[33m•\033[0m no notifier yet (notify-send / powershell.exe) — WSLg or a daemon provides it\n'; warn=$((warn+1)); fi
# AI CLIs are installed by their own installers, not setup.sh — flag, don't fail.
echo "── editor ───────────────────────";      chk nvim "setup.sh installs it"; dir ~/.config/nvim/init.lua
echo "── AI CLIs (install separately) ──";      for t in claude copilot; do warnc "$t" "claude installer / npm i -g @github/copilot"; done
echo "── optional ─────────────────────";      for t in dust duf procs bob; do warnc "$t"; done
echo "── zsh / tmux plugins ───────────"
dir ~/.oh-my-zsh
dir ~/.oh-my-zsh/custom/themes/powerlevel10k
dir ~/.oh-my-zsh/custom/plugins/fzf-tab
dir ~/.tmux/plugins/tpm
dir ~/.tmux/plugins/tmux-resurrect
echo "── dotfiles symlinks ────────────"
link "" ~/.zshrc; link "" ~/.tmux.conf; link "" ~/.local/bin/cw; link "" ~/.claude/hooks/lib.sh

echo
echo "summary: $ok present, $miss missing, $warn optional-absent"
[ "$miss" -eq 0 ] && echo "✅ core setup looks complete" || echo "⚠️  fix the ✗ items above (setup.sh installs most)"
