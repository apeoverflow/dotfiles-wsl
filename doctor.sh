#!/usr/bin/env bash
# ~/dotfiles-wsl/doctor.sh — verify the WSL environment has what the dotfiles need.
# Safe, read-only. Run on the VM/work machine after setup.sh + install.sh.
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
echo "── WSL interop ──────────────────";       chk wslview "apt install wslu"; chk clip.exe "Windows interop on PATH?"; warnc powershell.exe "for toast notifications"
echo "── notifications ────────────────"
if command -v notify-send >/dev/null 2>&1 || command -v powershell.exe >/dev/null 2>&1; then echo "  ✓ a notifier is available"; ok=$((ok+1)); else echo "  ✗ no notifier (notify-send or powershell.exe)"; miss=$((miss+1)); fi
echo "── AI CLIs ──────────────────────";      for t in claude copilot; do chk "$t"; done
echo "── optional ─────────────────────";      for t in dust duf procs bob nvim; do warnc "$t"; done
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
