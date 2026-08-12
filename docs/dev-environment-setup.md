# Dev Environment — Full Setup & Replication Guide

A complete map of this macOS terminal setup — shell, tmux, the Claude/Copilot
worktree-orchestration layer, Neovim, and reboot persistence — plus exactly what
to install and what to put under git to reproduce it on a fresh machine.

> Companion doc: **`tmux-persistence.md`** covers the reboot-restore layer in
> depth. This guide covers everything else and references it where they meet.

---

## 1. The big picture

```
┌───────────────────────────────────────────────────────────────────────────┐
│ Terminal (iTerm2 / Alacritty)                                              │
│  └─ zsh  ── oh-my-zsh + powerlevel10k + vi-mode + fzf-tab                   │
│      ├─ aliases (exa/rg/fd/bat…) + PATH for ~12 language toolchains         │
│      └─ functions: cw* / ta / tag / tns / nvim-dev  (+ completions)        │
│                                                                            │
│  └─ tmux (prefix = Ctrl-Space)                                             │
│      ├─ custom keybinds → claude-* scripts (window picker, jump, commit,PR)│
│      ├─ per-window: claude | copilot | nvim | lazygit | shell | dev-server │
│      └─ persistence: resurrect + continuum + ai-persist hooks              │
│                                                                            │
│  Orchestration layer (the "claude-bot" system)                            │
│      cw  ─ creates git worktree + tmux window + launches claude/copilot     │
│      pane-map/  ─ per-session JSON (session_id ↔ window ↔ worktree)         │
│      hooks  ─ on-stop / on-notification → mac notify + window ✓/! + log     │
│      pickers ─ claude-windows / claude-jump / claude-pick / claude-dash     │
│                                                                            │
│  Neovim ── LazyVim (folke/lazy.nvim), version-managed by `bob`             │
│      config repo: github.com/apeoverflow/KW-IDE                            │
└───────────────────────────────────────────────────────────────────────────┘
```

**Machine facts (as captured):** macOS on Apple Silicon (`/opt/homebrew`), zsh
`/bin/zsh`, tmux from Homebrew, Neovim `v0.11.5` via `bob`, 71 Homebrew leaves.

---

## 2. Dependency inventory

### 2.1 Homebrew (formulae + casks)
A full snapshot is committed as **`Brewfile`** in this directory. Reproduce with:
```bash
brew bundle --file=./Brewfile          # install everything
brew bundle dump --force --file=./Brewfile   # regenerate the snapshot
```

**Core tools this setup hard-depends on** (subset of the Brewfile):

| Tool | Used by |
|---|---|
| `tmux` | everything |
| `reattach-to-user-namespace` | tmux `default-command` (macOS clipboard) |
| `fzf` | `ta`, `cw*`, `claude-windows/pick`, fzf-tab |
| `jq` | `cw`, all hooks, ai-persist scripts |
| `gh` | `claude-pr` (open PRs) |
| `lazygit` | `prefix+l/L`, git windows |
| `terminal-notifier` | Claude hooks (mac notifications) |
| `bob` | installs/switches Neovim versions |
| `bat`, `exa`, `rg` (ripgrep), `fd` | shell aliases / pagers |
| `node` | runs the `copilot` CLI |
| `uv` | runs `claude-dash` (PEP-723 inline script) |
| `git`, `uuidgen` | `cw` worktree + session ids |

> ⚠️ **Broken aliases to fix or install:** `~/.zshrc` aliases `du→dust`,
> `df→duf`, `top→btop`, `ps→procs`, and `FZF_DEFAULT_COMMAND='ag …'`, but
> `dust`, `duf`, `btop`, `procs`, and `ag` (the_silver_searcher) are **not
> installed**. Either `brew install dust duf btop procs the_silver_searcher` or
> remove those alias lines. (`ps→procs` being missing is why `ps` errors.)

