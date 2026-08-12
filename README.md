# dotfiles-wsl

WSL2 (Ubuntu/Debian) port of my macOS terminal setup
([`dotfiles-mac`](https://github.com/apeoverflow/dotfiles-mac)) — zsh +
powerlevel10k + tmux + the Claude/Copilot worktree orchestration + reboot
persistence. Same structure and symlink workflow; the platform-specific bits are
adapted for Linux/WSL.

- 📘 [`docs/dev-environment-setup.md`](docs/dev-environment-setup.md) — full component walkthrough (macOS-oriented; concepts identical)
- 🔁 [`docs/tmux-persistence.md`](docs/tmux-persistence.md) — reboot/session-resume layer

---

## Quick start (on the WSL box or a test VM)

```bash
git clone https://github.com/apeoverflow/dotfiles-wsl.git ~/dotfiles-wsl
cd ~/dotfiles-wsl
./setup.sh        # apt deps, eza/lazygit, oh-my-zsh + plugins, tmux plugins
./install.sh      # symlink home/* into $HOME (backs up any originals)
chsh -s $(which zsh)   # then restart WSL:  wsl --shutdown  (from Windows)
# open tmux, press Ctrl-Space then I to install tmux plugins
./doctor.sh       # verify everything is present
```

AI CLIs (install separately): **Claude Code** (official installer →
`~/.local/bin/claude`) and **Copilot** (`npm i -g @github/copilot`, needs Node).
Neovim config is its own repo: `git clone https://github.com/apeoverflow/KW-IDE.git ~/.config/nvim`.

---

## How it works (same as the Mac repo)

Tracked files live under `home/`, mirroring `$HOME`. `install.sh` symlinks each
into place, so `~/.zshrc` → `~/dotfiles-wsl/home/.zshrc`. Edit the file anywhere;
it's the same file — commit when ready:

```bash
cd ~/dotfiles-wsl && git add -A && git commit -m "…" && git push
```

---

## What changed vs. `dotfiles-mac`

| Area | macOS | WSL |
|---|---|---|
| tmux pane shell | `reattach-to-user-namespace -l $SHELL` | removed (native shell) |
| clipboard | `pbcopy`, OSC-52 | `clip.exe`, OSC-52 (Windows Terminal supports it) |
| open files/URLs | `open` | `wslview` (from `wslu`) |
| `ls` | `exa` | `eza` |
| `bat` / `fd` | native | Debian `batcat` / `fdfind` → symlinked to `bat`/`fd` |
| `du/df/top/ps` | dust/duf/btop/procs (always aliased) | aliased **only if installed** (so a missing tool never shadows the real command) |
| notifications | `terminal-notifier` | `notify-send` → PowerShell toast fallback |
| `date` parsing (hooks) | BSD `date -j` | GNU `date -d` first, BSD fallback |
| `stat` mtime | `stat -f %m` | `stat -c %Y` first, BSD fallback |
| `lsof` (ai-persist) | `/usr/sbin/lsof` | `lsof` on `$PATH` |
| JAVA_HOME | `/usr/libexec/java_home` | JDK path if present, else unset |
| removed | iTerm2 integration, MATLAB, `/opt/homebrew`, gcloud-in-Downloads, fvm | — |

The **portable core is unchanged**: `cw`, all `claude-*` scripts, the pane-map,
the Stop/Notification hooks, tmux keybindings, and the resurrect + ai-persist
reboot layer. Package management is `apt` + a couple of release binaries instead
of a Brewfile (see `setup.sh`).

---

## Terminal (Windows Terminal)

- **Tab title = tmux session name** already works: `~/.tmux.conf` has
  `set -g set-titles on` / `set-titles-string "#S"`, and Windows Terminal honours
  the title escape. (In WT you can also set the tab title per-profile, but tmux
  drives it live.)
- **Clipboard**: OSC-52 is forwarded, so tmux copy-mode yanks reach the Windows
  clipboard. `clip.exe` handles the shell-side copies.
- **Notifications**: use WSLg's `notify-send` if available, otherwise a Windows
  toast via `powershell.exe`.

---

## Testing on a VM first

`doctor.sh` is the fast feedback loop — it lists every dependency as ✓/✗/optional
and the symlink status, so on a fresh VM you can run `setup.sh` → `install.sh` →
`doctor.sh` and immediately see what's missing. Nothing here is destructive:
`install.sh` backs up any real files it replaces into `~/.dotfiles-backup/<ts>/`.

## Caveats

- Not yet run end-to-end on a live WSL box — this was ported on macOS. `doctor.sh`
  + a VM run is the intended verification path.
- `notify-send` needs WSLg (Windows 11) or a notification daemon; otherwise the
  PowerShell toast path is used.
- `dust`/`duf`/`procs` aren't in Ubuntu's default repos — install via `cargo` if
  you want them (the aliases are conditional, so nothing breaks without them).
