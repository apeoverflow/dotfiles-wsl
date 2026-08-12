# tmux Persistence Across Reboots (with Claude / Copilot session resume)

Restore your whole tmux workspace after a reboot — sessions, windows, pane
layouts, and every worktree working directory — **and** re-attach each `claude`
and `copilot` window to the *exact* session it was running, by session ID.

tmux sessions live in RAM inside the `tmux` server process, so a reboot always
destroys the live sessions. There is no way to keep the running processes alive.
What this setup does is **save the layout + the AI session IDs to disk**, then
rebuild everything and resume the AI conversations on demand.

---

## TL;DR — daily use

| Action | Keys / command |
|---|---|
| Save a snapshot now | `prefix` + `Ctrl-s` (also auto-saved every 15 min) |
| **Restore after a reboot** | `prefix` + `Ctrl-r` |

> `prefix` is `Ctrl-Space` in this config.

After a reboot: launch `tmux`, press **`prefix` + `Ctrl-r`**, and every window
comes back at the right directory. Each `claude`/`copilot` window is
automatically re-launched as `claude --resume <id>` / `copilot --resume=<id>`,
reconnecting to the same conversation it had before.

---

## Why AI resume needs more than tmux-resurrect

tmux-resurrect is great at **geometry** (sessions, windows, names, cwds) but it
can only *relaunch a program* — it cannot recover a TUI's in-memory state. For
`claude`/`copilot` a blind relaunch would start a *fresh* conversation.

The trick is that Claude and Copilot already persist every session to disk, and
the **live process itself** tells us which session it is — no reliance on tmux
window indices (which drift under `renumber-windows on`) or on the
`~/.claude/pane-map` cache (which goes stale). At save time we read the session
id straight from the running process:

- **copilot** writes `~/.copilot/session-state/<sid>/inuse.<pid>.lock` while a
  session is open. A `<pid>` in the pane's process group ⇒ that pane's session id.
- **claude** keeps `~/.claude/projects/<enc-cwd>/<sid>.jsonl` open. `lsof` of a
  pid in the pane's process group yields the `<sid>`.

This is authoritative even when several claude/copilot sessions share one
worktree, or when window numbers have shifted since the session started.

> **copilot fork caveat.** `copilot --resume=<id>` loads the conversation but
> spins up a *new, empty* working session (no `events.jsonl` yet) and locks
> that. Resuming that empty fork id would fail. So the save script treats a
> session as resumable only if it has a non-empty `events.jsonl`; if the live
> lock points at an empty fork, it falls back to the newest session **with**
> events in the same cwd (the parent) — which is what you actually want back.

---

## How it works (two stages)

```
        ┌─────────────────────────── SAVE (every 15 min + prefix+Ctrl-s) ──┐
        │ tmux-resurrect saves geometry → ~/.local/share/tmux/resurrect/   │
        │ post-save hook → ai-persist-save.sh                              │
        │   • scans live panes; for each, inspects its process group       │
        │   • copilot: pid -> inuse.<pid>.lock -> session id               │
        │     claude:  pid -> open <sid>.jsonl  -> session id              │
        │     (empty copilot forks resolve to the parent with events)      │
        │   • freezes {pane_target, tool, session_id, cwd} into            │
        │     ~/.tmux/ai-persist/ai-live.json                              │
        └─────────────────────────────────────────────────────────────────┘

        ══════════════════════  R E B O O T  ══════════════════════

        ┌───────────────────────── RESTORE (prefix+Ctrl-r) ───────────────┐
        │ tmux-resurrect rebuilds sessions/windows/cwds                    │
        │   • nvim + lazygit relaunch automatically                        │
        │   • claude/copilot windows come back as plain shells             │
        │ post-restore hook → ai-persist-restore.sh                        │
        │   • reads ai-live.json                                           │
        │   • into each matching restored pane, types:                     │
        │       claude  --resume  <session_id>                             │
        │       copilot --resume=<session_id>                              │
        └─────────────────────────────────────────────────────────────────┘
```

**Why freeze the IDs at save time?** After a reboot there is no tmux server to
ask "which session was live in this pane". Recording the answer while everything
is still running makes restore unambiguous — even when several claude/copilot
sessions share the same worktree directory (a plain `--continue` can't tell them
apart; a specific `--resume <id>` can).

### Per-window-type behaviour