### 2.2 Language toolchains (installed outside brew, referenced in `~/.zshrc` PATH)
`bun`, `nvm` (lazy-loaded), Solana, `nargo`/Noir + `bb`, Ruby (brew) + gems,
Flutter via `fvm`, Dart, `pipx` venvs (poetry, slither, neovim-remote→`nvr`),
`uv`/`uvx`, Google Cloud SDK, Postgres@17, Java 17. These are optional per
project — install only what you use.

### 2.3 oh-my-zsh + external zsh pieces
- **oh-my-zsh** at `~/.oh-my-zsh`.
- **Custom plugins/themes** in `~/.oh-my-zsh/custom/` (git-cloned, not part of omz):
  `powerlevel10k` (theme), `zsh-autosuggestions`, `zsh-syntax-highlighting`,
  `zsh-completions`, `fzf-tab`.
- Built-in omz plugins enabled: `git vi-mode docker docker-compose npm yarn node
  brew history-substring-search` (+ the customs above).

### 2.4 tmux plugins
`tpm`, `tmux-resurrect`, `tmux-continuum` in `~/.tmux/plugins/` (see
`tmux-persistence.md`).

### 2.5 The AI CLIs
- **Claude Code** — installed at `~/.local/share/claude/…`, symlinked to
  `~/.local/bin/claude`.
- **GitHub Copilot CLI** — `copilot` (Homebrew / npm), a Node app.

---

## 3. Component deep-dive

### 3.1 Shell — `~/.zshrc` (382 lines)

Load order and notable pieces:

1. **p10k guard (lines 8–18):** disables Powerlevel10k/gitstatus in non-TTY or
   `$NVIM` subshells so their stderr doesn't leak into plugin terminals. Real
   interactive shells get the instant-prompt cache.
2. **History (21–35):** 50k lines at `~/.cache/zsh/history`, shared, dedup.
3. **Completion (37–42):** `compinit` + `menu select` + `globdots`.
4. **omz plugins (46–61).**
5. **vi-mode (64–104):** `Ctrl-Z`→cmd mode, beam/block cursor per mode, `KEYTIMEOUT=5`.
6. **Aliases (106–134):** editor (`v=nvim`), modern CLI swaps, `lg=lazygit`.
7. **PATH + env (137–245):** the toolchains in §2.2; `EDITOR/VISUAL=nvim`,
   `MANPAGER` via bat, fzf-tab popup config, history-substring-search binds.
8. **Custom functions (247–381):**

| Function | What it does |
|---|---|
| `nvim-dev` | launches Neovim from a worktree config (`NVIM_APPNAME=nvim-dev`) for testing IDE changes |
| `cwcd` (fn) | wraps `~/.local/bin/cwcd` then `git checkout` the chosen `test/` branch |
| `cwr` | hard-reset working dir after `prefix+b` moved the branch pointer (guards dirty tree) |
| `_cw` / `_cwcd` | zsh completions for `cw` (worktree names + flags) and `cwcd` |
| `tns` | `tmux new-session -s <name> -c $PWD` |
| `ta` | attach to a session — **fzf picker** if no arg, else direct; `switch-client` when already inside tmux |
| `tag` | attach in a new *grouped* session (independent window navigation) |
| `_tmux_session_names` | tab-completion of session names for `ta`/`tag` |

### 3.2 tmux — `~/.tmux.conf`

- **Prefix:** `Ctrl-Space`. Base index 1, `renumber-windows on`, mouse on, 50k
  scrollback, OSC-52 clipboard forwarding, `reattach-to-user-namespace` shell.
- **Session root:** `session-created` hook captures `SESSION_ROOT`; `prefix+R`
  overrides it. Shell/editor/git binds open at session root vs pane dir.
- **Claude orchestration binds:**
  `prefix+j` claude-jump · `prefix+n` claude-pick · `prefix+w` claude-windows
  (rich picker) · `prefix+c` new claude · `prefix+b` claude-commit · `prefix+p`
  claude-pr · `prefix+W` choose-tree · `after-select-window` → claude-clear-tick
  (strips the ✓/! tick).
