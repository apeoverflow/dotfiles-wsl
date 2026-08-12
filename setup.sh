#!/usr/bin/env bash
# ~/dotfiles-wsl/setup.sh — install every dependency the WSL dotfiles need.
# Target: Ubuntu/Debian on WSL2. Idempotent; safe to re-run. Does NOT symlink
# the dotfiles themselves — run ./install.sh for that afterwards.
set -uo pipefail
clone() { [ -d "$2" ] || git clone --depth=1 "$1" "$2"; }

echo "== apt packages =="
sudo apt-get update -y || echo "!! apt update failed"
# Install per-package so one unavailable package can't abort the whole batch
# (learned the hard way: a missing 'wslu' on a non-WSL VM took everything down).
CORE=(zsh tmux git curl wget unzip build-essential ca-certificates gnupg \
      jq uuid-runtime lsof ripgrep fd-find bat fzf silversearcher-ag btop)
for p in "${CORE[@]}"; do
  sudo apt-get install -y "$p" >/dev/null 2>&1 && echo "  ✓ $p" || echo "  ✗ $p (apt install failed)"
done

echo "== Node.js (needed for the copilot CLI) =="
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1 || true
  sudo apt-get install -y nodejs >/dev/null 2>&1 && echo "  ✓ node $(node -v 2>/dev/null)" \
    || echo "  ✗ node — install via nvm:  nvm install --lts"
fi

echo "== wslu (WSL-only: provides wslview) =="
if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
  sudo apt-get install -y wslu >/dev/null 2>&1 && echo "  ✓ wslu" || echo "  ✗ wslu (add-apt-repository universe?)"
else
  echo "  • skipped — not running under WSL (wslview only matters on real WSL)"
fi

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
  case "$(uname -m)" in
    x86_64|amd64) lgarch="Linux_x86_64" ;;
    aarch64|arm64) lgarch="Linux_arm64" ;;
    *) lgarch="Linux_x86_64" ;;
  esac
  ver=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
        | grep -oE '"tag_name": *"v[0-9.]+"' | grep -oE '[0-9.]+')
  if [ -n "${ver:-}" ]; then
    curl -Lo /tmp/lazygit.tgz \
      "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${ver}_${lgarch}.tar.gz" \
      && tar xf /tmp/lazygit.tgz -C /tmp lazygit \
      && sudo install /tmp/lazygit /usr/local/bin && rm -f /tmp/lazygit* \
      && echo "  ✓ lazygit $ver ($lgarch)" || echo "  ✗ lazygit download failed"
  else
    echo "  ✗ could not resolve lazygit version (GitHub API rate limit?)"
  fi
fi

echo "== optional modern tools (aliased only if present) =="
for t in dust duf procs; do
  command -v "$t" >/dev/null 2>&1 || echo "   note: $t not installed (optional) — 'cargo install $t' if you want it"
done

echo "== oh-my-zsh + theme/plugins =="
# Guard on the actual core file, not just the directory — cloning plugins into
# ~/.oh-my-zsh/custom/ creates the dir, which would otherwise skip the install
# and leave oh-my-zsh half-installed (missing oh-my-zsh.sh). Install via git so
# it's deterministic and self-repairs a partial install without clobbering custom/.
if [ ! -f ~/.oh-my-zsh/oh-my-zsh.sh ]; then
  tmp=$(mktemp -d)
  if git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$tmp/omz" >/dev/null 2>&1; then
    mkdir -p ~/.oh-my-zsh
    cp -rn "$tmp/omz/." ~/.oh-my-zsh/    # fill in core files, keep any existing custom/
    echo "  ✓ oh-my-zsh installed"
  else
    echo "  ✗ oh-my-zsh clone failed"
  fi
  rm -rf "$tmp"
else
  echo "  ✓ oh-my-zsh already present"
fi
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

echo "== neovim (official release binary — no cargo/bob needed) =="
if ! command -v nvim >/dev/null 2>&1; then
  case "$(uname -m)" in
    x86_64|amd64)  nvarch="linux-x86_64" ;;
    aarch64|arm64) nvarch="linux-arm64"  ;;
    *)             nvarch="linux-x86_64" ;;
  esac
  # try the current asset name, then fall back to the older linux64 name
  if   curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-${nvarch}.tar.gz" -o /tmp/nvim.tgz \
    || curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz"   -o /tmp/nvim.tgz; then
    rm -rf ~/.local/nvim && mkdir -p ~/.local/nvim
    tar xf /tmp/nvim.tgz -C ~/.local/nvim --strip-components=1 && rm -f /tmp/nvim.tgz
    mkdir -p ~/.local/bin && ln -sf ~/.local/nvim/bin/nvim ~/.local/bin/nvim
    echo "  ✓ neovim $(~/.local/bin/nvim --version 2>/dev/null | head -1)"
  else
    echo "  ✗ neovim download failed — install manually"
  fi
fi
# LazyVim config (public repo). First `nvim` launch bootstraps lazy.nvim + plugins.
if [ ! -e ~/.config/nvim/init.lua ]; then
  git clone https://github.com/apeoverflow/KW-IDE.git ~/.config/nvim \
    && echo "  ✓ cloned KW-IDE -> ~/.config/nvim (run 'nvim' once to sync plugins)" \
    || echo "  ✗ KW-IDE clone failed"
else
  echo "  • ~/.config/nvim already present — left as-is"
fi

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
