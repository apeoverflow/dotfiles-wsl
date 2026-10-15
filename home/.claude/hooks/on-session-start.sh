#!/usr/bin/env bash
# Logs SessionStart so a "stuck on start plugins" spinner can be timed later.
# Always exits 0; keep this under 1s.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh" 2>/dev/null || exit 0

install_watchdog 3
log_debug start "on-session-start"
parse_stdin || true
log_debug session_start "source=${HOOK_REASON:-startup} grok_event=${GROK_HOOK_EVENT:-}"
exit 0