- **Persistence block** (added later): plugins + `@continuum-save-interval` +
  the `ai-persist` hooks. Full detail in `tmux-persistence.md`.

### 3.3 The Claude/Copilot orchestration layer

The heart of the setup — turns "start an agent on a task" into "one command that
makes a worktree, a tmux window, and a tracked session."

**`cw <name> [flags]`** (`~/.local/bin/cw`) — the launcher:
1. Parses flags → tool (`claude` default / `-c` copilot), model (`-s` sonnet),
   permission mode (`-d`/`-sd` bypass, `-n` normal), `-nw` no-worktree, `--agent`.
2. Ensures a git repo + at least one commit.
3. Creates a worktree at `<repo>/.claude/worktrees/<name>` (reuses branch if it
   exists, else branches from current). Existing worktree → reuse, name gets `+`.
4. Generates a `session_id` (`uuidgen`) and launches the tool in a **new tmux
   window** via a temp bootstrap script (sets the OSC-2 title to `tool:session_id`).
5. Writes `~/.claude/pane-map/<session_id>.json`:
   `{session_id, pane_target, worktree, cwd, tool, base_branch}` — resolving the
   real base branch through any `test/` prefix.

**`~/.claude/pane-map/<sid>.json`** — the per-session index that ties a session
id to its tmux window, worktree, cwd, and tool. Read by the hooks and pickers.
(Note: `pane_target` here drifts under `renumber-windows`; the reboot layer no
longer trusts it — see `tmux-persistence.md`.)

**Hooks** (registered in `~/.claude/settings.json`):
- `on-stop.sh` (Stop) — on turn end: skip if <15s; extract a title from the
  transcript; **mac notify** (`terminal-notifier`); rename the window `✓ <wt>`;
  append a `stop` event to `~/.claude/ready.log`.
- `on-notification.sh` (Notification) — when Claude needs input: notify; rename
  window `! <wt>`; log a `notification` event.
- `lib.sh` — shared helpers: `parse_stdin`, `lookup_pane`, `extract_title`,
  `append_ready_log`, `notify_mac`, `flash_window`.

**Navigation / lifecycle scripts** (`~/.local/bin/`):

| Script | Bound to | Purpose |
|---|---|---|
| `claude-windows` | `prefix+w` / `prefix+c` | fzf picker of tmux windows w/ live preview; create / kill (+ worktree cleanup) / reorder |
| `claude-jump` | `prefix+j` | jump to the most recently finished session (reads `ready.log`) |
| `claude-pick` / `cws` | `prefix+n` | fzf picker of recent stop events |
| `claude-clear-tick` | `after-select-window` | strip the `✓ `/`! ` tick when you visit a window |
| `claude-commit` | `prefix+b` | stage + commit all changes in the pane's worktree |
| `claude-pr` | `prefix+p` | push the worktree branch and open a PR (`gh`) |
| `claude-sync` | — | pull `test/` branch commits back into the working branch |
| `claude-gc` | — | prune old `pane-map` files, trim `ready.log` |
| `claude-dashboard` | — | gather git/worktree context, pipe to `claude -p` for a summary |
| `claude-dash` | — | full-screen TUI over sessions (Python via `uv`), with resume |

**Runtime state (NOT committed — regenerated at use):**
`~/.claude/pane-map/`, `~/.claude/ready.log`, `~/.claude/history.jsonl`,
`~/.claude/projects/`, `~/.tmux/ai-persist/ai-live.json`.

### 3.4 Neovim — LazyVim

- **Manager:** `folke/lazy.nvim` (bootstrapped in `lua/config/lazy.lua`); base
  distro is **LazyVim** (`lazyvim.json`, `lazy-lock.json` pins versions).
- **Config repo:** `~/.config/nvim` is already a git repo →
  `https://github.com/apeoverflow/KW-IDE.git`. **This is your nvim dotfiles — keep
  committing here.**
