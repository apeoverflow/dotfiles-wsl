# dotfiles-wsl

WSL2 (Ubuntu/Debian) port of my macOS terminal setup
([`dotfiles-mac`](https://github.com/apeoverflow/dotfiles-mac)) — zsh +
powerlevel10k + tmux + the agent orchestration (**GitHub Copilot CLI only** on WSL) + reboot
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

Agent: **GitHub Copilot CLI** only — `npm i -g @github/copilot && copilot login`
(needs Node; `setup.sh` installs it). `install.sh` registers the hooks in
`~/.copilot/settings.json`, so if Copilot wasn't installed yet, just re-run it.
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
| notifications | `osascript` (capped at 2s) | `notify-send` → PowerShell toast, launched detached (`setsid`) so the hook never waits on it |
| hook time cap (`run_limited`) | perl fork + alarm | GNU `timeout`, perl fallback |
| locale | `en_GB.UTF-8` | `en_GB.UTF-8` if generated (`setup.sh` runs `locale-gen`), else `C.UTF-8` |
| `default-terminal` | `tmux-256color` | `tmux-256color` if its terminfo exists (`ncurses-term`), else `screen-256color` |
| `date` parsing (hooks) | BSD `date -j` | GNU `date -d` first, BSD fallback |
| `stat` mtime | `stat -f %m` | `stat -c %Y` first, BSD fallback |
| `lsof` (ai-persist) | `/usr/sbin/lsof` | `lsof` on `$PATH` |
| JAVA_HOME | `/usr/libexec/java_home` | JDK path if present, else unset |
| agent | Claude Code (default) + Copilot / Codex / Grok / Pi | **Copilot only** — `cw` always launches `copilot` |
| hook registration | `~/.claude/settings.json` (symlinked) | merged into `~/.copilot/settings.json` by `install.sh` (`agentStop` / `notification` / `sessionStart`) |
| models (`cw`) | `claude-opus-4.6` / `claude-sonnet-4.6` via copilot | `claude-opus-5.5` / `claude-sonnet-5.5` (the 4.6 ids aren't offered any more) |
| removed | iTerm2 integration, MATLAB, `/opt/homebrew`, gcloud-in-Downloads, fvm, Dart pub-cache, Unity CLI, `~/.claude/settings.json`, `claude-dash`, `claude-dashboard` | — |

The **portable core is unchanged**: `cw`, the `claude-*` scripts (names and
`~/.claude/` paths kept for parity with the Mac repo, even though they drive
Copilot here), the pane-map, the stop/notification/session-start hooks (with
their watchdog + `debug.jsonl` log; `~/.claude/hooks/diagnose.sh` dumps it),
tmux keybindings, and the resurrect + ai-persist reboot layer. Package management is `apt` + a couple of release binaries (see
`setup.sh`).

**Optional `Brewfile`** — a reduced version of the macOS Brewfile for use with
Homebrew-on-Linux (`brew bundle --file=Brewfile`), if you'd rather manage the
heavier dev tools with brew. It **drops all `cask`, `vscode`, `cargo`, and `go`
entries** plus the macOS-only formulae. The core CLI already comes from `apt`, so
this is purely for the extras (llvm, cmake, postgres, python, …) — skip it if
apt is enough.

---

## Terminal (WezTerm)

[`windows/.wezterm.lua`](windows/.wezterm.lua) is set up to match the iTerm2 profile:
same font, colours, Option-as-Meta and ⌘-style line editing. It opens straight into WSL.
WezTerm runs on Windows, so `install.sh` **copies** it to `%USERPROFILE%\.wezterm.lua`.
Re-run `install.sh` after editing; WezTerm reloads it on its own.

- Install **MesloLGS NF** on Windows (the four `.ttf`s from the powerlevel10k README).
- ⌘ becomes **Ctrl+Shift** (change `CMD` at the top of the file to use something else):

| iTerm | WezTerm |
|---|---|
| ⌘T / ⌘W / ⌘N | Ctrl+Shift+T / W / N |
| ⌘⇧[ / ⌘⇧], ⌘1…9 | Ctrl+Shift+{ / }, **Alt**+1…9 |
| ⌘D / ⌘⇧D split | Ctrl+Shift+D / **E** |
| ⌘[ / ⌘], ⌘⌥arrows | Ctrl+Shift+[ / ], Ctrl+Shift+Alt+arrows |
| ⌘⇧↩ zoom pane, ⌘↩ fullscreen | Ctrl+Shift+Enter, Alt+Enter |
| ⌘C / ⌘V / ⌘F / ⌘K | Ctrl+Shift+C / V / F / K |
| ⌘← / ⌘→ / ⌘⌫ | Ctrl+Shift+← / → / ⌫ (line start / end / kill) |
| ⌥← / ⌥→ / ⌥⌫ | Alt+← / → / ⌫ (word jump / delete) |
| ⌘-click link | Ctrl+click |

## Terminal (Windows Terminal, if used instead)

- **Tab title = tmux session name** already works: `~/.tmux.conf` has
  `set -g set-titles on` / `set-titles-string "#S"`, and Windows Terminal honours
  the title escape. (In WT you can also set the tab title per-profile, but tmux
  drives it live.)
- **Clipboard**: OSC-52 is forwarded, so tmux copy-mode yanks reach the Windows
  clipboard. `clip.exe` handles the shell-side copies.
- **Notifications**: use WSLg's `notify-send` if available, otherwise a Windows
  toast via `powershell.exe`. Either way the notifier is detached, so a slow
  `powershell.exe` start never holds up the Stop hook.

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
