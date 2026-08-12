#!/usr/bin/env bash
# ~/dotfiles-wsl/setup.sh — install every dependency the WSL dotfiles need.
# Target: Ubuntu/Debian on WSL2. Idempotent; safe to re-run. Does NOT symlink
# the dotfiles themselves — run ./install.sh for that afterwards.
set -uo pipefail
clone() { [ -d "$2" ] || git clone --depth=1 "$1" "$2"; }

echo "== apt packages =="
sudo apt update
sudo apt install -y \
  zsh tmux git curl wget unzip build-essential jq uuid-runtime lsof \
  ripgrep fd-find bat fzf silversearcher-ag btop \
  wslu || echo "!! some apt packages failed — check output"

echo "== eza (modern ls) =="
if ! command -v eza >/dev/null 2>&1; then
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null || true
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
  sudo apt update && sudo apt install -y eza \
    || echo "!! eza apt install failed — try: cargo install eza"
fi

echo "== Debian name fixes: batcat->bat, fdfind->fd =="
mkdir -p ~/.local/bin
[ -x "$(command -v batcat 2>/dev/null)" ] && ln -sf "$(command -v batcat)" ~/.local/bin/bat
[ -x "$(command -v fdfind 2>/dev/null)" ] && ln -sf "$(command -v fdfind)" ~/.local/bin/fd

echo "== lazygit (latest release binary) =="
if ! command -v lazygit >/dev/null 2>&1; then
  ver=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
        | grep -oE '"tag_name": *"v[0-9.]+"' | grep -oE '[0-9.]+')
  if [ -n "${ver:-}" ]; then
    curl -Lo /tmp/lazygit.tgz \
      "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${ver}_Linux_x86_64.tar.gz"
    tar xf /tmp/lazygit.tgz -C /tmp lazygit && sudo install /tmp/lazygit /usr/local/bin && rm -f /tmp/lazygit*
  fi
fi

echo "== optional modern tools (aliased only if present) =="
for t in dust duf procs; do
  command -v "$t" >/dev/null 2>&1 || echo "   note: $t not installed (optional) — 'cargo install $t' if you want it"
done

echo "== oh-my-zsh + theme/plugins =="
[ -d ~/.oh-my-zsh ] || RUNZSH=no CHSH=no \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
ZC=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
clone https://github.com/romkatv/powerlevel10k            "$ZC/themes/powerlevel10k"
clone https://github.com/zsh-users/zsh-autosuggestions     "$ZC/plugins/zsh-autosuggestions"
clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZC/plugins/zsh-syntax-highlighting"
clone https://github.com/zsh-users/zsh-completions         "$ZC/plugins/zsh-completions"
clone https://github.com/Aloxaf/fzf-tab                    "$ZC/plugins/fzf-tab"

echo "== tmux plugins (tpm + resurrect + continuum) =="
clone https://github.com/tmux-plugins/tpm            ~/.tmux/plugins/tpm
clone https://github.com/tmux-plugins/tmux-resurrect ~/.tmux/plugins/tmux-resurrect
clone https://github.com/tmux-plugins/tmux-continuum ~/.tmux/plugins/tmux-continuum

echo "== neovim (bob) =="
command -v bob  >/dev/null 2>&1 || echo "   install bob:  cargo install bob-nvim   (or a release binary), then: bob use stable"
command -v nvim >/dev/null 2>&1 || echo "   then clone your nvim config: git clone git@github.com:apeoverflow/KW-IDE.git ~/.config/nvim"

echo "== default shell =="
[ "${SHELL:-}" = "$(command -v zsh)" ] || echo "   run:  chsh -s \$(which zsh)   then restart WSL (wsl --shutdown from Windows)"

cat <<'EOF'

── Next steps ───────────────────────────────────────────────
  1) ~/dotfiles-wsl/install.sh          # symlink the dotfiles into $HOME
  2) open tmux, press  Ctrl-Space  I    # install tmux plugins (tpm)
  3) AI CLIs:  install Claude Code;  npm i -g @github/copilot   (needs node)
  4) ~/dotfiles-wsl/doctor.sh           # verify everything
─────────────────────────────────────────────────────────────
EOF