- **Structure:** `init.lua` + `lua/config/{lazy,options,keymaps,autocmds,
  treesitter}.lua` + `lua/plugins/*.lua` (avante, claude-code, copilot,
  telescope, lsp, git, rust, flutter, cpp, ui, colorscheme, …).
- **Version management:** `bob` (`bob use v0.11.5`); binary at
  `~/.local/share/bob/nvim-bin/nvim`.
- **`nvim-dev`:** the zsh function + `NVIM_APPNAME=nvim-dev` let you test config
  changes from an nvim worktree without touching the live config. `nvr`
  (neovim-remote, pipx) is available for remote control.

### 3.5 Reboot persistence
See **`tmux-persistence.md`**. In brief: `tmux-resurrect` + `tmux-continuum`
restore geometry, and `~/.tmux/ai-persist-{save,restore}.sh` re-attach each
claude/copilot window to its exact session id (copilot via `inuse` lock, claude
via open `.jsonl`).

---

## 4. Replicating on a fresh Mac (ordered)

```bash
# 1. Homebrew + everything in the Brewfile
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew bundle --file=~/Code/personal/claude-bot/Brewfile

# 2. oh-my-zsh + custom plugins/theme
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
ZC=~/.oh-my-zsh/custom
git clone --depth=1 https://github.com/romkatv/powerlevel10k          "$ZC/themes/powerlevel10k"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions   "$ZC/plugins/zsh-autosuggestions"
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZC/plugins/zsh-syntax-highlighting"
git clone --depth=1 https://github.com/zsh-users/zsh-completions        "$ZC/plugins/zsh-completions"
git clone --depth=1 https://github.com/Aloxaf/fzf-tab                   "$ZC/plugins/fzf-tab"

# 3. Dotfiles (see §5 for the repo) — restore ~/.zshrc ~/.p10k.zsh ~/.tmux.conf
#    ~/.local/bin/{cw,cwcd,cws,claude-*}  ~/.claude/{settings.json,hooks/}
#    ~/.tmux/ai-persist-*.sh

# 4. tmux plugins
git clone https://github.com/tmux-plugins/tpm            ~/.tmux/plugins/tpm
git clone https://github.com/tmux-plugins/tmux-resurrect ~/.tmux/plugins/tmux-resurrect
git clone https://github.com/tmux-plugins/tmux-continuum ~/.tmux/plugins/tmux-continuum
tmux start-server \; source-file ~/.tmux.conf            # then prefix+I

# 5. Neovim
brew install bob && bob use stable
git clone https://github.com/apeoverflow/KW-IDE.git ~/.config/nvim && nvim   # lazy syncs

# 6. AI CLIs
#    Claude Code: official installer → ~/.local/bin/claude
#    Copilot CLI: npm i -g @github/copilot   (needs node)

# 7. Language toolchains as needed (bun, nvm, solana, fvm, uv, pipx tools…)
chmod +x ~/.local/bin/cw ~/.local/bin/cwcd ~/.local/bin/cws ~/.local/bin/claude-*
chmod +x ~/.claude/hooks/*.sh ~/.tmux/ai-persist-*.sh
```

---

## 5. What to put under git (commit plan)

You currently have **one** thing versioned (nvim → KW-IDE). Everything else is
loose. Recommended: a single **`dotfiles`** repo managed with **GNU Stow**
(`brew install stow` — not yet installed here), which symlinks tracked files
into `$HOME`. Prefer plain symlinks or a bare git repo? Either works; the
commit/never-commit lists below are what matter.

### 5.1 Repo layout (stow "packages")
```
dotfiles/
├── Brewfile                      # (or keep the copy in claude-bot)
├── zsh/       .zshrc  .p10k.zsh
├── tmux/      .tmux.conf
│             .tmux/ai-persist-save.sh  .tmux/ai-persist-restore.sh
├── bin/       .local/bin/cw  cwcd  cws
│             .local/bin/claude-clear-tick claude-commit claude-dash
│             claude-dashboard claude-gc claude-jump claude-pick
│             claude-pr claude-sync claude-windows
└── claude/    .claude/settings.json
              .claude/hooks/lib.sh  on-stop.sh  on-notification.sh
```
Apply with: `cd ~/dotfiles && stow zsh tmux bin claude`
(each package mirrors `$HOME`, so `stow zsh` links `~/.zshrc`, etc.)