| Window | On restore |
|---|---|
| **shell** | cwd restored (worktree dir), plain shell |
| **nvim** | relaunched at the right cwd (resurrect default whitelist). Add a session plugin if you want *buffers* reopened, not just an empty nvim |
| **lazygit** | relaunched at the right cwd (stateless — perfect) |
| **claude** | shell restored at the worktree → `claude --resume <id>` typed in |
| **copilot** | shell restored at the worktree → `copilot --resume=<id>` typed in |
| **dev servers** (`node`, etc.) | restored as a shell at the right cwd; not auto-run (they died with the machine — relaunch them yourself) |

Guards in the restore script: it only types into a **fresh shell** pane (never
stomps a busy pane) and only if the pane's **cwd still matches** what was saved,
so a changed layout can't resume the wrong conversation. A stale/exited session
is never resumed.

---

## Files

| Path | Role |
|---|---|
| `~/.tmux.conf` | plugin declarations + hook wiring (see block at bottom of the file) |
| `~/.tmux/ai-persist-save.sh` | post-save hook: writes `ai-live.json` |
| `~/.tmux/ai-persist-restore.sh` | post-restore hook: types the resume commands |
| `~/.tmux/ai-persist/ai-live.json` | frozen snapshot of live AI sessions |
| `~/.copilot/session-state/<sid>/` | copilot's own per-session state (read for `inuse` locks + `events.jsonl`) |
| `~/.claude/projects/<enc-cwd>/<sid>.jsonl` | claude's own per-session transcript (read via `lsof`) |
| `~/.local/share/tmux/resurrect/` | tmux-resurrect's geometry snapshots |
| `~/.tmux/plugins/{tpm,tmux-resurrect,tmux-continuum}` | the plugins |

The hook scripts honour env overrides for testing (all default to the real
paths): `AI_PERSIST_DIR`, `AI_PERSIST_COPILOT_STATE`, `AI_PERSIST_CLAUDE_PROJECTS`.

---

## Setup (already applied on this machine — here for reference / new machines)

1. **Install the plugin manager + plugins**

   ```bash
   git clone --depth 1 https://github.com/tmux-plugins/tpm            ~/.tmux/plugins/tpm
   git clone --depth 1 https://github.com/tmux-plugins/tmux-resurrect ~/.tmux/plugins/tmux-resurrect
   git clone --depth 1 https://github.com/tmux-plugins/tmux-continuum ~/.tmux/plugins/tmux-continuum
   ```

2. **`~/.tmux.conf`** — add this block (keep the `run '…/tpm'` line **last** in
   the whole file):

   ```tmux
   # -- Persistence across reboots ------------------------------------------
   set -g @plugin 'tmux-plugins/tpm'
   set -g @plugin 'tmux-plugins/tmux-resurrect'
   set -g @plugin 'tmux-plugins/tmux-continuum'

   # Auto-save every 15 min; restore stays manual (prefix+Ctrl-r).
   set -g @continuum-save-interval '15'

   # Save scrollback so restored panes aren't blank in previews.
   set -g @resurrect-capture-pane-contents 'on'

   # Relaunch stateless tools automatically (nvim is already whitelisted).
   # claude/copilot are re-attached by session id via the hooks instead.
   set -g @resurrect-processes 'lazygit'

   # Freeze live claude/copilot session ids on save; resume them on restore.
   set -g @resurrect-hook-post-save-all    '~/.tmux/ai-persist-save.sh'
   set -g @resurrect-hook-post-restore-all '~/.tmux/ai-persist-restore.sh'

   # Keep TPM initialisation as the very last line.
   run '~/.tmux/plugins/tpm/tpm'
   ```

3. **Make the hook scripts executable**

   ```bash
   chmod +x ~/.tmux/ai-persist-save.sh ~/.tmux/ai-persist-restore.sh
   ```

4. **Activate** (or just restart tmux):

   ```bash
   tmux source-file ~/.tmux.conf     # inside tmux you can also press prefix + I
   ```

### Optional: fully automatic restore on boot

By default you press `prefix + Ctrl-r` yourself. To have tmux auto-restore the
last snapshot the moment the server starts, add:

```tmux
set -g @continuum-restore 'on'
```

Note: on macOS tmux does **not** auto-start after login — you still have to
launch `tmux` once (manually, from your shell profile, or a `launchd` agent).
The AI resume runs on *any* restore, automatic or manual.

### Optional: reopen nvim buffers, not just an empty nvim

```tmux
set -g @resurrect-strategy-nvim 'session'   # needs tpope/vim-obsession in nvim
```

---

## Testing

Verified three independent ways — all on isolated tmux sockets so the live
session was never at risk.

