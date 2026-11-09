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

install_look_command() {
    local target=/usr/local/bin/look
    local temp_file

    need_root_or_sudo

    if [[ -e "$target" ]] && ! grep -q 'nodequality-tmux-launcher' "$target" 2>/dev/null; then
        printf '错误：%s 已存在，脚本不会覆盖已有命令。\n' "$target" >&2
        exit 1
    fi

    temp_file=$(mktemp)
    cat > "$temp_file" <<EOF
#!/usr/bin/env bash
# nodequality-tmux-launcher
set -Eeuo pipefail
session=$(printf '%q' "$SESSION")
if ! tmux has-session -t "\$session" 2>/dev/null; then
    printf '没有找到 NodeQuality 的 tmux 会话：%s\n' "\$session" >&2
    printf '测评可能已经结束，日志文件：%s\n' $(printf '%q' "$LOG_FILE") >&2
    exit 1
fi
exec tmux attach-session -t "\$session"
EOF
    chmod 0755 "$temp_file"

    if [[ "$(id -u)" -eq 0 ]]; then
        install -m 0755 "$temp_file" "$target"
    else
        sudo install -m 0755 "$temp_file" "$target"
    fi
    rm -f "$temp_file"
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
printf '[%s] NodeQuality 测评开始，自动输入：v、y、y、y\\n' "\$(date '+%F %T')"
script_file=\$(mktemp)
trap 'rm -f "\$script_file"' EXIT
if ! curl -fsSL "$NODEQUALITY_URL" -o "\$script_file"; then
    printf '[%s] NodeQuality 测评脚本下载失败。\\n' "\$(date '+%F %T')" >&2
    printf '脚本下载失败，tmux 会话仍会保留，按 Ctrl-b，然后按 d 退出。\\n'
    exec bash
fi
set +e
printf 'v\\ny\\ny\\ny\\n' | bash "\$script_file"
status=\$?
set -e
printf '[%s] NodeQuality 测评结束，退出状态：%s。\\n' "\$(date '+%F %T')" "\$status"
printf '测评已经结束，tmux 会话仍会保留，可输入 look 查看最后输出。\\n'
exec bash
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
        install_look_command
        start_session
        printf '脚本已经开始执行，你可以放心关闭SSH，重新连接后在服务器输入look即可返回脚本观看进度。\n'
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