### 5.2 Commit ✅ / never commit 🚫

**✅ Commit**
- `~/.zshrc`, `~/.p10k.zsh`
- `~/.tmux.conf`
- `~/.tmux/ai-persist-save.sh`, `~/.tmux/ai-persist-restore.sh`
- `~/.local/bin/`: `cw`, `cwcd`, `cws`, and all `claude-*` scripts
- `~/.claude/settings.json`, `~/.claude/hooks/{lib,on-stop,on-notification}.sh`
- `Brewfile`, and these two docs
- Neovim → **already** in `apeoverflow/KW-IDE` (keep as-is, or add as a submodule)

**🚫 Never commit (secrets / machine state / installed artifacts)**
- `~/.claude.json` and `~/.claude/backups/` — account + MCP tokens
- `~/.claude/{projects,pane-map,ready.log,history.jsonl,file-history,plugins,statsig,debug}` — runtime state
- `~/.copilot/` — copilot session state + oauth
- `~/.tmux/ai-persist/ai-live.json`, `~/.local/share/tmux/resurrect/` — snapshots
- `~/.tmux/plugins/` — cloned plugins (reinstall via tpm)
- `~/.local/bin/` **symlinks + binaries** (`claude`, `uv`, `sui`, `surfpool`,
  `herdr`, `nvr`, `slither*`, `poetry`, `duckdb`) — reinstalled by their tools
- `~/.local/bin/{pipx,userpath,*python-argcomplete*}` — pipx-generated wrappers
- The `~/Code/personal/claude-bot/.secrets` file, any `google-cloud-sdk`

### 5.3 Suggested `.gitignore` (in the dotfiles repo)
```gitignore
*.log
.DS_Store
.claude/projects/
.claude/pane-map/
.claude/backups/
.claude/history.jsonl
.tmux/ai-persist/
.tmux/plugins/
```

### 5.4 Quick start for the dotfiles repo
```bash
mkdir -p ~/dotfiles/{zsh,tmux/.tmux,bin/.local/bin,claude/.claude/hooks}
cp ~/.zshrc ~/.p10k.zsh                              ~/dotfiles/zsh/
cp ~/.tmux.conf                                      ~/dotfiles/tmux/
cp ~/.tmux/ai-persist-*.sh                           ~/dotfiles/tmux/.tmux/
cp ~/.local/bin/{cw,cwcd,cws,claude-*}               ~/dotfiles/bin/.local/bin/
cp ~/.claude/settings.json                           ~/dotfiles/claude/.claude/
cp ~/.claude/hooks/{lib,on-stop,on-notification}.sh  ~/dotfiles/claude/.claude/hooks/
cp ~/Code/personal/claude-bot/Brewfile               ~/dotfiles/
cd ~/dotfiles && git init && git add -A && git commit -m "initial dotfiles"
# then, to adopt on this machine, replace originals with symlinks:
#   rm ~/.zshrc … && stow zsh tmux bin claude
```

---

## 6. Component → dependency quick reference

| If you want… | You need |
|---|---|
| `cw` to launch agents | `git`, `tmux`, `jq`, `uuidgen`, `claude` and/or `copilot` (node) |
| Claude window ✓/! + notifications | `terminal-notifier`, hooks in `settings.json`, `tmux` |
| `prefix+w` / `ta` pickers | `fzf` |
| `claude-pr` | `gh` (authenticated) |
| `claude-dash` TUI | `uv` (runs the PEP-723 script) |
| Neovim | `bob` + the KW-IDE repo |
| Reboot restore | `tpm` + resurrect + continuum + ai-persist scripts (see other doc) |
| The prompt | oh-my-zsh + powerlevel10k + the 4 custom zsh plugins |