**1. Synthetic reboot cycle (8/8 pass).** Fake `claude`/`copilot` binaries (that
register an `inuse` lock / hold a `.jsonl` open, and log their argv) on socket
`-L ptest2`, with a real `tmux kill-server` as the "reboot". Asserts:

- claude id captured from its open `.jsonl`; copilot id from its `inuse` lock;
- an **empty copilot fork** resolves back to the resumable parent (via cwd);
- plain-shell and lazygit windows are **not** captured;
- after reboot, sessions/windows/cwds are rebuilt;
- `claude --resume <id>` and `copilot --resume=<id>` are issued with the exact
  IDs, exactly once each; lazygit is never resumed.

**2. Live capture on the real server.** Running the save against the real
`oomph-ondemand` session captured exactly the two live copilots with their
correct, resumable session IDs, and excluded the `lazygit`/`nvim`/dev-server
panes — even though stale `pane-map` entries pointed the old logic at the wrong
sessions (the bug this process-based approach fixes).

**3. Full live cycle with a real conversation.** On socket `-L pdemo3`: launch a
real `copilot` resuming an actual past conversation → save → `kill-server`
(reboot) → restore → **copilot relaunched and reloaded the real conversation**,
resuming the correct session id. End-to-end PASS.

The test scripts live in the scratchpad used during setup
(`test_persist2.sh`, `live_demo3.sh`); none of them touch your real tmux server
or your `~/.copilot` / `~/.claude` session data destructively.

### Test it yourself, safely

Quickest confidence check without a real reboot, on your live session:

```bash
prefix + Ctrl-s                         # save
jq . ~/.tmux/ai-persist/ai-live.json    # confirm your live claude/copilot are listed with correct ids
```

For a true reboot rehearsal that can't disturb your main session, run it on an
isolated socket: start `tmux -L demo`, open a claude/copilot in it, `prefix +
Ctrl-s`, `tmux -L demo kill-server`, then `tmux -L demo` + `prefix + Ctrl-r` and
watch the window resume. (This is exactly what `live_demo3.sh` automates.)

---

## Troubleshooting

- **A claude window came back as a plain shell.** The pane's cwd didn't match
  the saved cwd (worktree moved/deleted), or the pane wasn't a fresh shell when
  the hook ran. Resume manually with your existing tooling (`prefix + j`,
  `claude-dash`) or `claude --resume` in that directory.
- **`ai-live.json` is empty.** Expected if no `claude`/`copilot` was running at
  the last save. It repopulates on the next save when an AI pane is live.
- **Wrong / old session resumed.** The snapshot is only as fresh as the last
  save. Force one with `prefix + Ctrl-s` before rebooting if you just started a
  new session.
- **A copilot window shows "No session … matched".** It resumed an empty fork
  id. The save script guards against this (it only records copilot sessions with
  a non-empty `events.jsonl` and resolves forks to their parent), but if you hit
  it, just run `copilot --resume` in that pane to pick from the list.
- **Nothing restores.** Confirm plugins are installed (`ls ~/.tmux/plugins`) and
  the hooks are set: `tmux show-option -gv @resurrect-hook-post-restore-all`.
- **Inspect what will happen:** `jq . ~/.tmux/ai-persist/ai-live.json`.

---

## Uninstall / revert

```bash
# Remove the "Persistence across reboots" block from ~/.tmux.conf
# (a timestamped backup was made: ~/.tmux.conf.bak-YYYYMMDD-HHMMSS)

rm -rf ~/.tmux/plugins/{tpm,tmux-resurrect,tmux-continuum}
rm -f  ~/.tmux/ai-persist-save.sh ~/.tmux/ai-persist-restore.sh
rm -rf ~/.tmux/ai-persist ~/.local/share/tmux/resurrect
tmux kill-server   # or restart tmux to drop the loaded plugins
```

---

## Tunables cheat-sheet

| Option | Default here | Meaning |
|---|---|---|
| `@continuum-save-interval` | `15` | minutes between auto-saves |
| `@continuum-restore` | *(off)* | `on` = auto-restore when the server starts |
| `@resurrect-capture-pane-contents` | `on` | save scrollback for restored panes |
| `@resurrect-processes` | `lazygit` | extra programs to relaunch verbatim |
| `@resurrect-strategy-nvim` | *(unset)* | `session` reopens nvim buffers (needs vim-obsession) |
| `@resurrect-dir` | *(XDG default)* | where geometry snapshots are stored |
