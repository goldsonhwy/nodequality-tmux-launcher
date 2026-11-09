#!/usr/bin/env bash
set -Eeuo pipefail

SESSION="${NODEQUALITY_TMUX_SESSION:-nodequality}"
NODEQUALITY_URL="${NODEQUALITY_URL:-https://run.NodeQuality.com}"
LOG_FILE="${NODEQUALITY_LOG_FILE:-$HOME/nodequality-${SESSION}.log}"
HQ_INPUT="-v"
IQ_INPUT="-y"
NQ_INPUT="-y"
BT_INPUT="-y"

usage() {
    cat <<'EOF'
Usage:
  nodequality-tmux.sh [参数1 参数2 参数3 参数4]
                               在后台 tmux 会话中启动测评
  nodequality-tmux.sh attach   进入已有的 tmux 会话
  nodequality-tmux.sh status   查看 tmux 会话状态
  nodequality-tmux.sh stop     停止 tmux 会话

四个测试参数必须按顺序提供：
  参数1：HardwareQuality，支持 -v 深度、-f 快速、-y 普通、-n 不测
  参数2：IPQuality，支持 -y 测试、-n 不测
  参数3：NetQuality，支持 -y 测试、-l 低流量、-n 不测
  参数4：回程路由追踪，支持 -y 测试、-n 不测

默认参数：-v -y -y -y

环境变量：
  NODEQUALITY_TMUX_SESSION     tmux 会话名称（默认：nodequality）
  NODEQUALITY_URL              测评脚本地址
  NODEQUALITY_LOG_FILE         输出日志路径
EOF
}

parse_test_args() {
    if (($# == 0)); then
        return 0
    fi

    if (($# != 4)); then
        printf '错误：启动测评时必须提供 0 个或 4 个测试参数。\n\n' >&2
        usage >&2
        exit 2
    fi

    case "$1" in
        -v|-f|-y|-n) HQ_INPUT="$1" ;;
        *) printf '错误：第 1 个参数只能是 -v、-f、-y 或 -n。\n' >&2; exit 2 ;;
    esac
    case "$2" in
        -y|-n) IQ_INPUT="$2" ;;
        *) printf '错误：第 2 个参数只能是 -y 或 -n。\n' >&2; exit 2 ;;
    esac
    case "$3" in
        -y|-l|-n) NQ_INPUT="$3" ;;
        *) printf '错误：第 3 个参数只能是 -y、-l 或 -n。\n' >&2; exit 2 ;;
    esac
    case "$4" in
        -y|-n) BT_INPUT="$4" ;;
        *) printf '错误：第 4 个参数只能是 -y 或 -n。\n' >&2; exit 2 ;;
    esac
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
printf '[%s] NodeQuality 测评开始，自动输入：$HQ_INPUT、$IQ_INPUT、$NQ_INPUT、$BT_INPUT\\n' "\$(date '+%F %T')"
script_file=\$(mktemp)
trap 'rm -f "\$script_file"' EXIT
if ! curl -fsSL "$NODEQUALITY_URL" -o "\$script_file"; then
    printf '[%s] NodeQuality 测评脚本下载失败。\\n' "\$(date '+%F %T')" >&2
    printf '脚本下载失败，tmux 会话仍会保留，按 Ctrl-b，然后按 d 退出。\\n'
    exec bash
fi
set +e
printf '%s\\n%s\\n%s\\n%s\\n' "$HQ_INPUT" "$IQ_INPUT" "$NQ_INPUT" "$BT_INPUT" | bash "\$script_file"
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

ACTION="${1:-start}"
if [[ "$ACTION" == -* ]]; then
    ACTION=start
fi

case "$ACTION" in
    start)
        [[ "${1:-}" == start ]] && shift
        parse_test_args "$@"
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
