#!/usr/bin/env bash
set -Eeuo pipefail

SESSION="${NODEQUALITY_TMUX_SESSION:-nodequality}"
NODEQUALITY_URL="${NODEQUALITY_URL:-https://run.NodeQuality.com}"
LOG_FILE="${NODEQUALITY_LOG_FILE:-$HOME/nodequality-${SESSION}.log}"

usage() {
    cat <<'EOF'
Usage:
  nodequality-tmux.sh          Start the benchmark in a detached tmux session
  nodequality-tmux.sh attach   Attach to the existing tmux session
  nodequality-tmux.sh status   Show the tmux session status
  nodequality-tmux.sh stop     Stop the tmux session

Environment:
  NODEQUALITY_TMUX_SESSION     tmux session name (default: nodequality)
  NODEQUALITY_URL              benchmark URL override (for testing/mirroring)
  NODEQUALITY_LOG_FILE         output log path (default: ~/nodequality-<session>.log)
EOF
}

need_root_or_sudo() {
    if [[ "$(id -u)" -eq 0 ]]; then
        SUDO=()
    elif command -v sudo >/dev/null 2>&1; then
        SUDO=(sudo)
    else
        printf 'Error: root privileges or sudo are required.\n' >&2
        exit 1
    fi
}

install_dependencies() {
    local missing=()
    command -v curl >/dev/null 2>&1 || missing+=(curl)
    command -v tmux >/dev/null 2>&1 || missing+=(tmux)

    if ((${#missing[@]} == 0)); then
        return 0
    fi

    if ! command -v apt-get >/dev/null 2>&1; then
        printf 'Error: missing %s and apt-get is unavailable. Install them manually.\n' "${missing[*]}" >&2
        exit 1
    fi

    need_root_or_sudo
    printf 'Installing required packages: %s\n' "${missing[*]}"
    "${SUDO[@]}" apt-get install -y "${missing[@]}"
}

has_session() {
    tmux has-session -t "$SESSION" 2>/dev/null
}

start_session() {
    if has_session; then
        printf 'A tmux session named %q is already running.\n' "$SESSION"
        printf 'Attach with: tmux attach -t %q\n' "$SESSION"
        exit 0
    fi

    local worker
    worker=$(cat <<EOF
set -Eeuo pipefail
printf '[%s] Starting NodeQuality with automated answers: v, y, y, y\\n' "\$(date '+%F %T')"
script_file=\$(mktemp)
trap 'rm -f "\$script_file"' EXIT
if ! curl -fsSL "$NODEQUALITY_URL" -o "\$script_file"; then
    printf '[%s] Failed to download NodeQuality script.\\n' "\$(date '+%F %T')" >&2
    exit 1
fi
set +e
printf 'v\\ny\\ny\\ny\\n' | bash "\$script_file"
status=\$?
set -e
printf '[%s] NodeQuality process exited with status %s.\\n' "\$(date '+%F %T')" "\$status"
exit "\$status"
EOF
)

    tmux new-session -d -s "$SESSION" bash -lc "$worker"
    tmux pipe-pane -t "$SESSION":0.0 "cat >> '$LOG_FILE'"
    printf 'Started tmux session: %s\n' "$SESSION"
    printf 'View live output: tmux attach -t %q\n' "$SESSION"
    printf 'Saved output log: %s\n' "$LOG_FILE"
    printf 'Detach without stopping it: press Ctrl-b, then d\n'
}

case "${1:-start}" in
    start)
        install_dependencies
        start_session
        ;;
    attach)
        if ! has_session; then
            printf 'No tmux session named %q is running. Start it first.\n' "$SESSION" >&2
            exit 1
        fi
        exec tmux attach-session -t "$SESSION"
        ;;
    status)
        if has_session; then
            tmux list-sessions -F '#{session_name}: #{session_windows} window(s), created #{session_created_string}' | awk -v session="$SESSION" '$0 ~ "^" session ":"'
        else
            printf 'No tmux session named %q is running.\n' "$SESSION"
            exit 1
        fi
        ;;
    stop)
        if has_session; then
            tmux kill-session -t "$SESSION"
            printf 'Stopped tmux session: %s\n' "$SESSION"
        else
            printf 'No tmux session named %q is running.\n' "$SESSION"
        fi
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
