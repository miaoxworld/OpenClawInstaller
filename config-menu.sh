#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   🦞 OpenClaw 交互式配置菜单 v1.0.0                                        ║
# ║   便捷的可视化配置工具                                                      ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#

# ================================ TTY 检测 ================================
# 当通过 curl | bash 或被其他脚本调用时，stdin 可能不是终端
# 需要优先选择“可读”的输入源，避免 /dev/tty 存在但不可用导致循环报错
resolve_tty_input() {
    if [ -t 0 ]; then
        echo "/dev/stdin"
        return 0
    fi

    if [ -e /dev/tty ] && ( : < /dev/tty ) 2>/dev/null; then
        echo "/dev/tty"
        return 0
    fi

    if [ -r /dev/stdin ]; then
        echo "/dev/stdin"
        return 0
    fi

    return 1
}

if ! TTY_INPUT="$(resolve_tty_input)"; then
    echo "错误: 无法获取终端输入，请直接运行此脚本"
    echo "用法: bash config-menu.sh"
    exit 1
fi

if [ "$TTY_INPUT" = "/dev/stdin" ] && [ ! -t 0 ]; then
    echo "错误: 当前会话不可交互（stdin 非终端，且 /dev/tty 不可用）"
    echo "请在可交互终端中运行: bash config-menu.sh"
    exit 1
fi

# 统一的读取函数（支持非 TTY 模式）
read_input() {
    local prompt="$1"
    local var_name="$2"
    echo -en "$prompt"
    if ! read $var_name < "$TTY_INPUT"; then
        echo ""
        log_error "输入读取失败，请在可交互终端中重新运行。"
        exit 1
    fi
}

# 从 TTY 读取敏感输入（默认不回显）
read_secret_input() {
    local prompt="$1"
    local var_name="$2"
    echo -e "${GRAY}（自动隐藏，直接粘贴后回车即可）${NC}"
    echo -en "$prompt"
    if stty -echo < "$TTY_INPUT" 2>/dev/null; then
        if ! read $var_name < "$TTY_INPUT"; then
            stty echo < "$TTY_INPUT" 2>/dev/null || true
            echo ""
            log_error "输入读取失败，请在可交互终端中重新运行。"
            exit 1
        fi
        stty echo < "$TTY_INPUT" 2>/dev/null || true
    else
        if ! read $var_name < "$TTY_INPUT"; then
            echo ""
            log_error "输入读取失败，请在可交互终端中重新运行。"
            exit 1
        fi
    fi
    echo ""
}

# ================================ 颜色定义 ================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# 背景色
BG_BLUE='\033[44m'
BG_GREEN='\033[42m'
BG_RED='\033[41m'

# ================================ 配置变量 ================================
CONFIG_DIR="$HOME/.openclaw"

# OpenClaw 环境变量配置
OPENCLAW_ENV="$CONFIG_DIR/env"
OPENCLAW_JSON="$CONFIG_DIR/openclaw.json"
BACKUP_DIR="$CONFIG_DIR/backups"
OPENCLAW_BIN_RESOLVED=""
DEFAULT_GATEWAY_HOST="${OPENCLAW_GATEWAY_HOST:-127.0.0.1}"
DEFAULT_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-13145}"

# 飞书插件策略（仅官方插件，支持版本 pin）
FEISHU_PLUGIN_OFFICIAL="@openclaw/feishu"
# QQ 社区插件策略（可选，不默认）
QQ_PLUGIN_COMMUNITY="@sliverp/qqbot"
QQ_PLUGIN_VERSION_DEFAULT="${OPENCLAW_QQ_PLUGIN_VERSION:-1.5.4}"
# 微信社区插件策略（LangBot WeChatPad 适配）
WECHAT_PLUGIN_LANGBOT="openclaw-wechat-channel"
WECHAT_PLUGIN_VERSION_DEFAULT="${OPENCLAW_WECHAT_PLUGIN_VERSION:-0.5.0}"
WECHATPAD_CALLBACK_PATH_DEFAULT="${OPENCLAW_WECHATPAD_CALLBACK_PATH:-/api/callback/wechatpadpro}"
# 企业微信社区插件策略（WeCom）
WECOM_PLUGIN_COMMUNITY="@marshulll/openclaw-wecom"
WECOM_PLUGIN_VERSION_DEFAULT="${OPENCLAW_WECOM_PLUGIN_VERSION:-0.1.41}"
WECOM_WEBHOOK_BOT_DEFAULT="${OPENCLAW_WECOM_WEBHOOK_BOT_PATH:-/wecom/bot}"
WECOM_WEBHOOK_APP_DEFAULT="${OPENCLAW_WECOM_WEBHOOK_APP_PATH:-/wecom/app}"
INSTALLER_REPO="leecyno1/auto-install-Openclaw"
INSTALLER_RAW_URL="https://raw.githubusercontent.com/${INSTALLER_REPO}/main"
AUTO_FIX_OPENCLAW_REPO_URL="${AUTO_FIX_OPENCLAW_REPO_URL:-https://github.com/leecyno1/auto-fix-openclaw.git}"
AUTO_FIX_OPENCLAW_REPO_MIRROR_URL="${AUTO_FIX_OPENCLAW_REPO_MIRROR_URL:-https://mirror.ghproxy.com/https://github.com/leecyno1/auto-fix-openclaw.git}"
AUTO_FIX_OPENCLAW_DIR="${AUTO_FIX_OPENCLAW_DIR:-$HOME/.openclaw/tools/auto-fix-openclaw}"
AUTO_FIX_OPENCLAW_BIN="$AUTO_FIX_OPENCLAW_DIR/bin/auto-fix-openclaw"

# ================================ 工具函数 ================================

clear_screen() {
    if [ -n "${TERM:-}" ] && [ "${TERM}" != "dumb" ] && command -v clear >/dev/null 2>&1; then
        clear
    else
        printf '\n'
    fi
}

print_header() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║   🦞 OpenClaw 配置中心                                         ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_divider() {
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_menu_item() {
    local num=$1
    local text=$2
    local icon=$3
    echo -e "  ${CYAN}[$num]${NC} $icon $text"
}

log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

press_enter() {
    echo ""
    echo -en "${GRAY}按 Enter 键继续...${NC}"
    if ! read < "$TTY_INPUT"; then
        echo ""
        log_error "输入读取失败，退出配置菜单。"
        exit 1
    fi
}

confirm() {
    local message="$1"
    local default="${2:-y}"
    
    if [ "$default" = "y" ]; then
        local prompt="[Y/n]"
    else
        local prompt="[y/N]"
    fi
    
    echo -en "${YELLOW}$message $prompt: ${NC}"
    if ! read response < "$TTY_INPUT"; then
        echo ""
        log_error "输入读取失败，退出配置菜单。"
        exit 1
    fi
    response=${response:-$default}
    
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# 检查依赖
check_dependencies() {
    if ! command -v yq &> /dev/null; then
        # 使用简单的 sed/grep 处理 yaml
        USE_YQ=false
    else
        USE_YQ=true
    fi
}

# 备份配置
backup_config() {
    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/env_$(date +%Y%m%d_%H%M%S).bak"
    if [ -f "$OPENCLAW_ENV" ]; then
        cp "$OPENCLAW_ENV" "$backup_file"
        echo "$backup_file"
    fi
}

# 确保插件被添加到 plugins.allow 数组中
# 这是启用插件的关键步骤
ensure_plugin_in_allow() {
    local plugin_id="$1"
    
    if [ ! -f "$OPENCLAW_JSON" ]; then
        log_warn "配置文件不存在: $OPENCLAW_JSON"
        return 1
    fi
    
    # 检查是否安装了 jq
    if ! command -v jq &> /dev/null; then
        log_warn "未安装 jq，尝试使用 Python 更新配置..."
        python3 << PYEOF
import json
import os

config_path = os.path.expanduser("$OPENCLAW_JSON")
plugin_id = "$plugin_id"

try:
    with open(config_path, 'r') as f:
        config = json.load(f)
    
    # 确保 plugins 结构存在
    if 'plugins' not in config:
        config['plugins'] = {'allow': [], 'entries': {}}
    if 'allow' not in config['plugins']:
        config['plugins']['allow'] = []
    if 'entries' not in config['plugins']:
        config['plugins']['entries'] = {}
    
    # 添加到 allow 列表
    if plugin_id not in config['plugins']['allow']:
        config['plugins']['allow'].append(plugin_id)
        print(f"已将 {plugin_id} 添加到 plugins.allow")
    
    # 确保 entries 中也启用
    config['plugins']['entries'][plugin_id] = {'enabled': True}
    
    # 确保 channels.xxx 存在（使用安全的默认策略，不设置 enabled）
    if 'channels' not in config:
        config['channels'] = {}
    if plugin_id not in config['channels']:
        config['channels'][plugin_id] = {'dmPolicy': 'pairing', 'groupPolicy': 'allowlist'}
    
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    
except Exception as e:
    print(f"更新配置失败: {e}")
    exit(1)
PYEOF
        return $?
    fi
    
    # 使用 jq 更新配置
    local tmp_file=$(mktemp)
    
    # 确保 plugins 和 channels 结构存在，并添加到 allow 列表
    jq --arg plugin "$plugin_id" '
        .plugins //= {"allow": [], "entries": {}} |
        .plugins.allow //= [] |
        .plugins.entries //= {} |
        .channels //= {} |
        .channels[$plugin] //= {"dmPolicy": "pairing", "groupPolicy": "allowlist"} |
        if (.plugins.allow | index($plugin)) then . else .plugins.allow += [$plugin] end |
        .plugins.entries[$plugin] = {"enabled": true}
    ' "$OPENCLAW_JSON" > "$tmp_file"
    
    if [ $? -eq 0 ] && [ -s "$tmp_file" ]; then
        mv "$tmp_file" "$OPENCLAW_JSON"
        log_info "已将 $plugin_id 添加到 plugins.allow"
        return 0
    else
        rm -f "$tmp_file"
        log_error "更新 plugins.allow 失败"
        return 1
    fi
}

# 从 plugins.allow / plugins.entries / channels 中移除插件
remove_plugin_from_allow() {
    local plugin_id="$1"

    if [ ! -f "$OPENCLAW_JSON" ]; then
        log_warn "配置文件不存在: $OPENCLAW_JSON"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        python3 << PYEOF
import json
import os

config_path = os.path.expanduser("$OPENCLAW_JSON")
plugin_id = "$plugin_id"

try:
    with open(config_path, 'r') as f:
        config = json.load(f)

    plugins = config.get('plugins', {})
    allow = plugins.get('allow', [])
    if isinstance(allow, list):
        plugins['allow'] = [p for p in allow if p != plugin_id]

    entries = plugins.get('entries', {})
    if isinstance(entries, dict) and plugin_id in entries:
        entries.pop(plugin_id, None)
        plugins['entries'] = entries

    config['plugins'] = plugins

    channels = config.get('channels', {})
    if isinstance(channels, dict):
        channels.pop(plugin_id, None)
        config['channels'] = channels

    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
except Exception as e:
    print(f"更新配置失败: {e}")
    exit(1)
PYEOF
        return $?
    fi

    local tmp_file
    tmp_file=$(mktemp)
    jq --arg plugin "$plugin_id" '
        .plugins //= {"allow": [], "entries": {}} |
        .plugins.allow = ((.plugins.allow // []) | map(select(. != $plugin))) |
        .plugins.entries = ((.plugins.entries // {}) | del(.[$plugin])) |
        .channels = ((.channels // {}) | del(.[$plugin]))
    ' "$OPENCLAW_JSON" > "$tmp_file"

    if [ $? -eq 0 ] && [ -s "$tmp_file" ]; then
        mv "$tmp_file" "$OPENCLAW_JSON"
        log_info "已清理 $plugin_id 在本地配置中的残留"
        return 0
    fi

    rm -f "$tmp_file"
    log_error "清理 $plugin_id 配置残留失败"
    return 1
}

# 将逗号分隔字符串转换为 JSON 数组
build_json_array_from_csv() {
    local csv="$1"
    local json="["
    local count=0
    local item=""
    local trimmed=""
    local escaped=""

    IFS=',' read -r -a __csv_items <<< "$csv"
    for item in "${__csv_items[@]}"; do
        trimmed="$(echo "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [ -n "$trimmed" ] || continue
        escaped="${trimmed//\\/\\\\}"
        escaped="${escaped//\"/\\\"}"
        if [ $count -gt 0 ]; then
            json+=","
        fi
        json+="\"$escaped\""
        count=$((count + 1))
    done

    json+="]"
    echo "$json"
}

# 直接写入 channels.<channel>.allowFrom，确保数组类型准确
set_channel_allow_from_json() {
    local channel="$1"
    local allow_json="$2"

    if [ ! -f "$OPENCLAW_JSON" ]; then
        openclaw config set "channels.${channel}.allowFrom" "$allow_json" > /dev/null 2>&1
        return $?
    fi

    if ! command -v jq &> /dev/null; then
        python3 << PYEOF
import json
import os

config_path = os.path.expanduser("$OPENCLAW_JSON")
channel = "$channel"
allow_from = json.loads('''$allow_json''')

with open(config_path, 'r') as f:
    cfg = json.load(f)
cfg.setdefault('channels', {})
cfg['channels'].setdefault(channel, {})
cfg['channels'][channel]['allowFrom'] = allow_from
with open(config_path, 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
PYEOF
        return $?
    fi

    local tmp_file
    tmp_file=$(mktemp)
    jq --arg channel "$channel" --argjson allow "$allow_json" '
        .channels //= {} |
        .channels[$channel] //= {} |
        .channels[$channel].allowFrom = $allow
    ' "$OPENCLAW_JSON" > "$tmp_file"

    if [ $? -eq 0 ] && [ -s "$tmp_file" ]; then
        mv "$tmp_file" "$OPENCLAW_JSON"
        return 0
    fi

    rm -f "$tmp_file"
    return 1
}

# 从环境变量文件读取配置
get_env_value() {
    local key=$1
    if [ -f "$OPENCLAW_ENV" ]; then
        grep "^export $key=" "$OPENCLAW_ENV" 2>/dev/null | sed 's/.*=//' | tr -d '"'
    fi
}

# ================================ 测试功能 ================================

ensure_openclaw_on_path() {
    # 补充常见全局 bin，避免“已安装但当前 shell 不可见”
    local npm_prefix=""
    local npm_bin=""
    local candidate=""

    if command -v npm &> /dev/null; then
        npm_prefix="$(npm config get prefix 2>/dev/null || true)"
        if [ -n "$npm_prefix" ] && [ "$npm_prefix" != "undefined" ] && [ "$npm_prefix" != "null" ]; then
            npm_bin="$npm_prefix/bin"
            if [ -d "$npm_bin" ]; then
                case ":$PATH:" in
                    *":$npm_bin:"*) ;;
                    *) export PATH="$npm_bin:$PATH" ;;
                esac
            fi
        fi
    fi

    for candidate in "$HOME/.npm-global/bin" "$HOME/.local/bin" "/usr/local/bin" "/usr/bin"; do
        if [ -d "$candidate" ]; then
            case ":$PATH:" in
                *":$candidate:"*) ;;
                *) export PATH="$candidate:$PATH" ;;
            esac
        fi
    done
}

resolve_openclaw_bin() {
    ensure_openclaw_on_path

    if command -v openclaw &> /dev/null; then
        if [ "$(type -t openclaw 2>/dev/null)" = "function" ] && [ -n "$OPENCLAW_BIN_RESOLVED" ]; then
            echo "$OPENCLAW_BIN_RESOLVED"
            return 0
        fi
        command -v openclaw
        return 0
    fi
    if command -v claw &> /dev/null; then
        command -v claw
        return 0
    fi

    if command -v npm &> /dev/null && command -v node &> /dev/null; then
        local npm_root=""
        npm_root="$(npm root -g 2>/dev/null || true)"
        if [ -n "$npm_root" ]; then
            local pkg_json="$npm_root/openclaw/package.json"
            if [ -f "$pkg_json" ]; then
                local candidate
                candidate=$(node -e '
const fs=require("fs");
const path=require("path");
const pkg=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const bin=(pkg.bin && (pkg.bin.openclaw || pkg.bin.claw)) || "";
if (bin) process.stdout.write(path.resolve(path.dirname(process.argv[1]), bin));
' "$pkg_json" 2>/dev/null || true)
                if [ -n "$candidate" ] && [ -f "$candidate" ]; then
                    chmod +x "$candidate" 2>/dev/null || true
                    echo "$candidate"
                    return 0
                fi
            fi
        fi
    fi

    return 1
}

ensure_openclaw_alias() {
    if command -v openclaw &> /dev/null; then
        return 0
    fi

    OPENCLAW_BIN_RESOLVED="$(resolve_openclaw_bin || true)"
    if [ -z "$OPENCLAW_BIN_RESOLVED" ]; then
        return 1
    fi

    # 当官方仅暴露 claw 时，动态注入 openclaw 兼容命令
    openclaw() {
        "$OPENCLAW_BIN_RESOLVED" "$@"
    }
    return 0
}

# 检查 OpenClaw 是否已安装
check_openclaw_installed() {
    ensure_openclaw_on_path
    command -v openclaw &> /dev/null || ensure_openclaw_alias
}

is_valid_port() {
    local p="$1"
    [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ]
}

get_gateway_port() {
    local port="$DEFAULT_GATEWAY_PORT"

    if [ -f "$OPENCLAW_ENV" ]; then
        local env_port
        env_port="$(grep '^export OPENCLAW_GATEWAY_PORT=' "$OPENCLAW_ENV" 2>/dev/null | tail -1 | sed 's/^export OPENCLAW_GATEWAY_PORT=//')"
        env_port="$(echo "$env_port" | tr -d '"'\''[:space:]')"
        if is_valid_port "$env_port"; then
            port="$env_port"
        fi
    fi

    if check_openclaw_installed; then
        local cfg_port
        cfg_port="$(openclaw config get gateway.port 2>/dev/null || true)"
        cfg_port="$(echo "$cfg_port" | tr -d '"'\''[:space:]')"
        if is_valid_port "$cfg_port"; then
            port="$cfg_port"
        fi
    fi

    echo "$port"
}

get_gateway_host() {
    local host="$DEFAULT_GATEWAY_HOST"

    if [ -f "$OPENCLAW_ENV" ]; then
        local env_host
        env_host="$(grep '^export OPENCLAW_GATEWAY_HOST=' "$OPENCLAW_ENV" 2>/dev/null | tail -1 | sed 's/^export OPENCLAW_GATEWAY_HOST=//')"
        env_host="$(echo "$env_host" | tr -d '"'\''[:space:]')"
        if [ -n "$env_host" ]; then
            host="$env_host"
        fi
    fi

    if check_openclaw_installed; then
        local cfg_host
        cfg_host="$(openclaw config get gateway.host 2>/dev/null || true)"
        cfg_host="$(echo "$cfg_host" | tr -d '"'\''[:space:]')"
        if [ -n "$cfg_host" ] && [ "$cfg_host" != "undefined" ]; then
            host="$cfg_host"
        fi
    fi

    echo "$host"
}

upsert_env_export() {
    local key="$1"
    local value="$2"
    local file="$OPENCLAW_ENV"

    mkdir -p "$(dirname "$file")" 2>/dev/null || true
    touch "$file" 2>/dev/null || true

    local tmp_file
    tmp_file="$(mktemp)"
    awk -v k="$key" -v v="$value" '
        BEGIN { done=0 }
        $0 ~ "^export " k "=" { print "export " k "=" v; done=1; next }
        { print }
        END { if (!done) print "export " k "=" v }
    ' "$file" > "$tmp_file" && mv "$tmp_file" "$file"
    chmod 600 "$file" 2>/dev/null || true
}

remove_env_export() {
    local key="$1"
    local file="$OPENCLAW_ENV"

    [ -f "$file" ] || return 0
    local tmp_file
    tmp_file="$(mktemp)"
    awk -v k="$key" '$0 !~ "^export " k "=" { print }' "$file" > "$tmp_file" && mv "$tmp_file" "$file"
    chmod 600 "$file" 2>/dev/null || true
}

get_gateway_pid() {
    local gateway_port
    gateway_port="$(get_gateway_port)"
    get_port_pid "$gateway_port"
}

get_port_pid() {
    local port="$1"
    local pid=""
    if command -v lsof &> /dev/null; then
        pid=$(lsof -ti :"$port" 2>/dev/null | head -1)
    fi
    if [ -z "$pid" ] && command -v pgrep &> /dev/null; then
        pid=$(pgrep -f "openclaw gateway" 2>/dev/null | head -1)
    fi
    echo "$pid"
}

# 重启 Gateway 使渠道配置生效
restart_gateway_for_channel() {
    echo ""
    log_info "正在重启 Gateway..."
    local gateway_port
    gateway_port="$(get_gateway_port)"
    
    # 加载环境变量
    if [ -f "$OPENCLAW_ENV" ]; then
        source "$OPENCLAW_ENV"
    fi
    
    # 先运行 doctor --fix 确保配置有效
    echo -e "${YELLOW}检查配置...${NC}"
    yes | openclaw doctor --fix > /dev/null 2>&1 || true
    
    # 使用官方 restart 命令
    local restart_output
    restart_output=$(openclaw gateway restart 2>&1) || true
    
    sleep 2
    
    # 使用端口检测判断服务是否启动成功（更可靠）
    local gateway_pid
    gateway_pid=$(get_gateway_pid)
    
    if [ -n "$gateway_pid" ]; then
        log_info "Gateway 已重启！(PID: $gateway_pid)"
        echo ""
        
        # 获取并显示 Dashboard URL（带 token）
        echo -e "${CYAN}━━━ 获取 Dashboard URL ━━━${NC}"
        local dashboard_url=$(openclaw dashboard --no-open 2>/dev/null | grep -E "^https?://" | head -1)
        if [ -n "$dashboard_url" ]; then
            echo ""
            echo -e "${GREEN}✓ Dashboard URL (带授权 token):${NC}"
            echo -e "  ${WHITE}$dashboard_url${NC}"
            echo ""
            echo -e "${YELLOW}⚠️  请使用此 URL 访问控制界面，否则会提示 token_missing${NC}"
        else
            echo ""
            echo -e "${YELLOW}提示: 运行以下命令获取带 token 的 Dashboard URL:${NC}"
            echo -e "  ${WHITE}openclaw dashboard${NC}"
        fi
        echo ""
        echo -e "${CYAN}查看日志: ${WHITE}openclaw logs --follow${NC}"
        echo -e "${CYAN}停止服务: ${WHITE}openclaw gateway stop${NC}"
        
        # 渠道状态探针（重启后）
        echo ""
        echo -e "${CYAN}━━━ 渠道状态探针 ━━━${NC}"
        openclaw channels list 2>/dev/null | head -12 | sed 's/^/  /' || echo "  (无法获取渠道状态)"
    else
        log_warn "Gateway 可能未正常启动"
        echo ""
        echo -e "${YELLOW}命令输出:${NC}"
        echo "$restart_output" | head -10 | sed 's/^/  /'
        echo ""
        log_info "尝试按配置端口 ${gateway_port} 直接拉起 Gateway..."
        if command -v setsid &> /dev/null; then
            if [ -f "$OPENCLAW_ENV" ]; then
                setsid bash -c "source $OPENCLAW_ENV && exec openclaw gateway --port ${gateway_port}" > /tmp/openclaw-gateway.log 2>&1 &
            else
                setsid openclaw gateway --port "${gateway_port}" > /tmp/openclaw-gateway.log 2>&1 &
            fi
        else
            if [ -f "$OPENCLAW_ENV" ]; then
                nohup bash -c "source $OPENCLAW_ENV && exec openclaw gateway --port ${gateway_port}" > /tmp/openclaw-gateway.log 2>&1 &
            else
                nohup openclaw gateway --port "${gateway_port}" > /tmp/openclaw-gateway.log 2>&1 &
            fi
            disown 2>/dev/null || true
        fi
        sleep 2
        gateway_pid="$(get_gateway_pid)"
        if [ -n "$gateway_pid" ]; then
            log_info "按端口 ${gateway_port} 启动成功 (PID: $gateway_pid)"
        else
            echo -e "${CYAN}建议:${NC}"
            echo "  • 运行 ${WHITE}openclaw doctor --fix${NC} 修复配置问题"
            echo "  • 运行 ${WHITE}openclaw gateway --port ${gateway_port}${NC} 手动启动"
        fi
    fi
}

# 检查 OpenClaw Gateway 是否运行
check_gateway_running() {
    if check_openclaw_installed; then
        openclaw health &>/dev/null
        return $?
    fi
    return 1
}

# 从 openclaw models status --json 读取当前默认模型
get_current_model_ref() {
    if ! check_openclaw_installed; then
        return 1
    fi

    local model_ref=""
    if command -v node &> /dev/null; then
        model_ref=$(openclaw models status --json 2>/dev/null | node -e '
const fs = require("fs");
try {
  const raw = fs.readFileSync(0, "utf8");
  const data = JSON.parse(raw || "{}");
  const v = (data.resolvedDefault || data.defaultModel || "").trim();
  if (v) process.stdout.write(v);
} catch {}
' 2>/dev/null || true)
    elif command -v python3 &> /dev/null; then
        model_ref=$(openclaw models status --json 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
    v=(d.get("resolvedDefault") or d.get("defaultModel") or "").strip()
    if v: print(v,end="")
except Exception:
    pass
' 2>/dev/null || true)
    else
        model_ref=$(openclaw config get agents.defaults.model.primary 2>/dev/null || true)
        if [ -z "$model_ref" ] || [ "$model_ref" = "undefined" ]; then
            model_ref=$(openclaw config get models.default 2>/dev/null || true)
        fi
    fi

    [ -n "$model_ref" ] && [ "$model_ref" != "undefined" ] && echo "$model_ref"
}

# 测试 AI API 连接
test_ai_connection() {
    local provider=$1
    local api_key=$2
    local model=$3
    local base_url=$4
    
    echo ""
    echo -e "${CYAN}━━━ 测试 AI 配置 ━━━${NC}"
    echo ""
    
    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装"
        return 1
    fi
    
    # 确保环境变量已加载
    [ -f "$OPENCLAW_ENV" ] && source "$OPENCLAW_ENV"
    
    local target_model_ref=""
    if [ -n "$provider" ] && [ -n "$model" ]; then
        target_model_ref="${provider}/${model}"
    else
        target_model_ref="$(get_current_model_ref || true)"
    fi

    echo -e "${CYAN}当前模型配置:${NC}"
    openclaw models status 2>&1 | head -12
    echo ""

    if [ -n "$target_model_ref" ]; then
        echo -e "${CYAN}目标模型:${NC} ${WHITE}${target_model_ref}${NC}"
    fi
    echo ""

    echo -e "${YELLOW}运行官方模型探针 (openclaw models status --probe --check)...${NC}"
    local probe_output=""
    local probe_exit=0
    if [ -n "$provider" ]; then
        probe_output=$(openclaw models status --probe --check --probe-provider "$provider" --json 2>&1)
        probe_exit=$?
    else
        probe_output=$(openclaw models status --probe --check --json 2>&1)
        probe_exit=$?
    fi

    if [ $probe_exit -eq 0 ]; then
        log_info "OpenClaw AI 探针通过，模型认证链路正常。"
        return 0
    fi

    log_warn "模型探针未通过，尝试一次本地 agent 调用获取详细报错..."
    local result=""
    local exit_code=1
    if [ -n "$target_model_ref" ]; then
        result=$(openclaw agent --local --model "$target_model_ref" --message "只回复 OK" 2>&1)
        exit_code=$?
    else
        result=$(openclaw agent --local --message "只回复 OK" 2>&1)
        exit_code=$?
    fi

    echo ""
    if [ $exit_code -eq 0 ] && ! echo "$result" | grep -qiE "error|failed|401|403|Unknown model"; then
        log_info "OpenClaw AI 测试成功！"
        return 0
    fi

    log_error "OpenClaw AI 测试失败"
    echo ""
    echo -e "  ${RED}探针输出:${NC}"
    echo "$probe_output" | head -10 | sed 's/^/    /'
    echo ""
    echo -e "  ${RED}调用输出:${NC}"
    echo "$result" | head -10 | sed 's/^/    /'
    echo ""
    echo "  诊断命令:"
    echo "    openclaw doctor"
    echo "    openclaw models status --probe --check --json"
    return 1
}

# 测试 Telegram 机器人
test_telegram_bot() {
    local token=$1
    local user_id=$2
    
    echo ""
    echo -e "${CYAN}━━━ 测试 Telegram 机器人 ━━━${NC}"
    echo ""
    
    # 1. 验证 Token
    echo -e "${YELLOW}1. 验证 Bot Token...${NC}"
    local bot_info=$(curl -s "https://api.telegram.org/bot${token}/getMe" 2>/dev/null)
    
    if echo "$bot_info" | grep -q '"ok":true'; then
        local bot_name=$(echo "$bot_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['first_name'])" 2>/dev/null)
        local bot_username=$(echo "$bot_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['username'])" 2>/dev/null)
        log_info "Bot 验证成功: $bot_name (@$bot_username)"
    else
        log_error "Bot Token 无效"
        return 1
    fi
    
    # 2. 发送测试消息
    echo ""
    echo -e "${YELLOW}2. 发送测试消息...${NC}"
    
    local message="🦞 OpenClaw 测试消息

这是一条来自配置工具的测试消息。
如果你收到这条消息，说明 Telegram 机器人配置成功！

时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    local send_result=$(curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"$user_id\",
            \"text\": \"$message\",
            \"parse_mode\": \"HTML\"
        }" 2>/dev/null)
    
    if echo "$send_result" | grep -q '"ok":true'; then
        log_info "测试消息发送成功！请检查你的 Telegram"
        return 0
    else
        local error=$(echo "$send_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('description', '未知错误'))" 2>/dev/null)
        log_error "消息发送失败: $error"
        echo ""
        echo -e "${YELLOW}提示: 请确保你已经先向机器人发送过消息${NC}"
        return 1
    fi
}

# 测试 Discord 机器人
test_discord_bot() {
    local token=$1
    local channel_id=$2
    
    echo ""
    echo -e "${CYAN}━━━ 测试 Discord 机器人 ━━━${NC}"
    echo ""
    
    # 1. 验证 Token
    echo -e "${YELLOW}1. 验证 Bot Token...${NC}"
    local bot_info=$(curl -s "https://discord.com/api/v10/users/@me" \
        -H "Authorization: Bot $token" 2>/dev/null)
    
    if echo "$bot_info" | grep -q '"id"'; then
        local bot_name=$(echo "$bot_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('username', 'Unknown'))" 2>/dev/null)
        local bot_id=$(echo "$bot_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id', ''))" 2>/dev/null)
        log_info "Bot 验证成功: $bot_name (ID: $bot_id)"
    else
        log_error "Bot Token 无效"
        return 1
    fi
    
    # 2. 检查机器人所在的服务器
    echo ""
    echo -e "${YELLOW}2. 检查机器人所在的服务器...${NC}"
    local guilds=$(curl -s "https://discord.com/api/v10/users/@me/guilds" \
        -H "Authorization: Bot $token" 2>/dev/null)
    
    local guild_count=$(echo "$guilds" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
    if [ "$guild_count" = "0" ] || [ -z "$guild_count" ]; then
        log_error "机器人尚未加入任何服务器！"
        echo ""
        echo -e "${YELLOW}请先邀请机器人到你的服务器:${NC}"
        echo "  1. Discord Developer Portal → 你的应用 → OAuth2 → URL Generator"
        echo "  2. Scopes 勾选: bot"
        echo "  3. Bot Permissions 勾选: View Channels, Send Messages"
        echo "  4. 复制链接并在浏览器中打开，选择服务器"
        echo ""
        echo -e "${WHITE}邀请链接示例:${NC}"
        echo "  https://discord.com/oauth2/authorize?client_id=${bot_id}&scope=bot&permissions=3072"
        return 1
    else
        log_info "机器人已加入 $guild_count 个服务器"
        # 显示服务器列表
        echo "$guilds" | python3 -c "
import sys, json
guilds = json.load(sys.stdin)
for g in guilds[:5]:
    print(f\"    • {g['name']} (ID: {g['id']})\")
if len(guilds) > 5:
    print(f'    ... 还有 {len(guilds)-5} 个服务器')
" 2>/dev/null
    fi
    
    # 3. 检查频道访问权限
    echo ""
    echo -e "${YELLOW}3. 检查频道访问权限...${NC}"
    local channel_info=$(curl -s "https://discord.com/api/v10/channels/$channel_id" \
        -H "Authorization: Bot $token" 2>/dev/null)
    
    if echo "$channel_info" | grep -q '"id"'; then
        local channel_name=$(echo "$channel_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('name', 'Unknown'))" 2>/dev/null)
        local guild_id=$(echo "$channel_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('guild_id', ''))" 2>/dev/null)
        log_info "频道访问正常: #$channel_name (服务器ID: $guild_id)"
    else
        local error=$(echo "$channel_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message', '未知错误'))" 2>/dev/null)
        log_error "无法访问频道: $error"
        echo ""
        if echo "$error" | grep -qi "Unknown Channel"; then
            echo -e "${YELLOW}频道 ID 可能不正确，请重新复制${NC}"
        else
            echo -e "${YELLOW}机器人可能不在该频道所在的服务器中${NC}"
            echo "  请确保机器人已被邀请到正确的服务器"
        fi
        return 1
    fi
    
    # 4. 发送测试消息
    echo ""
    echo -e "${YELLOW}4. 发送测试消息到频道...${NC}"
    
    # 使用单行消息避免 JSON 格式问题
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="🦞 **OpenClaw 测试消息** - 配置成功！时间: $timestamp"
    
    # 使用 python 正确编码 JSON
    local json_payload
    if command -v python3 &> /dev/null; then
        json_payload=$(python3 -c "import json; print(json.dumps({'content': '$message'}))" 2>/dev/null)
    else
        # 备用方案：简单消息
        json_payload="{\"content\": \"$message\"}"
    fi
    
    local send_result=$(curl -s -X POST "https://discord.com/api/v10/channels/${channel_id}/messages" \
        -H "Authorization: Bot $token" \
        -H "Content-Type: application/json" \
        -d "$json_payload" 2>/dev/null)
    
    if echo "$send_result" | grep -q '"id"'; then
        log_info "测试消息发送成功！请检查 Discord 频道"
        return 0
    else
        local error=$(echo "$send_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message', '未知错误'))" 2>/dev/null)
        local error_code=$(echo "$send_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code', 0))" 2>/dev/null)
        log_error "消息发送失败: $error"
        echo ""
        
        # 根据错误类型给出修复建议
        if echo "$error" | grep -qi "Missing Access"; then
            echo -e "${YELLOW}━━━ 修复 Missing Access 错误 ━━━${NC}"
            echo ""
            echo -e "${WHITE}可能原因:${NC}"
            echo "  1. 机器人未被邀请到该频道所在的服务器"
            echo "  2. 机器人在该频道没有发送消息权限"
            echo "  3. 频道 ID 不正确"
            echo ""
            echo -e "${WHITE}解决方法:${NC}"
            echo "  1. 确认机器人已被邀请到服务器:"
            echo "     • 重新生成邀请链接并邀请机器人"
            echo "     • OAuth2 → URL Generator → 勾选 bot"
            echo "     • Bot Permissions 勾选: Send Messages, View Channels"
            echo ""
            echo "  2. 检查频道权限:"
            echo "     • 右键频道 → 编辑频道 → 权限"
            echo "     • 添加机器人角色，允许「发送消息」「查看频道」"
            echo ""
            echo "  3. 确认频道 ID 正确:"
            echo "     • 开启开发者模式后，右键频道 → 复制 ID"
            echo "     • 当前输入的频道 ID: ${WHITE}$channel_id${NC}"
        elif echo "$error" | grep -qi "Unknown Channel"; then
            echo -e "${YELLOW}提示: 频道 ID 无效，请检查是否正确复制${NC}"
            echo "  当前输入: $channel_id"
        elif echo "$error" | grep -qi "Cannot send messages"; then
            echo -e "${YELLOW}提示: 机器人没有在该频道发送消息的权限${NC}"
            echo "  右键频道 → 编辑频道 → 权限 → 添加机器人并允许发送消息"
        fi
        echo ""
        return 1
    fi
}

# 测试 Slack 机器人
test_slack_bot() {
    local bot_token=$1
    
    echo ""
    echo -e "${CYAN}━━━ 测试 Slack 机器人 ━━━${NC}"
    echo ""
    
    # 验证 Token
    echo -e "${YELLOW}验证 Bot Token...${NC}"
    local auth_result=$(curl -s "https://slack.com/api/auth.test" \
        -H "Authorization: Bearer $bot_token" 2>/dev/null)
    
    if echo "$auth_result" | grep -q '"ok":true'; then
        local team=$(echo "$auth_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('team', 'Unknown'))" 2>/dev/null)
        local user=$(echo "$auth_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('user', 'Unknown'))" 2>/dev/null)
        log_info "Slack 验证成功: $user @ $team"
        return 0
    else
        local error=$(echo "$auth_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error', '未知错误'))" 2>/dev/null)
        log_error "验证失败: $error"
        return 1
    fi
}

# 测试飞书机器人
test_feishu_bot() {
    local app_id=$1
    local app_secret=$2
    local chat_id=$3
    
    echo ""
    echo -e "${CYAN}━━━ 测试飞书机器人 ━━━${NC}"
    echo ""
    
    # 1. 获取 tenant_access_token
    echo -e "${YELLOW}1. 获取 tenant_access_token...${NC}"
    local token_result=$(curl -s -X POST "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
        -H "Content-Type: application/json" \
        -d "{
            \"app_id\": \"$app_id\",
            \"app_secret\": \"$app_secret\"
        }" 2>/dev/null)
    
    local code=$(echo "$token_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code', -1))" 2>/dev/null)
    
    if [ "$code" != "0" ]; then
        local msg=$(echo "$token_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('msg', '未知错误'))" 2>/dev/null)
        log_error "获取 Token 失败: $msg"
        echo ""
        echo -e "${YELLOW}请检查:${NC}"
        echo "  • App ID 和 App Secret 是否正确"
        echo "  • 应用是否已发布"
        return 1
    fi
    
    local access_token=$(echo "$token_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tenant_access_token', ''))" 2>/dev/null)
    log_info "Token 获取成功！"
    
    # 2. 获取机器人信息
    echo ""
    echo -e "${YELLOW}2. 获取机器人信息...${NC}"
    local bot_info=$(curl -s "https://open.feishu.cn/open-apis/bot/v3/info" \
        -H "Authorization: Bearer $access_token" 2>/dev/null)
    
    local bot_code=$(echo "$bot_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code', -1))" 2>/dev/null)
    if [ "$bot_code" = "0" ]; then
        local bot_name=$(echo "$bot_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('bot', {}).get('app_name', 'Unknown'))" 2>/dev/null)
        log_info "机器人: $bot_name"
    else
        log_warn "无法获取机器人信息（可能需要添加机器人能力）"
    fi
    
    # 3. 发送测试消息（如果提供了 chat_id）
    if [ -n "$chat_id" ]; then
        echo ""
        echo -e "${YELLOW}3. 发送测试消息...${NC}"
        
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # 使用 Python 正确构建 JSON，确保 content 是字符串化的 JSON
        local request_body=$(python3 -c "
import json

message = '''🦞 OpenClaw 测试消息

这是一条来自配置工具的测试消息。
如果你收到这条消息，说明飞书机器人配置成功！

时间: $timestamp'''

# content 必须是一个 JSON 字符串（字符串化的 JSON 对象）
content_obj = {'text': message}
content_str = json.dumps(content_obj, ensure_ascii=False)

body = {
    'receive_id': '$chat_id',
    'msg_type': 'text',
    'content': content_str
}
print(json.dumps(body, ensure_ascii=False))
" 2>/dev/null)
        
        echo -e "${GRAY}请求体: $request_body${NC}"
        
        local send_result=$(curl -s -X POST "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id" \
            -H "Authorization: Bearer $access_token" \
            -H "Content-Type: application/json" \
            -d "$request_body" 2>/dev/null)
        
        echo -e "${GRAY}响应: $send_result${NC}"
        echo ""
        
        local send_code=$(echo "$send_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code', -1))" 2>/dev/null)
        if [ "$send_code" = "0" ]; then
            log_info "测试消息发送成功！请检查飞书群组"
        else
            local send_msg=$(echo "$send_result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('msg', '未知错误'))" 2>/dev/null)
            log_error "消息发送失败: $send_msg (code: $send_code)"
            echo ""
            echo -e "${YELLOW}提示:${NC}"
            echo "  • 确保机器人已添加到群组"
            echo "  • 确保有 im:message:send_as_bot 权限"
            echo "  • 群组 ID 可在群设置中查看"
        fi
    else
        echo ""
        echo -e "${GREEN}✓ 飞书应用验证成功！${NC}"
        echo ""
        echo -e "${YELLOW}如需发送测试消息，请提供群组 Chat ID${NC}"
        echo -e "${GRAY}获取方式: 群设置 → 群信息 → 群号${NC}"
    fi
    
    return 0
}

# 测试 Ollama 连接
test_ollama_connection() {
    local base_url=$1
    local model=$2
    
    echo ""
    echo -e "${CYAN}━━━ 测试 Ollama 连接 ━━━${NC}"
    echo ""
    
    # 1. 检查服务是否运行
    echo -e "${YELLOW}1. 检查 Ollama 服务...${NC}"
    local health=$(curl -s "${base_url}/api/tags" 2>/dev/null)
    
    if [ -z "$health" ]; then
        log_error "无法连接到 Ollama 服务: $base_url"
        echo -e "${YELLOW}请确保 Ollama 正在运行: ollama serve${NC}"
        return 1
    fi
    log_info "Ollama 服务运行正常"
    
    # 2. 检查模型是否存在
    echo ""
    echo -e "${YELLOW}2. 检查模型 $model...${NC}"
    if echo "$health" | grep -q "\"name\":\"$model\""; then
        log_info "模型 $model 已安装"
    else
        log_warn "模型 $model 可能未安装"
        echo -e "${YELLOW}运行以下命令安装: ollama pull $model${NC}"
    fi
    
    # 3. 测试生成
    echo ""
    echo -e "${YELLOW}3. 测试模型响应...${NC}"
    local response=$(curl -s "${base_url}/api/generate" \
        -d "{\"model\": \"$model\", \"prompt\": \"Say hello\", \"stream\": false}" 2>/dev/null)
    
    if echo "$response" | grep -q '"response"'; then
        log_info "模型响应测试成功"
        return 0
    else
        log_error "模型响应测试失败"
        return 1
    fi
}

# 测试 WhatsApp (通过 openclaw status)
test_whatsapp() {
    echo ""
    echo -e "${CYAN}━━━ 测试 WhatsApp 连接 ━━━${NC}"
    echo ""
    
    if check_openclaw_installed; then
        echo -e "${YELLOW}检查 WhatsApp 渠道状态...${NC}"
        echo ""
        openclaw status 2>/dev/null | grep -i whatsapp || echo "WhatsApp 渠道未配置"
        echo ""
        echo -e "${CYAN}提示: 使用 'openclaw channels login' 配置 WhatsApp${NC}"
        return 0
    else
        log_warn "WhatsApp 测试需要 OpenClaw 已安装"
        echo -e "${YELLOW}请先完成 OpenClaw 安装${NC}"
        return 1
    fi
}

# 测试 iMessage (通过 openclaw status)
test_imessage() {
    echo ""
    echo -e "${CYAN}━━━ 测试 iMessage 连接 ━━━${NC}"
    echo ""
    
    if check_openclaw_installed; then
        echo -e "${YELLOW}检查 iMessage 渠道状态...${NC}"
        echo ""
        openclaw status 2>/dev/null | grep -i imessage || echo "iMessage 渠道未配置"
        return 0
    else
        log_warn "iMessage 测试需要 OpenClaw 已安装"
        echo -e "${YELLOW}请先完成 OpenClaw 安装${NC}"
        return 1
    fi
}

# 测试微信 (通过 openclaw status)
test_wechat() {
    echo ""
    echo -e "${CYAN}━━━ 测试微信连接 ━━━${NC}"
    echo ""
    
    if check_openclaw_installed; then
        echo -e "${YELLOW}检查微信渠道状态...${NC}"
        echo ""
        openclaw status 2>/dev/null | grep -i wechat || echo "微信渠道未配置"
        return 0
    else
        log_warn "微信测试需要 OpenClaw 已安装"
        echo -e "${YELLOW}请先完成 OpenClaw 安装${NC}"
        return 1
    fi
}

# 运行 OpenClaw 诊断 (使用 openclaw doctor)
run_openclaw_doctor() {
    echo ""
    echo -e "${CYAN}━━━ OpenClaw 诊断 ━━━${NC}"
    echo ""
    
    if check_openclaw_installed; then
        openclaw doctor
        return $?
    else
        log_error "OpenClaw 未安装"
        echo -e "${YELLOW}请先运行 install.sh 安装 OpenClaw${NC}"
        return 1
    fi
}

# 运行 OpenClaw 状态检查 (使用 openclaw status)
run_openclaw_status() {
    echo ""
    echo -e "${CYAN}━━━ OpenClaw 状态 ━━━${NC}"
    echo ""
    
    if check_openclaw_installed; then
        openclaw status
        return $?
    else
        log_error "OpenClaw 未安装"
        return 1
    fi
}

# 运行 OpenClaw 健康检查 (使用 openclaw health)
run_openclaw_health() {
    echo ""
    echo -e "${CYAN}━━━ Gateway 健康检查 ━━━${NC}"
    echo ""
    
    if check_openclaw_installed; then
        openclaw health
        return $?
    else
        log_error "OpenClaw 未安装"
        return 1
    fi
}

run_official_model_onboard() {
    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装"
        return 1
    fi
    echo ""
    log_info "启动官方模型配置向导: openclaw onboard"
    if [ -e /dev/tty ]; then
        openclaw onboard < /dev/tty
    else
        openclaw onboard
    fi
}

# ================================ 状态显示 ================================

show_status() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📊 系统状态${NC}"
    print_divider
    echo ""
    
    # OpenClaw 服务状态
    if check_openclaw_installed; then
        echo -e "  ${GREEN}✓${NC} OpenClaw 已安装: $(openclaw --version 2>/dev/null || echo 'unknown')"
        
        # 使用端口检测判断服务运行状态（更可靠）
        local status_pid
        status_pid=$(get_gateway_pid)
        if [ -n "$status_pid" ]; then
            echo -e "  ${GREEN}●${NC} 服务状态: ${GREEN}运行中${NC} (PID: $status_pid)"
        else
            echo -e "  ${RED}●${NC} 服务状态: ${RED}已停止${NC}"
        fi
    else
        echo -e "  ${RED}✗${NC} OpenClaw 未安装"
    fi
    
    echo ""
    
    # 当前配置
    if [ -f "$OPENCLAW_ENV" ]; then
        echo ""
        echo -e "  ${CYAN}当前配置:${NC}"
        
        # 显示 OpenClaw 模型配置
        if check_openclaw_installed; then
            local default_model
            default_model="$(get_current_model_ref || true)"
            [ -z "$default_model" ] && default_model="未配置"
            echo -e "    • 默认模型: ${WHITE}$default_model${NC}"
        fi
        
        # 检查 API Key 配置
        if grep -q "ANTHROPIC_API_KEY" "$OPENCLAW_ENV" 2>/dev/null; then
            echo -e "    • AI 提供商: ${WHITE}Anthropic${NC}"
        elif grep -q "OPENAI_API_KEY" "$OPENCLAW_ENV" 2>/dev/null; then
            echo -e "    • AI 提供商: ${WHITE}OpenAI${NC}"
        elif grep -q "GOOGLE_API_KEY" "$OPENCLAW_ENV" 2>/dev/null; then
            echo -e "    • AI 提供商: ${WHITE}Google${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} 环境变量未配置"
    fi
    
    echo ""
    
    # 目录状态
    echo -e "  ${CYAN}目录结构:${NC}"
    [ -d "$CONFIG_DIR" ] && echo -e "    ${GREEN}✓${NC} 配置目录: $CONFIG_DIR" || echo -e "    ${RED}✗${NC} 配置目录"
    [ -f "$OPENCLAW_ENV" ] && echo -e "    ${GREEN}✓${NC} 环境变量: $OPENCLAW_ENV" || echo -e "    ${RED}✗${NC} 环境变量"
    [ -f "$OPENCLAW_JSON" ] && echo -e "    ${GREEN}✓${NC} OpenClaw 配置: $OPENCLAW_JSON" || echo -e "    ${YELLOW}⚠${NC} OpenClaw 配置"
    
    echo ""
    print_divider
    press_enter
}

# ================================ AI 模型配置 ================================

config_ai_model() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🤖 AI 模型配置${NC}"
    print_divider
    echo ""

    echo -e "${CYAN}推荐优先使用官方向导（模型列表与参数始终最新）${NC}"
    if confirm "是否启动官方向导 openclaw onboard？" "y"; then
        if run_official_model_onboard; then
            log_info "官方模型配置完成。"
            press_enter
            return
        fi
        log_warn "官方向导执行失败，继续使用本地兼容配置菜单。"
        echo ""
    fi
    
    echo -e "${CYAN}选择 AI 提供商:${NC}"
    echo -e "${GRAY}提示: 支持自定义 API 地址（通过自定义 Provider 配置）${NC}"
    echo ""
    echo -e "${WHITE}主流服务商:${NC}"
    print_menu_item "1" "Anthropic Claude" "🟣"
    print_menu_item "2" "OpenAI GPT" "🟢"
    print_menu_item "3" "DeepSeek" "🔵"
    print_menu_item "4" "Kimi (Moonshot)" "🌙"
    print_menu_item "5" "Google Gemini" "🔴"
    echo ""
    echo -e "${WHITE}多模型网关:${NC}"
    print_menu_item "6" "OpenRouter (多模型网关)" "🔄"
    print_menu_item "7" "OpenCode (免费多模型)" "🆓"
    echo ""
    echo -e "${WHITE}快速推理:${NC}"
    print_menu_item "8" "Groq (超快推理)" "⚡"
    print_menu_item "9" "Mistral AI" "🌬️"
    echo ""
    echo -e "${WHITE}本地/企业:${NC}"
    print_menu_item "10" "Ollama 本地模型" "🟠"
    print_menu_item "11" "Azure OpenAI" "☁️"
    echo ""
    echo -e "${WHITE}国产/其他:${NC}"
    print_menu_item "12" "xAI Grok" "𝕏"
    print_menu_item "13" "智谱 GLM (Zai)" "🇨🇳"
    print_menu_item "14" "MiniMax" "🤖"
    echo ""
    echo -e "${WHITE}实验性:${NC}"
    print_menu_item "15" "Google Gemini CLI" "🧪"
    print_menu_item "16" "Google Antigravity" "🚀"
    echo ""
    echo -e "${WHITE}高性能推理:${NC}"
    print_menu_item "17" "Novita AI (Kimi/DeepSeek/GLM)" "🚀"
    echo ""
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""

    echo -en "${YELLOW}请选择 [0-17]: ${NC}"
    read choice < "$TTY_INPUT"

    case $choice in
        1) config_anthropic ;;
        2) config_openai ;;
        3) config_deepseek ;;
        4) config_kimi ;;
        5) config_google_gemini ;;
        6) config_openrouter ;;
        7) config_opencode ;;
        8) config_groq ;;
        9) config_mistral ;;
        10) config_ollama ;;
        11) config_azure_openai ;;
        12) config_xai ;;
        13) config_zai ;;
        14) config_minimax ;;
        15) config_google_gemini_cli ;;
        16) config_google_antigravity ;;
        17) config_novita ;;
        0) return ;;
        *) log_error "无效选择"; press_enter; config_ai_model ;;
    esac
}

config_anthropic() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🟣 配置 Anthropic Claude${NC}"
    print_divider
    echo ""
    
    # 获取当前配置
    local current_key=$(get_env_value "ANTHROPIC_API_KEY")
    local current_url=$(get_env_value "ANTHROPIC_BASE_URL")
    local official_url="https://api.anthropic.com"
    
    # 显示当前配置
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    if [ -n "$current_url" ]; then
        echo -e "  API 地址: ${WHITE}$current_url${NC}"
    else
        echo -e "  API 地址: ${GRAY}(使用官方)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
    echo -e "${GRAY}获取 Key: https://console.anthropic.com/${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key 和地址)" "🔄"
    print_menu_item "2" "完整配置 (可修改所有设置)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    local base_url="$current_url"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        echo -e "${CYAN}API 地址配置:${NC}"
        [ -n "$current_url" ] && echo -e "  当前地址: ${WHITE}$current_url${NC}"
        echo -e "  官方地址: ${WHITE}$official_url${NC}"
        echo ""
        read -p "$(echo -e "${YELLOW}输入 API 地址 (留空保持当前配置): ${NC}")" input_url < "$TTY_INPUT"
        
        # 留空时保持当前配置
        if [ -n "$input_url" ]; then
            base_url="$input_url"
        fi
        
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "Claude Sonnet 4.6 (推荐, 官方默认)" "⭐"
    print_menu_item "2" "Claude Opus 4.6 (最强)" "👑"
    print_menu_item "3" "Claude 4.5 Haiku (快速)" "⚡"
    print_menu_item "4" "Claude Sonnet 4.5 (兼容)" "📦"
    print_menu_item "5" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="claude-sonnet-4-6" ;;
        2) model="claude-opus-4-6" ;;
        3) model="claude-haiku-4-5" ;;
        4) model="claude-sonnet-4-5" ;;
        5) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="claude-sonnet-4-6" ;;
    esac
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "anthropic" "$api_key" "$model" "$base_url"
    
    echo ""
    log_info "Anthropic Claude 配置完成！"
    log_info "模型: $model"
    [ -n "$base_url" ] && log_info "API 地址: $base_url" || log_info "API 地址: 官方"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "anthropic" "$api_key" "$model" "$base_url"
    fi
    
    press_enter
}

config_openai() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🟢 配置 OpenAI GPT${NC}"
    print_divider
    echo ""
    
    # 获取当前配置
    local current_key=$(get_env_value "OPENAI_API_KEY")
    local current_url=$(get_env_value "OPENAI_BASE_URL")
    local official_url="https://api.openai.com/v1"
    
    # 显示当前配置
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    if [ -n "$current_url" ]; then
        echo -e "  API 地址: ${WHITE}$current_url${NC}"
    else
        echo -e "  API 地址: ${GRAY}(使用官方)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
    echo -e "${GRAY}获取 Key: https://platform.openai.com/${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key 和地址)" "🔄"
    print_menu_item "2" "完整配置 (可修改所有设置)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    local base_url="$current_url"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        echo -e "${CYAN}API 地址配置:${NC}"
        [ -n "$current_url" ] && echo -e "  当前地址: ${WHITE}$current_url${NC}"
        echo -e "  官方地址: ${WHITE}$official_url${NC}"
        echo ""
        read -p "$(echo -e "${YELLOW}输入 API 地址 (留空保持当前配置): ${NC}")" input_url < "$TTY_INPUT"
        
        if [ -n "$input_url" ]; then
            base_url="$input_url"
        fi
        
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "GPT-5.1-Codex (推荐, 官方默认)" "⭐"
    print_menu_item "2" "GPT-5.4 (最新通用)" "🚀"
    print_menu_item "3" "GPT-5.1" "⚡"
    print_menu_item "4" "GPT-5.1-Codex-Mini (经济)" "💰"
    print_menu_item "5" "GPT-4.1 (兼容)" "🧠"
    print_menu_item "6" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-6] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="gpt-5.1-codex" ;;
        2) model="gpt-5.4" ;;
        3) model="gpt-5.1" ;;
        4) model="gpt-5.1-codex-mini" ;;
        5) model="gpt-4.1" ;;
        6) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="gpt-5.1-codex" ;;
    esac
    
    # 如果使用自定义 API 地址，询问 API 类型
    local api_type=""
    if [ -n "$base_url" ]; then
        echo ""
        echo -e "${CYAN}选择 API 兼容格式:${NC}"
        echo ""
        print_menu_item "1" "openai-responses (OpenAI 官方 Responses API)" "🔵"
        print_menu_item "2" "openai-completions (兼容 /v1/chat/completions)" "🟢"
        echo ""
        echo -e "${GRAY}提示: 大多数第三方服务使用 openai-completions 格式${NC}"
        echo ""
        read -p "$(echo -e "${YELLOW}选择 API 格式 [1-2] (默认: 2): ${NC}")" api_type_choice < "$TTY_INPUT"
        case $api_type_choice in
            1) api_type="openai-responses" ;;
            *) api_type="openai-completions" ;;
        esac
    fi
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "openai" "$api_key" "$model" "$base_url" "$api_type"
    
    echo ""
    log_info "OpenAI GPT 配置完成！"
    log_info "模型: $model"
    [ -n "$base_url" ] && log_info "API 地址: $base_url" || log_info "API 地址: 官方"
    [ -n "$api_type" ] && log_info "API 格式: $api_type"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "openai" "$api_key" "$model" "$base_url"
    fi
    
    press_enter
}

config_deepseek() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔵 配置 DeepSeek${NC}"
    print_divider
    echo ""
    
    # 获取当前配置
    local current_key=$(get_env_value "DEEPSEEK_API_KEY")
    local current_url=$(get_env_value "DEEPSEEK_BASE_URL")
    local official_url="https://api.deepseek.com"
    
    # 显示当前配置
    echo -e "${CYAN}DeepSeek 提供高性能 AI 模型，支持 OpenAI 兼容格式${NC}"
    echo ""
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    if [ -n "$current_url" ]; then
        echo -e "  API 地址: ${WHITE}$current_url${NC}"
    else
        echo -e "  API 地址: ${GRAY}(使用官方)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
    echo -e "${GRAY}获取 Key: https://platform.deepseek.com/${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key 和地址)" "🔄"
    print_menu_item "2" "完整配置 (可修改所有设置)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    local base_url="${current_url:-$official_url}"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        echo -e "${CYAN}API 地址配置:${NC}"
        [ -n "$current_url" ] && echo -e "  当前地址: ${WHITE}$current_url${NC}"
        echo -e "  官方地址: ${WHITE}$official_url${NC}"
        echo ""
        read -p "$(echo -e "${YELLOW}输入 API 地址 (留空保持当前配置): ${NC}")" input_url < "$TTY_INPUT"
        
        if [ -n "$input_url" ]; then
            base_url="$input_url"
        fi
        
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "deepseek-chat (V3.2, 推荐)" "⭐"
    print_menu_item "2" "deepseek-reasoner (R1, 推理)" "🧠"
    print_menu_item "3" "deepseek-coder (代码)" "💻"
    print_menu_item "4" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-4] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="deepseek-chat" ;;
        2) model="deepseek-reasoner" ;;
        3) model="deepseek-coder" ;;
        4) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="deepseek-chat" ;;
    esac
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "deepseek" "$api_key" "$model" "$base_url"
    
    echo ""
    log_info "DeepSeek 配置完成！"
    log_info "模型: $model"
    log_info "API 地址: $base_url"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "deepseek" "$api_key" "$model" "$base_url"
    fi
    
    press_enter
}

config_kimi() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🌙 配置 Kimi (Moonshot)${NC}"
    print_divider
    echo ""
    
    # 获取当前配置
    local current_key=$(get_env_value "MOONSHOT_API_KEY")
    local current_url=$(get_env_value "MOONSHOT_BASE_URL")
    local official_url="https://api.moonshot.ai/v1"
    
    # 显示当前配置
    echo -e "${CYAN}Kimi 是月之暗面（Moonshot AI）推出的大语言模型${NC}"
    echo ""
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    if [ -n "$current_url" ]; then
        echo -e "  API 地址: ${WHITE}$current_url${NC}"
    else
        echo -e "  API 地址: ${GRAY}(使用官方)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}官方 API: ${WHITE}https://api.moonshot.ai/v1${NC}"
    echo -e "${CYAN}国内 API: ${WHITE}https://api.moonshot.cn/v1${NC}"
    echo -e "${GRAY}获取 Key: https://platform.moonshot.cn/${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key 和地址)" "🔄"
    print_menu_item "2" "完整配置 (可修改所有设置)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    local base_url="${current_url:-$official_url}"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        echo -e "${CYAN}API 地址配置:${NC}"
        print_menu_item "1" "国际版 API (api.moonshot.ai)" "🌍"
        print_menu_item "2" "国内版 API (api.moonshot.cn)" "🇨🇳"
        read -p "$(echo -e "${YELLOW}区域选择 [1-2] (默认: 1): ${NC}")" moonshot_region < "$TTY_INPUT"
        if [ "${moonshot_region:-1}" = "2" ]; then
            base_url="https://api.moonshot.cn/v1"
        else
            base_url="https://api.moonshot.ai/v1"
        fi
        echo ""
        [ -n "$current_url" ] && echo -e "  当前地址: ${WHITE}$current_url${NC}"
        echo -e "  建议地址: ${WHITE}$base_url${NC}"
        echo ""
        read -p "$(echo -e "${YELLOW}输入 API 地址 (留空保持当前配置): ${NC}")" input_url < "$TTY_INPUT"
        
        if [ -n "$input_url" ]; then
            base_url="$input_url"
        fi
        
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "kimi-k2.5 (推荐, 官方默认)" "⭐"
    print_menu_item "2" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="kimi-k2.5" ;;
        2) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="kimi-k2.5" ;;
    esac
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "moonshot" "$api_key" "$model" "$base_url"
    
    echo ""
    log_info "Kimi (Moonshot) 配置完成！"
    log_info "模型: $model"
    log_info "API 地址: $base_url"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "moonshot" "$api_key" "$model" "$base_url"
    fi
    
    press_enter
}

config_ollama() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🟠 配置 Ollama 本地模型${NC}"
    print_divider
    echo ""
    
    # 获取当前配置
    local current_url=$(get_env_value "OLLAMA_HOST")
    local default_url="http://localhost:11434"
    
    echo -e "${CYAN}Ollama 允许你在本地运行 AI 模型，无需 API Key${NC}"
    echo ""
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_url" ]; then
        echo -e "  服务地址: ${WHITE}$current_url${NC}"
    else
        echo -e "  服务地址: ${GRAY}(使用默认)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}默认地址: ${WHITE}$default_url${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前服务地址)" "🔄"
    print_menu_item "2" "完整配置 (可修改服务地址)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local ollama_url="${current_url:-$default_url}"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        echo -e "${CYAN}服务地址配置:${NC}"
        [ -n "$current_url" ] && echo -e "  当前地址: ${WHITE}$current_url${NC}"
        echo -e "  默认地址: ${WHITE}$default_url${NC}"
        echo ""
        read -p "$(echo -e "${YELLOW}输入服务地址 (留空保持当前配置): ${NC}")" input_url < "$TTY_INPUT"
        
        if [ -n "$input_url" ]; then
            ollama_url="$input_url"
        fi
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "Llama 3 (8B)" "🦙"
    print_menu_item "2" "Llama 3 (70B)" "🦙"
    print_menu_item "3" "Mistral" "🌬️"
    print_menu_item "4" "CodeLlama" "💻"
    print_menu_item "5" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="llama3" ;;
        2) model="llama3:70b" ;;
        3) model="mistral" ;;
        4) model="codellama" ;;
        5) 
            read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT"
            ;;
        *) model="llama3" ;;
    esac
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "ollama" "" "$model" "$ollama_url"
    
    echo ""
    log_info "Ollama 配置完成！"
    log_info "服务地址: $ollama_url"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 Ollama 连接？" "y"; then
        test_ollama_connection "$ollama_url" "$model"
    fi
    
    press_enter
}

config_openrouter() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔵 配置 OpenRouter${NC}"
    print_divider
    echo ""
    
    # 获取当前配置
    local current_key=$(get_env_value "OPENROUTER_API_KEY")
    local current_url=$(get_env_value "OPENROUTER_BASE_URL")
    local official_url="https://openrouter.ai/api/v1"
    
    # 显示当前配置
    echo -e "${CYAN}OpenRouter 是一个多模型网关，支持多种 AI 模型${NC}"
    echo ""
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    if [ -n "$current_url" ]; then
        echo -e "  API 地址: ${WHITE}$current_url${NC}"
    else
        echo -e "  API 地址: ${GRAY}(使用默认)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
    echo -e "${GRAY}获取 Key: https://openrouter.ai/${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key 和地址)" "🔄"
    print_menu_item "2" "完整配置 (可修改所有设置)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    local base_url="${current_url:-$official_url}"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        echo -e "${CYAN}API 地址配置:${NC}"
        [ -n "$current_url" ] && echo -e "  当前地址: ${WHITE}$current_url${NC}"
        echo -e "  默认地址: ${WHITE}$official_url${NC}"
        echo ""
        read -p "$(echo -e "${YELLOW}输入 API 地址 (留空保持当前配置): ${NC}")" input_url < "$TTY_INPUT"
        
        if [ -n "$input_url" ]; then
            base_url="$input_url"
        fi
        
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "auto (推荐, 官方默认)" "🧭"
    print_menu_item "2" "anthropic/claude-opus-4.6" "🟣"
    print_menu_item "3" "openai/gpt-5.1-codex" "🟢"
    print_menu_item "4" "google/gemini-3.1-pro-preview" "🔴"
    print_menu_item "5" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="auto" ;;
        2) model="anthropic/claude-opus-4.6" ;;
        3) model="openai/gpt-5.1-codex" ;;
        4) model="google/gemini-3.1-pro-preview" ;;
        5) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="auto" ;;
    esac
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "openrouter" "$api_key" "$model" "$base_url"
    
    echo ""
    log_info "OpenRouter 配置完成！"
    log_info "模型: $model"
    log_info "API 地址: $base_url"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "openrouter" "$api_key" "$model" "$base_url"
    fi
    
    press_enter
}

config_google_gemini() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔴 配置 Google Gemini${NC}"
    print_divider
    echo ""
    
    # 获取当前配置
    local current_key=$(get_env_value "GOOGLE_API_KEY")
    local current_url=$(get_env_value "GOOGLE_BASE_URL")
    local official_url="https://generativelanguage.googleapis.com"
    
    # 显示当前配置
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    if [ -n "$current_url" ]; then
        echo -e "  API 地址: ${WHITE}$current_url${NC}"
    else
        echo -e "  API 地址: ${GRAY}(使用官方)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
    echo -e "${GRAY}获取 Key: https://aistudio.google.com/apikey${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key 和地址)" "🔄"
    print_menu_item "2" "完整配置 (可修改所有设置)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    local base_url="$current_url"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        echo -e "${CYAN}API 地址配置:${NC}"
        [ -n "$current_url" ] && echo -e "  当前地址: ${WHITE}$current_url${NC}"
        echo -e "  官方地址: ${WHITE}$official_url${NC}"
        echo ""
        read -p "$(echo -e "${YELLOW}输入 API 地址 (留空保持当前配置): ${NC}")" input_url < "$TTY_INPUT"
        
        if [ -n "$input_url" ]; then
            base_url="$input_url"
        fi
        
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "gemini-3.1-pro-preview (推荐, 官方默认)" "⭐"
    print_menu_item "2" "gemini-3-flash-preview" "🚀"
    print_menu_item "3" "gemini-2.5-pro" "📦"
    print_menu_item "4" "gemini-2.5-flash" "⚡"
    print_menu_item "5" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="gemini-3.1-pro-preview" ;;
        2) model="gemini-3-flash-preview" ;;
        3) model="gemini-2.5-pro" ;;
        4) model="gemini-2.5-flash" ;;
        5) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="gemini-3.1-pro-preview" ;;
    esac
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "google" "$api_key" "$model" "$base_url"
    
    echo ""
    log_info "Google Gemini 配置完成！"
    log_info "模型: $model"
    [ -n "$base_url" ] && log_info "API 地址: $base_url" || log_info "API 地址: 官方"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "google" "$api_key" "$model" "$base_url"
    fi
    
    press_enter
}

config_azure_openai() {
    clear_screen
    print_header
    
    echo -e "${WHITE}☁️ 配置 Azure OpenAI${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}Azure OpenAI 需要以下信息:${NC}"
    echo "  - Azure 端点 URL"
    echo "  - API Key"
    echo "  - 部署名称"
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入 Azure 端点 URL: ${NC}")" azure_endpoint
    read_secret_input "${YELLOW}输入 API Key: ${NC}" api_key
    read -p "$(echo -e "${YELLOW}输入部署名称 (Deployment Name): ${NC}")" deployment_name
    read -p "$(echo -e "${YELLOW}API 版本 (默认: 2024-02-15-preview): ${NC}")" api_version
    api_version=${api_version:-"2024-02-15-preview"}
    
    if [ -n "$azure_endpoint" ] && [ -n "$api_key" ] && [ -n "$deployment_name" ]; then
        
        echo ""
        log_info "Azure OpenAI 配置完成！"
        log_info "端点: $azure_endpoint"
        log_info "部署: $deployment_name"
    else
        log_error "配置不完整，已取消"
    fi
    
    press_enter
}

config_groq() {
    clear_screen
    print_header
    
    echo -e "${WHITE}⚡ 配置 Groq${NC}"
    print_divider
    echo ""
    
    # 获取当前配置 (Groq 使用 OPENAI 环境变量)
    local current_key=$(get_env_value "OPENAI_API_KEY")
    local current_url=$(get_env_value "OPENAI_BASE_URL")
    local official_url="https://api.groq.com/openai/v1"
    
    # 显示当前配置
    echo -e "${CYAN}Groq 提供超快的推理速度${NC}"
    echo ""
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    if [ -n "$current_url" ]; then
        echo -e "  API 地址: ${WHITE}$current_url${NC}"
    else
        echo -e "  API 地址: ${GRAY}(使用默认)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
    echo -e "${GRAY}获取 Key: https://console.groq.com/${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key 和地址)" "🔄"
    print_menu_item "2" "完整配置 (可修改所有设置)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    local base_url="${current_url:-$official_url}"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        echo -e "${CYAN}API 地址配置:${NC}"
        [ -n "$current_url" ] && echo -e "  当前地址: ${WHITE}$current_url${NC}"
        echo -e "  默认地址: ${WHITE}$official_url${NC}"
        echo ""
        read -p "$(echo -e "${YELLOW}输入 API 地址 (留空保持当前配置): ${NC}")" input_url < "$TTY_INPUT"
        
        if [ -n "$input_url" ]; then
            base_url="$input_url"
        fi
        
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "llama-3.3-70b-versatile (推荐)" "⭐"
    print_menu_item "2" "llama-3.1-8b-instant" "⚡"
    print_menu_item "3" "mixtral-8x7b-32768" "🌬️"
    print_menu_item "4" "gemma2-9b-it" "💎"
    print_menu_item "5" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="llama-3.3-70b-versatile" ;;
        2) model="llama-3.1-8b-instant" ;;
        3) model="mixtral-8x7b-32768" ;;
        4) model="gemma2-9b-it" ;;
        5) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="llama-3.3-70b-versatile" ;;
    esac
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "groq" "$api_key" "$model" "$base_url"
    
    echo ""
    log_info "Groq 配置完成！"
    log_info "模型: $model"
    log_info "API 地址: $base_url"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "groq" "$api_key" "$model" "$base_url"
    fi
    
    press_enter
}

config_mistral() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🌬️ 配置 Mistral AI${NC}"
    print_divider
    echo ""
    
    # 获取当前配置 (Mistral 使用 OPENAI 环境变量)
    local current_key=$(get_env_value "OPENAI_API_KEY")
    local current_url=$(get_env_value "OPENAI_BASE_URL")
    local official_url="https://api.mistral.ai/v1"
    
    # 显示当前配置
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    if [ -n "$current_url" ]; then
        echo -e "  API 地址: ${WHITE}$current_url${NC}"
    else
        echo -e "  API 地址: ${GRAY}(使用默认)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
    echo -e "${GRAY}获取 Key: https://console.mistral.ai/${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key 和地址)" "🔄"
    print_menu_item "2" "完整配置 (可修改所有设置)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    local base_url="${current_url:-$official_url}"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        echo -e "${CYAN}API 地址配置:${NC}"
        [ -n "$current_url" ] && echo -e "  当前地址: ${WHITE}$current_url${NC}"
        echo -e "  默认地址: ${WHITE}$official_url${NC}"
        echo ""
        read -p "$(echo -e "${YELLOW}输入 API 地址 (留空保持当前配置): ${NC}")" input_url < "$TTY_INPUT"
        
        if [ -n "$input_url" ]; then
            base_url="$input_url"
        fi
        
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "mistral-large-latest (推荐)" "⭐"
    print_menu_item "2" "mistral-small-latest" "⚡"
    print_menu_item "3" "codestral-latest" "💻"
    print_menu_item "4" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-4] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="mistral-large-latest" ;;
        2) model="mistral-small-latest" ;;
        3) model="codestral-latest" ;;
        4) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="mistral-large-latest" ;;
    esac
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "mistral" "$api_key" "$model" "$base_url"
    
    echo ""
    log_info "Mistral AI 配置完成！"
    log_info "模型: $model"
    log_info "API 地址: $base_url"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "mistral" "$api_key" "$model" "$base_url"
    fi
    
    press_enter
}

config_xai() {
    clear_screen
    print_header
    
    echo -e "${WHITE}𝕏 配置 xAI Grok${NC}"
    print_divider
    echo ""
    
    # 获取当前配置
    local current_key=$(get_env_value "XAI_API_KEY")
    local official_url="https://api.x.ai/v1"
    
    # 显示当前配置
    echo -e "${CYAN}xAI 是 Elon Musk 创立的 AI 公司，提供 Grok 系列模型${NC}"
    echo ""
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
    echo -e "${GRAY}获取 Key: https://console.x.ai/${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key)" "🔄"
    print_menu_item "2" "完整配置 (可修改 API Key)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "grok-4 (推荐, 官方默认)" "⭐"
    print_menu_item "2" "grok-4-fast" "⚡"
    print_menu_item "3" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-3] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="grok-4" ;;
        2) model="grok-4-fast" ;;
        3) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="grok-4" ;;
    esac
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "xai" "$api_key" "$model" ""
    
    echo ""
    log_info "xAI Grok 配置完成！"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "xai" "$api_key" "$model" ""
    fi
    
    press_enter
}

config_zai() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🇨🇳 配置智谱 GLM (Zai)${NC}"
    print_divider
    echo ""
    
    # 获取当前配置
    local current_key=$(get_env_value "ZAI_API_KEY")
    local official_url="https://open.bigmodel.cn/api/paas/v4"
    
    # 显示当前配置
    echo -e "${CYAN}智谱 AI 是中国领先的 AI 公司，提供 GLM 系列模型${NC}"
    echo ""
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
    echo -e "${GRAY}获取 Key: https://open.bigmodel.cn/${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key)" "🔄"
    print_menu_item "2" "完整配置 (可修改 API Key)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "glm-5 (推荐，最新)" "⭐"
    print_menu_item "2" "glm-4.7" "📦"
    print_menu_item "3" "glm-4.7-flash" "⚡"
    print_menu_item "4" "glm-4.7-flashx" "🔥"
    print_menu_item "5" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="glm-5" ;;
        2) model="glm-4.7" ;;
        3) model="glm-4.7-flash" ;;
        4) model="glm-4.7-flashx" ;;
        5) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="glm-5" ;;
    esac
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "zai" "$api_key" "$model" ""
    
    echo ""
    log_info "智谱 GLM 配置完成！"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "zai" "$api_key" "$model" ""
    fi
    
    press_enter
}

config_minimax() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🤖 配置 MiniMax${NC}"
    print_divider
    echo ""
    
    # 获取当前配置
    local current_key=$(get_env_value "MINIMAX_API_KEY")
    
    # 显示当前配置
    echo -e "${CYAN}MiniMax 是中国领先的 AI 公司，提供大语言模型服务${NC}"
    echo ""
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}获取 API Key:${NC}"
    echo -e "  🌍 国际版: ${WHITE}https://platform.minimax.io/${NC}"
    echo -e "  🇨🇳 国内版: ${WHITE}https://platform.minimaxi.com/${NC}"
    echo ""
    print_divider
    echo ""
    
    echo -e "${YELLOW}选择区域:${NC}"
    print_menu_item "1" "国际版 (minimax)" "🌍"
    print_menu_item "2" "国内版 (minimax-cn)" "🇨🇳"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" region_choice < "$TTY_INPUT"
    region_choice=${region_choice:-1}
    
    local provider="minimax"
    if [ "$region_choice" = "2" ]; then
        provider="minimax-cn"
    fi
    
    echo ""
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key)" "🔄"
    print_menu_item "2" "完整配置 (可修改 API Key)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "MiniMax-M2.7 (推荐，最新旗舰)" "⭐"
    print_menu_item "2" "MiniMax-M2.7-highspeed (高速版)" "⚡"
    print_menu_item "3" "MiniMax-M2.5" "🔹"
    print_menu_item "4" "MiniMax-M2.5-highspeed" "🔹"
    print_menu_item "5" "自定义模型名称" "✏️"
    echo ""

    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}

    case $model_choice in
        1) model="MiniMax-M2.7" ;;
        2) model="MiniMax-M2.7-highspeed" ;;
        3) model="MiniMax-M2.5" ;;
        4) model="MiniMax-M2.5-highspeed" ;;
        5) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="MiniMax-M2.7" ;;
    esac
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "$provider" "$api_key" "$model" ""
    
    echo ""
    log_info "MiniMax 配置完成！"
    log_info "区域: $provider"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "$provider" "$api_key" "$model" ""
    fi
    
    press_enter
}

config_opencode() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🆓 配置 OpenCode${NC}"
    print_divider
    echo ""
    
    # 获取当前配置
    local current_key=$(get_env_value "OPENCODE_API_KEY")
    local official_url="https://opencode.ai/zen/v1"
    
    # 显示当前配置
    echo -e "${CYAN}OpenCode 是一个免费的多模型 API 网关${NC}"
    echo -e "${GREEN}✓ 支持多种模型: Claude, GPT, Gemini, GLM 等${NC}"
    echo -e "${GREEN}✓ 部分模型免费使用${NC}"
    echo ""
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
    echo -e "${GRAY}获取 Key: https://opencode.ai/auth${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key)" "🔄"
    print_menu_item "2" "完整配置 (可修改 API Key)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择目录:${NC}"
    print_menu_item "1" "Zen 目录 (Claude/GPT/Gemini)" "🧘"
    print_menu_item "2" "Go 目录 (Kimi/GLM/MiniMax)" "🏃"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" catalog_choice < "$TTY_INPUT"
    catalog_choice=${catalog_choice:-1}

    local provider="opencode"
    if [ "$catalog_choice" = "2" ]; then
        provider="opencode-go"
    fi

    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    if [ "$provider" = "opencode-go" ]; then
        print_menu_item "1" "kimi-k2.5 (推荐, Go 默认)" "⭐"
        print_menu_item "2" "glm-5" "🇨🇳"
        print_menu_item "3" "minimax-m2.5" "🤖"
        print_menu_item "4" "自定义模型名称" "✏️"
        echo ""
        read -p "$(echo -e "${YELLOW}请选择 [1-4] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
        model_choice=${model_choice:-1}
        case $model_choice in
            1) model="kimi-k2.5" ;;
            2) model="glm-5" ;;
            3) model="minimax-m2.5" ;;
            4) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
            *) model="kimi-k2.5" ;;
        esac
    else
        print_menu_item "1" "claude-opus-4-6 (推荐, Zen 默认)" "⭐"
        print_menu_item "2" "gpt-5.1-codex" "💻"
        print_menu_item "3" "gpt-5.2" "🟢"
        print_menu_item "4" "gemini-3-pro (Gemini 3)" "🔴"
        print_menu_item "5" "glm-4.7 (免费)" "🆓"
        print_menu_item "6" "gpt-5.1-codex-mini" "⚡"
        print_menu_item "7" "自定义模型名称" "✏️"
        echo ""
        read -p "$(echo -e "${YELLOW}请选择 [1-7] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
        model_choice=${model_choice:-1}
        case $model_choice in
            1) model="claude-opus-4-6" ;;
            2) model="gpt-5.1-codex" ;;
            3) model="gpt-5.2" ;;
            4) model="gemini-3-pro" ;;
            5) model="glm-4.7" ;;
            6) model="gpt-5.1-codex-mini" ;;
            7) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
            *) model="claude-opus-4-6" ;;
        esac
    fi
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "$provider" "$api_key" "$model" ""
    
    echo ""
    log_info "OpenCode 配置完成！"
    log_info "目录: $provider"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "$provider" "$api_key" "$model" ""
    fi
    
    press_enter
}

config_novita() {
    clear_screen
    print_header

    echo -e "${WHITE}🚀 配置 Novita AI${NC}"
    print_divider
    echo ""

    # 获取当前配置
    local current_key=$(get_env_value "NOVITA_API_KEY")
    local official_url="https://api.novita.ai/openai"

    # 显示当前配置
    echo -e "${CYAN}Novita AI 是高性能 OpenAI 兼容推理平台，提供 Kimi、DeepSeek、GLM 等主流模型${NC}"
    echo ""
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    echo ""

    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
    echo -e "${GRAY}获取 Key: https://novita.ai/${NC}"
    echo ""
    print_divider
    echo ""

    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key)" "🔄"
    print_menu_item "2" "完整配置 (可修改 API Key)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}

    local api_key="$current_key"

    if [ "$config_mode" = "2" ]; then
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi

        read -p "$(echo -e "${YELLOW}输入 API Key (留空保持不变): ${NC}")" input_key < "$TTY_INPUT"

        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi

    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi

    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "moonshotai/kimi-k2.5 (推荐)" "⭐"
    print_menu_item "2" "deepseek/deepseek-v3.2" "🔵"
    print_menu_item "3" "zai-org/glm-5" "🇨🇳"
    print_menu_item "4" "自定义模型名称" "✏️"
    echo ""

    read -p "$(echo -e "${YELLOW}请选择 [1-4] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}

    case $model_choice in
        1) model="moonshotai/kimi-k2.5" ;;
        2) model="deepseek/deepseek-v3.2" ;;
        3) model="zai-org/glm-5" ;;
        4) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="moonshotai/kimi-k2.5" ;;
    esac

    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "novita" "$api_key" "$model" ""

    echo ""
    log_info "Novita AI 配置完成！"
    log_info "模型: $model"

    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "novita" "$api_key" "$model" ""
    fi

    press_enter
}

config_google_gemini_cli() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🧪 配置 Google Gemini CLI${NC}"
    print_divider
    echo ""
    
    # 获取当前配置
    local current_key=$(get_env_value "GOOGLE_API_KEY")
    local official_url="https://generativelanguage.googleapis.com"
    
    echo -e "${YELLOW}⚠️ 实验性功能${NC}"
    echo ""
    echo -e "${CYAN}Google Gemini CLI 提供最新的 Gemini 模型预览版${NC}"
    echo ""
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
    echo -e "${GRAY}获取 Key: https://aistudio.google.com/apikey${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key)" "🔄"
    print_menu_item "2" "完整配置 (可修改 API Key)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "gemini-3.1-pro-preview (推荐)" "⭐"
    print_menu_item "2" "gemini-3-flash-preview (快速)" "⚡"
    print_menu_item "3" "gemini-3.1-flash-lite-preview (轻量)" "🚀"
    print_menu_item "4" "gemini-2.5-pro (稳定)" "📦"
    print_menu_item "5" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="gemini-3.1-pro-preview" ;;
        2) model="gemini-3-flash-preview" ;;
        3) model="gemini-3.1-flash-lite-preview" ;;
        4) model="gemini-2.5-pro" ;;
        5) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="gemini-3.1-pro-preview" ;;
    esac
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "google-gemini-cli" "$api_key" "$model" ""
    
    echo ""
    log_info "Google Gemini CLI 配置完成！"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "google-gemini-cli" "$api_key" "$model" ""
    fi
    
    press_enter
}

config_google_antigravity() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🚀 配置 Google Antigravity${NC}"
    print_divider
    echo ""
    
    # 获取当前配置
    local current_key=$(get_env_value "GOOGLE_API_KEY")
    
    echo -e "${YELLOW}⚠️ 实验性功能${NC}"
    echo ""
    echo -e "${CYAN}Google Antigravity 是 Google 的实验性 AI 服务${NC}"
    echo -e "${CYAN}提供多种顶级模型的访问${NC}"
    echo ""
    echo -e "${CYAN}当前配置:${NC}"
    if [ -n "$current_key" ]; then
        local masked_key="${current_key:0:8}...${current_key: -4}"
        echo -e "  API Key: ${WHITE}$masked_key${NC}"
    else
        echo -e "  API Key: ${GRAY}(未配置)${NC}"
    fi
    echo ""
    
    echo -e "${GRAY}获取 API Key: 请联系 Google Cloud 获取访问权限${NC}"
    echo ""
    print_divider
    echo ""
    
    # 询问配置模式
    echo -e "${YELLOW}选择配置模式:${NC}"
    print_menu_item "1" "仅更改模型 (保留当前 API Key)" "🔄"
    print_menu_item "2" "完整配置 (可修改 API Key)" "⚙️"
    echo ""
    read -p "$(echo -e "${YELLOW}请选择 [1-2] (默认: 1): ${NC}")" config_mode < "$TTY_INPUT"
    config_mode=${config_mode:-1}
    
    local api_key="$current_key"
    
    if [ "$config_mode" = "2" ]; then
        echo ""
        if [ -n "$current_key" ]; then
            local masked_key="${current_key:0:8}...${current_key: -4}"
            echo -e "当前 API Key: ${GRAY}$masked_key${NC}"
        fi
        
        read_secret_input "${YELLOW}输入 API Key (留空保持不变): ${NC}" input_key
        
        if [ -n "$input_key" ]; then
            api_key="$input_key"
        fi
    fi
    
    # 验证 API Key
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空，请先配置 API Key"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${CYAN}选择模型:${NC}"
    echo ""
    print_menu_item "1" "gemini-3-pro-high (推荐)" "⭐"
    print_menu_item "2" "gemini-3-pro-low (快速)" "⚡"
    print_menu_item "3" "gemini-3-flash (闪电)" "🔥"
    print_menu_item "4" "claude-opus-4-6-thinking (Claude)" "🟣"
    print_menu_item "5" "claude-sonnet-4-6-thinking (思考)" "🧠"
    print_menu_item "6" "gpt-oss-120b-medium (GPT)" "🟢"
    print_menu_item "7" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-7] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="gemini-3-pro-high" ;;
        2) model="gemini-3-pro-low" ;;
        3) model="gemini-3-flash" ;;
        4) model="claude-opus-4-6-thinking" ;;
        5) model="claude-sonnet-4-6-thinking" ;;
        6) model="gpt-oss-120b-medium" ;;
        7) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="gemini-3-pro-high" ;;
    esac
    
    # 保存到 OpenClaw 环境变量配置
    save_openclaw_ai_config "google-antigravity" "$api_key" "$model" ""
    
    echo ""
    log_info "Google Antigravity 配置完成！"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "google-antigravity" "$api_key" "$model" ""
    fi
    
    press_enter
}

# ================================ 渠道配置 ================================

config_channels() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📱 消息渠道配置${NC}"
    print_divider
    echo ""
    echo -e "${GRAY}详细文档: ~/.openclaw/docs/channels-configuration-guide.md${NC}"
    echo ""
    
    print_menu_item "1" "Telegram 机器人" "📨"
    print_menu_item "2" "Discord 机器人" "🎮"
    print_menu_item "3" "WhatsApp" "💬"
    print_menu_item "4" "Slack" "💼"
    print_menu_item "5" "飞书 (Feishu)" "🔷"
    print_menu_item "6" "Signal（官方）" "🔐"
    print_menu_item "7" "Microsoft Teams（官方插件）" "🏢"
    print_menu_item "8" "Mattermost（官方插件）" "🧩"
    print_menu_item "9" "Google Chat（官方插件）" "🟨"
    print_menu_item "10" "Matrix（官方插件）" "🔷"
    print_menu_item "11" "LINE（官方插件）" "🟩"
    print_menu_item "12" "Nextcloud Talk（官方插件）" "☁️"
    print_menu_item "13" "更多官方渠道" "🧭"
    print_menu_item "14" "钉钉/QQ/企业微信 官方状态检查" "🧾"
    print_menu_item "15" "微信（LangBot WeChatPad，社区）" "🟢"
    print_menu_item "16" "iMessage（旧版）" "🍎"
    print_menu_item "17" "QQ（社区插件，可选）" "🐧"
    print_menu_item "18" "企业微信（WeCom，社区插件）" "🏬"
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    echo -en "${YELLOW}请选择 [0-18]: ${NC}"
    read choice < "$TTY_INPUT"
    
    case $choice in
        1) config_telegram ;;
        2) config_discord ;;
        3) config_whatsapp ;;
        4) config_slack ;;
        5) config_feishu ;;
        6) config_signal ;;
        7) config_msteams ;;
        8) config_mattermost ;;
        9) config_googlechat ;;
        10) config_matrix ;;
        11) config_line ;;
        12) config_nextcloud_talk ;;
        13) config_more_official_channels ;;
        14) check_cn_enterprise_channel_official_status ;;
        15) config_wechat ;;
        16) config_imessage ;;
        17) config_qq_community ;;
        18) config_wecom_community ;;
        0) return ;;
        *) log_error "无效选择"; press_enter; config_channels ;;
    esac
}

config_telegram() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📨 配置 Telegram 机器人${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}配置步骤:${NC}"
    echo "  1. 在 Telegram 中搜索 @BotFather"
    echo "  2. 发送 /newbot 创建新机器人"
    echo "  3. 按提示设置名称，获取 Bot Token"
    echo "  4. 搜索 @userinfobot 获取你的 User ID"
    echo ""
    print_divider
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入 Bot Token: ${NC}")" bot_token
    read -p "$(echo -e "${YELLOW}输入你的 User ID: ${NC}")" user_id
    
    if [ -n "$bot_token" ] && [ -n "$user_id" ]; then
        
        # 使用 openclaw 命令配置
        if check_openclaw_installed; then
            echo ""
            log_info "正在配置 OpenClaw Telegram 渠道..."
            
            # 启用 Telegram 插件
            echo -e "${YELLOW}启用 Telegram 插件...${NC}"
            openclaw plugins enable telegram 2>/dev/null || true
            ensure_plugin_in_allow "telegram"
            
            # 添加 Telegram channel
            echo -e "${YELLOW}添加 Telegram 账号...${NC}"
            if openclaw channels add --channel telegram --token "$bot_token" 2>/dev/null; then
                log_info "Telegram 渠道配置成功！"
            else
                log_warn "Telegram 渠道可能已存在或配置失败"
            fi
            
            echo ""
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${WHITE}Telegram 配置完成！${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo -e "Bot Token: ${WHITE}${bot_token:0:10}...${NC}"
            echo -e "User ID: ${WHITE}$user_id${NC}"
            echo ""
            echo -e "${YELLOW}⚠️  重要: 需要重启 Gateway 才能生效！${NC}"
            echo ""
            
            if confirm "是否现在重启 Gateway？" "y"; then
                restart_gateway_for_channel
            fi
        else
            log_error "OpenClaw 未安装，请先安装 OpenClaw"
        fi
        
        # 询问是否测试
        echo ""
        if confirm "是否发送测试消息验证配置？" "y"; then
            test_telegram_bot "$bot_token" "$user_id"
        fi
    else
        log_error "配置不完整，已取消"
    fi
    
    press_enter
}

config_discord() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🎮 配置 Discord 机器人${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}第一步: 创建 Discord 应用和机器人${NC}"
    echo ""
    echo "  1. 访问 ${WHITE}https://discord.com/developers/applications${NC}"
    echo "  2. 点击 ${WHITE}New Application${NC} 创建新应用"
    echo "  3. 进入应用后，点击左侧 ${WHITE}Bot${NC} 菜单"
    echo "  4. 点击 ${WHITE}Reset Token${NC} 生成并复制 Bot Token"
    echo "  5. 开启 ${WHITE}Message Content Intent${NC} (重要!)"
    echo ""
    echo -e "${CYAN}第二步: 邀请机器人到服务器${NC}"
    echo ""
    echo "  1. 点击左侧 ${WHITE}OAuth2 → URL Generator${NC}"
    echo "  2. Scopes 勾选: ${WHITE}bot${NC}"
    echo "  3. Bot Permissions 至少勾选:"
    echo "     • ${WHITE}View Channels${NC} (查看频道)"
    echo "     • ${WHITE}Send Messages${NC} (发送消息)"
    echo "     • ${WHITE}Read Message History${NC} (读取消息历史)"
    echo "  4. 复制生成的 URL，在浏览器打开并选择服务器"
    echo "  5. ${YELLOW}确保机器人在目标频道有权限！${NC}"
    echo ""
    echo -e "${CYAN}第三步: 获取频道 ID${NC}"
    echo ""
    echo "  1. 打开 Discord 客户端，进入 ${WHITE}用户设置 → 高级${NC}"
    echo "  2. 开启 ${WHITE}开发者模式${NC}"
    echo "  3. 右键点击你想让机器人响应的频道"
    echo "  4. 点击 ${WHITE}复制频道 ID${NC}"
    echo ""
    print_divider
    echo ""
    
    echo -en "${YELLOW}输入 Bot Token: ${NC}"
    read bot_token < "$TTY_INPUT"
    echo -en "${YELLOW}输入频道 ID (右键频道→复制ID): ${NC}"
    read channel_id < "$TTY_INPUT"
    
    if [ -n "$bot_token" ] && [ -n "$channel_id" ]; then
        
        # 使用 openclaw 命令配置
        if check_openclaw_installed; then
            echo ""
            log_info "正在配置 OpenClaw Discord 渠道..."
            
            # 启用 Discord 插件
            echo -e "${YELLOW}启用 Discord 插件...${NC}"
            openclaw plugins enable discord 2>/dev/null || true
            ensure_plugin_in_allow "discord"
            
            # 添加 Discord channel
            echo -e "${YELLOW}添加 Discord 账号...${NC}"
            if openclaw channels add --channel discord --token "$bot_token" 2>/dev/null; then
                log_info "Discord 渠道配置成功！"
            else
                log_warn "Discord 渠道可能已存在或配置失败"
            fi
            
            # 设置 groupPolicy 为 open（只响应 @ 机器人的消息）
            echo -e "${YELLOW}设置消息响应策略...${NC}"
            openclaw config set channels.discord.groupPolicy open 2>/dev/null || true
            log_info "已设置为: 响应 @机器人 的消息"
            
            echo ""
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${WHITE}Discord 配置完成！${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo -e "${CYAN}使用方式: 在频道中 @机器人 发送消息${NC}"
            echo ""
            echo -e "${YELLOW}⚠️  重要: 需要重启 Gateway 才能生效！${NC}"
            echo ""
            
            if confirm "是否现在重启 Gateway？" "y"; then
                restart_gateway_for_channel
            fi
        else
            log_error "OpenClaw 未安装，请先安装 OpenClaw"
        fi
        
        # 询问是否测试
        echo ""
        if confirm "是否发送测试消息验证配置？" "y"; then
            test_discord_bot "$bot_token" "$channel_id"
        fi
    else
        log_error "配置不完整，已取消"
    fi
    
    press_enter
}

config_whatsapp() {
    clear_screen
    print_header
    
    echo -e "${WHITE}💬 配置 WhatsApp${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}WhatsApp 配置需要扫描二维码登录${NC}"
    echo ""
    
    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装，请先运行安装脚本"
        press_enter
        return
    fi
    
    echo "配置步骤:"
    echo "  1. 启用 WhatsApp 插件"
    echo "  2. 扫描二维码登录"
    echo "  3. 重启 Gateway"
    echo ""
    
    if confirm "是否继续？"; then
        # 确保初始化
        ensure_openclaw_init
        
        # 启用 WhatsApp 插件
        echo ""
        log_info "启用 WhatsApp 插件..."
        openclaw plugins enable whatsapp 2>/dev/null || true
        ensure_plugin_in_allow "whatsapp"
        
        echo ""
        log_info "正在启动 WhatsApp 登录向导..."
        echo -e "${YELLOW}请扫描显示的二维码完成登录${NC}"
        echo ""
        
        # 使用 channels login 命令
        openclaw channels login --channel whatsapp --verbose
        
        echo ""
        if confirm "是否重启 Gateway 使配置生效？" "y"; then
            restart_gateway_for_channel
        fi
    fi
    
    press_enter
}

config_slack() {
    clear_screen
    print_header
    
    echo -e "${WHITE}💼 配置 Slack${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}配置步骤:${NC}"
    echo "  1. 访问 https://api.slack.com/apps"
    echo "  2. 创建新应用，选择 'From scratch'"
    echo "  3. 在 OAuth & Permissions 中添加所需权限"
    echo "  4. 安装应用到工作区并获取 Bot Token"
    echo ""
    print_divider
    echo ""
    
    read_secret_input "${YELLOW}输入 Bot Token (xoxb-...): ${NC}" bot_token
    read -p "$(echo -e "${YELLOW}输入 App Token (xapp-...): ${NC}")" app_token
    
    if [ -n "$bot_token" ] && [ -n "$app_token" ]; then
        
        # 使用 openclaw 命令配置
        if check_openclaw_installed; then
            echo ""
            log_info "正在配置 OpenClaw Slack 渠道..."
            
            # 启用 Slack 插件
            echo -e "${YELLOW}启用 Slack 插件...${NC}"
            openclaw plugins enable slack 2>/dev/null || true
            ensure_plugin_in_allow "slack"
            
            # 添加 Slack channel
            echo -e "${YELLOW}添加 Slack 账号...${NC}"
            if openclaw channels add --channel slack --bot-token "$bot_token" --app-token "$app_token" 2>/dev/null; then
                log_info "Slack 渠道配置成功！"
            else
                log_warn "Slack 渠道可能已存在或配置失败"
            fi
            
            echo ""
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${WHITE}Slack 配置完成！${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo -e "${YELLOW}⚠️  重要: 需要重启 Gateway 才能生效！${NC}"
            echo ""
            
            if confirm "是否现在重启 Gateway？" "y"; then
                restart_gateway_for_channel
            fi
        else
            log_info "Slack 配置完成！"
        fi
        
        # 询问是否测试
        echo ""
        if confirm "是否验证 Slack 连接？" "y"; then
            test_slack_bot "$bot_token"
        fi
    else
        log_error "配置不完整，已取消"
    fi
    
    press_enter
}

get_official_channel_package() {
    local channel="$1"
    case "$channel" in
        signal) echo "@openclaw/signal" ;;
        msteams) echo "@openclaw/msteams" ;;
        mattermost) echo "@openclaw/mattermost" ;;
        googlechat) echo "@openclaw/googlechat" ;;
        matrix) echo "@openclaw/matrix" ;;
        line) echo "@openclaw/line" ;;
        nextcloud-talk) echo "@openclaw/nextcloud-talk" ;;
        irc) echo "@openclaw/irc" ;;
        twitch) echo "@openclaw/twitch" ;;
        zalo) echo "@openclaw/zalo" ;;
        zalouser) echo "@openclaw/zalouser" ;;
        nostr) echo "@openclaw/nostr" ;;
        tlon) echo "@openclaw/tlon" ;;
        synology-chat) echo "@openclaw/synology-chat" ;;
        bluebubbles) echo "@openclaw/bluebubbles" ;;
        *) echo "" ;;
    esac
}

config_official_plugin_channel() {
    local channel="$1"
    local display_name="$2"

    clear_screen
    print_header
    echo -e "${WHITE}🔌 配置 ${display_name}${NC}"
    print_divider
    echo ""

    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装"
        press_enter
        return
    fi

    ensure_openclaw_init

    local pkg
    pkg="$(get_official_channel_package "$channel")"
    if [ -z "$pkg" ]; then
        log_error "未找到 ${display_name} 对应的官方插件包映射"
        press_enter
        return
    fi

    echo -e "${CYAN}该渠道使用官方插件: ${WHITE}${pkg}${NC}"
    echo -e "${CYAN}将执行: 安装插件 -> 启用插件 -> 渠道配置向导${NC}"
    echo ""

    if confirm "是否安装/更新官方插件 ${pkg}？" "y"; then
        if openclaw plugins install "$pkg" --pin; then
            log_info "官方插件安装成功: $pkg"
        else
            log_warn "插件安装失败，继续尝试使用已安装版本配置渠道"
        fi
    fi

    openclaw plugins enable "$channel" 2>/dev/null || true
    ensure_plugin_in_allow "$channel"

    echo ""
    log_info "启动渠道配置向导..."
    if openclaw channels add --channel "$channel"; then
        log_info "${display_name} 渠道配置成功！"
    else
        log_warn "${display_name} 渠道向导未成功完成，可稍后重试。"
        echo -e "${CYAN}手动命令:${NC} ${WHITE}openclaw channels add --channel ${channel}${NC}"
    fi

    echo ""
    if confirm "是否重启 Gateway 使配置生效？" "y"; then
        restart_gateway_for_channel
    fi

    press_enter
}

config_signal() { config_official_plugin_channel "signal" "Signal（官方）"; }
config_msteams() { config_official_plugin_channel "msteams" "Microsoft Teams（官方插件）"; }
config_mattermost() { config_official_plugin_channel "mattermost" "Mattermost（官方插件）"; }
config_googlechat() { config_official_plugin_channel "googlechat" "Google Chat（官方插件）"; }
config_matrix() { config_official_plugin_channel "matrix" "Matrix（官方插件）"; }
config_line() { config_official_plugin_channel "line" "LINE（官方插件）"; }
config_nextcloud_talk() { config_official_plugin_channel "nextcloud-talk" "Nextcloud Talk（官方插件）"; }

config_more_official_channels() {
    clear_screen
    print_header
    echo -e "${WHITE}🧭 更多官方渠道${NC}"
    print_divider
    echo ""
    print_menu_item "1" "IRC（官方插件）" "💻"
    print_menu_item "2" "Twitch（官方插件）" "🟣"
    print_menu_item "3" "Zalo（官方插件）" "🇻🇳"
    print_menu_item "4" "Zalo Personal（官方插件）" "📱"
    print_menu_item "5" "Nostr（官方插件）" "🌐"
    print_menu_item "6" "Tlon（官方插件）" "🪐"
    print_menu_item "7" "Synology Chat（官方插件）" "🗄️"
    print_menu_item "8" "BlueBubbles（官方）" "🔵"
    print_menu_item "0" "返回" "↩️"
    echo ""
    echo -en "${YELLOW}请选择 [0-8]: ${NC}"
    read choice < "$TTY_INPUT"
    case $choice in
        1) config_official_plugin_channel "irc" "IRC（官方插件）" ;;
        2) config_official_plugin_channel "twitch" "Twitch（官方插件）" ;;
        3) config_official_plugin_channel "zalo" "Zalo（官方插件）" ;;
        4) config_official_plugin_channel "zalouser" "Zalo Personal（官方插件）" ;;
        5) config_official_plugin_channel "nostr" "Nostr（官方插件）" ;;
        6) config_official_plugin_channel "tlon" "Tlon（官方插件）" ;;
        7) config_official_plugin_channel "synology-chat" "Synology Chat（官方插件）" ;;
        8) config_official_plugin_channel "bluebubbles" "BlueBubbles（官方）" ;;
        0) return ;;
        *) log_error "无效选择"; press_enter; config_more_official_channels ;;
    esac
}

check_cn_enterprise_channel_official_status() {
    clear_screen
    print_header
    echo -e "${WHITE}🧾 国内企业渠道官方适配检查${NC}"
    print_divider
    echo ""
    echo -e "${CYAN}对照基线: 官方扩展目录 + 官方 channels 文档（最新版）${NC}"
    echo ""
    echo -e "  • 钉钉（DingTalk）: ${YELLOW}当前未发现官方插件${NC}"
    echo -e "  • QQ: ${YELLOW}当前未发现官方插件${NC}"
    echo -e "  • 企业微信（WeCom）: ${YELLOW}当前未发现官方插件${NC}"
    echo ""
    echo -e "${CYAN}可选社区方案（非官方，需自行评估风险）:${NC}"
    echo "  • QQ: @sliverp/qqbot（本菜单提供安装/探针/回滚）"
    echo "  • 微信: openclaw-wechat-channel（按 LangBot WeChatPad 适配流程）"
    echo "  • 企业微信: @marshulll/openclaw-wecom（本菜单提供安装/探针/回滚）"
    echo ""
    echo -e "${CYAN}已纳入的官方企业渠道替代项:${NC}"
    echo "  • 飞书（Feishu）"
    echo "  • Microsoft Teams（插件）"
    echo "  • Slack"
    echo "  • Google Chat（插件）"
    echo "  • Mattermost（插件）"
    echo ""
    echo -e "${YELLOW}说明:${NC} 为避免与官方能力漂移，本安装器仅默认纳入已发布的官方渠道插件。"
    echo -e "${YELLOW}补充:${NC} 企业微信/QQ/微信目前按社区插件方案接入。"
    echo ""
    press_enter
}

probe_wecom_community_config() {
    echo ""
    echo -e "${CYAN}━━━ WeCom 社区插件探针 ━━━${NC}"
    echo ""

    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装，无法探针"
        return 1
    fi

    local plugin_ok=false
    local channel_ok=false
    local mode=""
    local bot_token=""
    local app_corp=""

    if openclaw plugins list 2>/dev/null | grep -Eqi "openclaw-wecom|wecom"; then
        plugin_ok=true
        log_info "WeCom 插件已安装"
    else
        log_warn "未检测到 WeCom 插件"
    fi

    if openclaw channels list 2>/dev/null | grep -qi "wecom"; then
        channel_ok=true
        log_info "WeCom 渠道已注册"
    else
        log_warn "WeCom 渠道未在 channels list 中出现"
    fi

    mode="$(openclaw config get channels.wecom.mode 2>/dev/null || true)"
    [ -z "$mode" ] || [ "$mode" = "undefined" ] && mode="both"
    echo -e "${CYAN}当前模式:${NC} ${WHITE}${mode}${NC}"

    bot_token="$(openclaw config get channels.wecom.accounts.bot.token 2>/dev/null || true)"
    app_corp="$(openclaw config get channels.wecom.accounts.app.corpId 2>/dev/null || true)"
    if [ "$mode" = "bot" ] || [ "$mode" = "both" ]; then
        if [ -n "$bot_token" ] && [ "$bot_token" != "undefined" ]; then
            log_info "Bot 模式关键字段已配置"
        else
            log_warn "Bot 模式 token 未配置"
        fi
    fi
    if [ "$mode" = "app" ] || [ "$mode" = "both" ]; then
        if [ -n "$app_corp" ] && [ "$app_corp" != "undefined" ]; then
            log_info "App 模式关键字段已配置"
        else
            log_warn "App 模式 corpId 未配置"
        fi
    fi

    echo ""
    echo -e "${CYAN}诊断输出:${NC}"
    openclaw doctor 2>&1 | head -10 | sed 's/^/  /'

    if [ "$plugin_ok" = true ] && [ "$channel_ok" = true ]; then
        log_info "WeCom 配置探针通过"
        return 0
    fi

    echo ""
    echo -e "${YELLOW}排障建议:${NC}"
    echo "  1) openclaw doctor --fix"
    echo "  2) openclaw plugins update --all"
    echo "  3) 重新执行企业微信配置向导"
    return 1
}

rollback_wecom_community_config() {
    echo ""
    echo -e "${WHITE}♻️ 回滚企业微信（WeCom）社区配置${NC}"
    print_divider
    echo ""
    echo -e "${YELLOW}将执行:${NC}"
    echo "  • 禁用并卸载 WeCom 社区插件"
    echo "  • 清理 channels.wecom 与 plugins.allow 残留"
    echo ""

    if ! confirm "确认执行回滚？" "n"; then
        log_info "已取消回滚"
        return 0
    fi

    openclaw plugins disable wecom > /dev/null 2>&1 || true
    openclaw plugins disable openclaw-wecom > /dev/null 2>&1 || true
    openclaw plugins uninstall wecom --keep-files > /dev/null 2>&1 || true
    openclaw plugins uninstall openclaw-wecom --keep-files > /dev/null 2>&1 || true
    openclaw plugins uninstall "$WECOM_PLUGIN_COMMUNITY" --keep-files > /dev/null 2>&1 || true

    if openclaw config --help 2>/dev/null | grep -q "unset"; then
        openclaw config unset channels.wecom > /dev/null 2>&1 || true
        openclaw config unset plugins.entries.wecom > /dev/null 2>&1 || true
        openclaw config unset plugins.entries.openclaw-wecom > /dev/null 2>&1 || true
    else
        openclaw config set channels.wecom.enabled false > /dev/null 2>&1 || true
    fi

    remove_plugin_from_allow "wecom" || true
    remove_plugin_from_allow "openclaw-wecom" || true

    log_info "企业微信配置回滚完成"
    if confirm "是否重启 Gateway 使回滚生效？" "y"; then
        restart_gateway_for_channel
    fi
    return 0
}

config_wecom_community_setup() {
    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装"
        return 1
    fi

    ensure_openclaw_init

    local plugin_version="${OPENCLAW_WECOM_PLUGIN_VERSION:-$WECOM_PLUGIN_VERSION_DEFAULT}"
    local plugin_spec="${WECOM_PLUGIN_COMMUNITY}@${plugin_version}"
    local mode_choice mode
    local default_account

    local bot_webhook="$WECOM_WEBHOOK_BOT_DEFAULT"
    local bot_token=""
    local bot_aes=""
    local bot_receive_id=""

    local app_webhook="$WECOM_WEBHOOK_APP_DEFAULT"
    local corp_id=""
    local corp_secret=""
    local agent_id=""
    local callback_token=""
    local callback_aes=""

    echo -e "${YELLOW}⚠️ 风险提示:${NC}"
    echo "  • 企业微信当前不是 OpenClaw 官方渠道，依赖社区插件"
    echo "  • 插件固定版本安装，降低升级漂移风险"
    echo ""
    echo -e "${CYAN}将安装:${NC} ${WHITE}${plugin_spec}${NC}"
    if ! confirm "继续安装并配置企业微信插件？" "n"; then
        log_info "已取消企业微信配置"
        return 0
    fi

    if openclaw plugins install "$plugin_spec" --pin; then
        log_info "企业微信插件安装成功"
    else
        log_warn "插件安装失败，尝试继续使用已安装版本"
        if ! openclaw plugins list 2>/dev/null | grep -Eqi "openclaw-wecom|wecom"; then
            log_error "未检测到企业微信插件，无法继续"
            return 1
        fi
    fi

    openclaw plugins enable wecom > /dev/null 2>&1 || openclaw plugins enable openclaw-wecom > /dev/null 2>&1 || true
    ensure_plugin_in_allow "wecom"
    ensure_plugin_in_allow "openclaw-wecom"
    openclaw channels add --channel wecom > /dev/null 2>&1 || true

    echo ""
    echo -e "${CYAN}选择企业微信接入模式:${NC}"
    print_menu_item "1" "Bot 模式（回调 JSON）" "🤖"
    print_menu_item "2" "App 模式（内部应用 XML 回调）" "🏢"
    print_menu_item "3" "双模式（推荐）" "🔀"
    echo ""
    read_input "${YELLOW}请选择 [1-3] (默认: 3): ${NC}" mode_choice
    mode_choice="${mode_choice:-3}"
    case "$mode_choice" in
        1) mode="bot"; default_account="bot" ;;
        2) mode="app"; default_account="app" ;;
        *) mode="both"; default_account="bot" ;;
    esac

    if [ "$mode" = "bot" ] || [ "$mode" = "both" ]; then
        echo ""
        echo -e "${CYAN}Bot 模式参数:${NC}"
        read_input "${YELLOW}Bot webhookPath（默认 ${bot_webhook}）: ${NC}" bot_webhook
        bot_webhook="${bot_webhook:-$WECOM_WEBHOOK_BOT_DEFAULT}"
        read_secret_input "${YELLOW}Bot Token: ${NC}" bot_token
        read_secret_input "${YELLOW}Bot EncodingAESKey: ${NC}" bot_aes
        read_input "${YELLOW}Bot ReceiveId（aibotid）: ${NC}" bot_receive_id
        if [ -z "$bot_token" ] || [ -z "$bot_aes" ] || [ -z "$bot_receive_id" ]; then
            log_error "Bot 模式参数不完整"
            return 1
        fi
    fi

    if [ "$mode" = "app" ] || [ "$mode" = "both" ]; then
        echo ""
        echo -e "${CYAN}App 模式参数:${NC}"
        read_input "${YELLOW}App webhookPath（默认 ${app_webhook}）: ${NC}" app_webhook
        app_webhook="${app_webhook:-$WECOM_WEBHOOK_APP_DEFAULT}"
        read_input "${YELLOW}CorpID: ${NC}" corp_id
        read_secret_input "${YELLOW}CorpSecret: ${NC}" corp_secret
        read_input "${YELLOW}AgentID（数字）: ${NC}" agent_id
        read_secret_input "${YELLOW}Callback Token: ${NC}" callback_token
        read_secret_input "${YELLOW}Callback AES Key: ${NC}" callback_aes
        if [ -z "$corp_id" ] || [ -z "$corp_secret" ] || [ -z "$agent_id" ] || [ -z "$callback_token" ] || [ -z "$callback_aes" ]; then
            log_error "App 模式参数不完整"
            return 1
        fi
        if ! [[ "$agent_id" =~ ^[0-9]+$ ]]; then
            log_error "AgentID 必须是数字"
            return 1
        fi
    fi

    openclaw config set channels.wecom.enabled true > /dev/null 2>&1 || true
    openclaw config set channels.wecom.mode "$mode" > /dev/null 2>&1 || true
    openclaw config set channels.wecom.defaultAccount "$default_account" > /dev/null 2>&1 || true

    if [ "$mode" = "bot" ] || [ "$mode" = "both" ]; then
        openclaw config set channels.wecom.accounts.bot.mode bot > /dev/null 2>&1 || true
        openclaw config set channels.wecom.accounts.bot.webhookPath "$bot_webhook" > /dev/null 2>&1 || true
        openclaw config set channels.wecom.accounts.bot.token "$bot_token" > /dev/null 2>&1 || true
        openclaw config set channels.wecom.accounts.bot.encodingAESKey "$bot_aes" > /dev/null 2>&1 || true
        openclaw config set channels.wecom.accounts.bot.receiveId "$bot_receive_id" > /dev/null 2>&1 || true
    fi

    if [ "$mode" = "app" ] || [ "$mode" = "both" ]; then
        openclaw config set channels.wecom.accounts.app.mode app > /dev/null 2>&1 || true
        openclaw config set channels.wecom.accounts.app.webhookPath "$app_webhook" > /dev/null 2>&1 || true
        openclaw config set channels.wecom.accounts.app.corpId "$corp_id" > /dev/null 2>&1 || true
        openclaw config set channels.wecom.accounts.app.corpSecret "$corp_secret" > /dev/null 2>&1 || true
        openclaw config set channels.wecom.accounts.app.agentId "$agent_id" > /dev/null 2>&1 || true
        openclaw config set channels.wecom.accounts.app.callbackToken "$callback_token" > /dev/null 2>&1 || true
        openclaw config set channels.wecom.accounts.app.callbackAesKey "$callback_aes" > /dev/null 2>&1 || true
    fi

    log_info "企业微信 WeCom 配置完成"
    if confirm "是否立即执行 WeCom 配置探针？" "y"; then
        probe_wecom_community_config || true
    fi
    if confirm "是否重启 Gateway 使配置生效？" "y"; then
        restart_gateway_for_channel
    fi
    return 0
}

config_wecom_community() {
    clear_screen
    print_header
    echo -e "${WHITE}🏬 企业微信（WeCom，社区插件）${NC}"
    print_divider
    echo ""
    echo "  1) 安装并配置企业微信插件"
    echo "  2) 企业微信配置探针"
    echo "  3) 回滚企业微信配置"
    echo "  0) 返回"
    echo ""
    read_input "${YELLOW}请选择 [0-3]: ${NC}" wecom_choice

    case "$wecom_choice" in
        1) config_wecom_community_setup ;;
        2) probe_wecom_community_config ;;
        3) rollback_wecom_community_config ;;
        0) return ;;
        *) log_error "无效选择" ;;
    esac
    press_enter
}

probe_qq_community_config() {
    echo ""
    echo -e "${CYAN}━━━ QQ 社区插件探针 ━━━${NC}"

    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装，无法探针"
        return 1
    fi

    local plugin_ok=false
    local channel_ok=false
    local allow_value=""

    if openclaw plugins list 2>/dev/null | grep -qi "qqbot"; then
        plugin_ok=true
        log_info "qqbot 插件已安装"
    else
        log_warn "qqbot 插件未在 plugins list 中出现"
    fi

    if openclaw channels list 2>/dev/null | grep -qi "qqbot"; then
        channel_ok=true
        log_info "qqbot 渠道已注册"
    else
        log_warn "qqbot 渠道未在 channels list 中出现"
    fi

    allow_value="$(openclaw config get channels.qqbot.allowFrom 2>/dev/null || true)"
    if [ -n "$allow_value" ] && [ "$allow_value" != "undefined" ]; then
        echo -e "${CYAN}allowFrom:${NC} ${WHITE}$allow_value${NC}"
        if echo "$allow_value" | grep -q '\*'; then
            log_warn "当前 allowFrom 包含 *，表示允许所有来源"
        fi
    else
        log_warn "未检测到 channels.qqbot.allowFrom（插件默认可能为允许全部）"
    fi

    echo ""
    echo -e "${CYAN}诊断输出:${NC}"
    if openclaw plugins --help 2>/dev/null | grep -q "doctor"; then
        openclaw plugins doctor 2>&1 | head -10 | sed 's/^/  /'
    else
        openclaw doctor 2>&1 | head -10 | sed 's/^/  /'
    fi

    if [ "$plugin_ok" = true ] && [ "$channel_ok" = true ]; then
        log_info "QQ 社区配置探针通过"
        return 0
    fi

    echo ""
    echo -e "${YELLOW}排障建议:${NC}"
    echo "  1) openclaw doctor --fix"
    echo "  2) openclaw plugins update --all"
    echo "  3) 重新执行 QQ 社区配置向导"
    return 1
}

rollback_qq_community_config() {
    echo ""
    echo -e "${WHITE}♻️ 回滚 QQ 社区配置${NC}"
    print_divider
    echo ""
    echo -e "${YELLOW}将执行:${NC}"
    echo "  • 禁用 qqbot 插件"
    echo "  • 卸载 qqbot 插件（保留插件文件）"
    echo "  • 清理 channels.qqbot 与 plugins.allow 中的 qqbot"
    echo ""

    if ! confirm "确认执行回滚？" "n"; then
        log_info "已取消回滚"
        return 0
    fi

    openclaw plugins disable qqbot > /dev/null 2>&1 || true
    openclaw plugins uninstall qqbot --keep-files > /dev/null 2>&1 || true

    if openclaw config --help 2>/dev/null | grep -q "unset"; then
        openclaw config unset channels.qqbot > /dev/null 2>&1 || true
        openclaw config unset plugins.entries.qqbot > /dev/null 2>&1 || true
    else
        openclaw config set channels.qqbot.enabled false > /dev/null 2>&1 || true
        openclaw config set channels.qqbot.allowFrom "[]" > /dev/null 2>&1 || true
    fi

    remove_plugin_from_allow "qqbot" || true
    log_info "QQ 社区配置回滚完成"

    if confirm "是否重启 Gateway 使回滚生效？" "y"; then
        restart_gateway_for_channel
    fi
    return 0
}

config_qq_community_setup() {
    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装"
        return 1
    fi

    ensure_openclaw_init

    local plugin_version="${OPENCLAW_QQ_PLUGIN_VERSION:-$QQ_PLUGIN_VERSION_DEFAULT}"
    local plugin_spec="${QQ_PLUGIN_COMMUNITY}@${plugin_version}"
    local app_id=""
    local app_secret=""
    local allow_input=""
    local allow_json=""

    echo -e "${YELLOW}⚠️ 风险提示:${NC}"
    echo "  • QQ 当前不是官方渠道，依赖社区插件"
    echo "  • 仅建议用于测试或内部环境，生产环境请评估安全风险"
    echo "  • 本安装器会固定版本安装，避免 latest 漂移"
    echo ""

    if ! confirm "继续安装并配置 QQ 社区插件？" "n"; then
        log_info "已取消 QQ 配置"
        return 0
    fi

    echo ""
    echo -e "${CYAN}安装插件: ${WHITE}${plugin_spec}${NC}"
    if openclaw plugins install "$plugin_spec" --pin; then
        log_info "QQ 社区插件安装成功"
    else
        log_warn "插件安装失败，尝试继续使用已安装版本"
        if ! openclaw plugins list 2>/dev/null | grep -qi "qqbot"; then
            log_error "未检测到 qqbot 已安装，无法继续"
            return 1
        fi
    fi

    openclaw plugins enable qqbot > /dev/null 2>&1 || true
    ensure_plugin_in_allow "qqbot"

    echo ""
    echo -e "${CYAN}请输入 QQ 机器人凭据（官方 Bot 平台）${NC}"
    read_input "${YELLOW}AppID: ${NC}" app_id
    read_secret_input "${YELLOW}AppSecret: ${NC}" app_secret
    if [ -z "$app_id" ] || [ -z "$app_secret" ]; then
        log_error "AppID / AppSecret 不能为空"
        return 1
    fi

    echo ""
    echo -e "${YELLOW}注册 QQ 渠道...${NC}"
    local add_output=""
    add_output="$(openclaw channels add --channel qqbot --token "${app_id}:${app_secret}" 2>&1)"
    local add_exit=$?
    echo "$add_output" | grep -v "^🦞" | grep -v "^$" | head -5
    if [ $add_exit -ne 0 ]; then
        log_warn "QQ 渠道可能已存在或注册失败，继续写入 allowFrom"
    fi

    echo ""
    echo -e "${CYAN}来源白名单（allowFrom）配置:${NC}"
    echo "  • 输入格式: 12345,67890"
    echo "  • 留空表示允许所有来源（高风险）"
    read_input "${YELLOW}请输入允许来源（可留空）: ${NC}" allow_input

    if [ -n "$allow_input" ]; then
        allow_json="$(build_json_array_from_csv "$allow_input")"
        if [ "$allow_json" = "[]" ]; then
            log_error "allowFrom 解析后为空，请重新输入"
            return 1
        fi
        if set_channel_allow_from_json "qqbot" "$allow_json"; then
            log_info "已设置 allowFrom: $allow_json"
        else
            log_error "写入 allowFrom 失败"
            return 1
        fi
    else
        if confirm "未设置白名单将允许所有来源（[\"*\"]），确认继续？" "n"; then
            if set_channel_allow_from_json "qqbot" "[\"*\"]"; then
                log_warn "已设置 allowFrom 为 [\"*\"]（允许全部来源）"
            else
                log_error "写入 allowFrom 失败"
                return 1
            fi
        else
            log_info "已取消保存 QQ 配置"
            return 1
        fi
    fi

    openclaw config set channels.qqbot.enabled true > /dev/null 2>&1 || true
    log_info "QQ 社区渠道配置完成"

    if confirm "是否立即执行 QQ 配置探针？" "y"; then
        probe_qq_community_config || true
    fi

    if confirm "是否重启 Gateway 使配置生效？" "y"; then
        restart_gateway_for_channel
    fi

    return 0
}

config_qq_community() {
    clear_screen
    print_header
    echo -e "${WHITE}🐧 QQ（社区插件，可选）${NC}"
    print_divider
    echo ""
    echo "  1) 安装并配置 QQ 社区插件"
    echo "  2) QQ 配置探针检查"
    echo "  3) 回滚 QQ 社区配置"
    echo "  0) 返回"
    echo ""
    read_input "${YELLOW}请选择 [0-3]: ${NC}" qq_choice

    case "$qq_choice" in
        1) config_qq_community_setup ;;
        2) probe_qq_community_config ;;
        3) rollback_qq_community_config ;;
        0) return ;;
        *) log_error "无效选择" ;;
    esac
    press_enter
}

probe_wechat_langbot_config() {
    echo ""
    echo -e "${CYAN}━━━ 微信 LangBot/WeChatPad 探针 ━━━${NC}"
    echo ""

    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装，无法探针"
        return 1
    fi

    local plugin_ok=false
    local channel_ok=false
    local proxy_url=""

    if openclaw plugins list 2>/dev/null | grep -Eqi "openclaw-wechat-channel|wechat"; then
        plugin_ok=true
        log_info "微信社区插件已安装"
    else
        log_warn "未检测到微信社区插件"
    fi

    if openclaw channels list 2>/dev/null | grep -qi "wechat"; then
        channel_ok=true
        log_info "微信渠道已注册"
    else
        log_warn "微信渠道未在 channels list 中出现"
    fi

    proxy_url="$(openclaw config get channels.wechat.accounts.main.proxyUrl 2>/dev/null || true)"
    if [ -z "$proxy_url" ] || [ "$proxy_url" = "undefined" ]; then
        proxy_url="$(openclaw config get channels.wechat.proxyUrl 2>/dev/null || true)"
    fi
    if [ -n "$proxy_url" ] && [ "$proxy_url" != "undefined" ]; then
        echo -e "${CYAN}Proxy URL:${NC} ${WHITE}$proxy_url${NC}"
        if curl -fsS --max-time 5 "$proxy_url" >/dev/null 2>&1; then
            log_info "Proxy 连通性检查通过"
        else
            log_warn "Proxy URL 无法直接连通，请检查 LangBot 适配器服务状态"
        fi
    else
        log_warn "未检测到 channels.wechat.proxyUrl / accounts.main.proxyUrl"
    fi

    if [ "$plugin_ok" = true ] && [ "$channel_ok" = true ]; then
        log_info "微信配置探针通过"
        return 0
    fi

    echo ""
    echo -e "${YELLOW}排障建议:${NC}"
    echo "  1) openclaw doctor --fix"
    echo "  2) openclaw plugins update --all"
    echo "  3) 重新执行微信配置向导"
    return 1
}

rollback_wechat_langbot_config() {
    echo ""
    echo -e "${WHITE}♻️ 回滚微信（LangBot/WeChatPad）配置${NC}"
    print_divider
    echo ""
    echo -e "${YELLOW}将执行:${NC}"
    echo "  • 禁用并卸载微信社区插件"
    echo "  • 清理 channels.wechat 与 plugins.allow 残留"
    echo "  • 清理 WECHATPADPRO_* 环境变量"
    echo ""

    if ! confirm "确认执行回滚？" "n"; then
        log_info "已取消回滚"
        return 0
    fi

    openclaw plugins disable wechat > /dev/null 2>&1 || true
    openclaw plugins uninstall wechat --keep-files > /dev/null 2>&1 || true
    openclaw plugins uninstall "$WECHAT_PLUGIN_LANGBOT" --keep-files > /dev/null 2>&1 || true

    if openclaw config --help 2>/dev/null | grep -q "unset"; then
        openclaw config unset channels.wechat > /dev/null 2>&1 || true
        openclaw config unset plugins.entries.wechat > /dev/null 2>&1 || true
    else
        openclaw config set channels.wechat.enabled false > /dev/null 2>&1 || true
    fi

    remove_plugin_from_allow "wechat" || true
    remove_env_export "WECHATPADPRO_BASEURL"
    remove_env_export "WECHATPADPRO_API_KEY"
    remove_env_export "WECHATPADPRO_CALLBACK_HOST"
    remove_env_export "WECHATPADPRO_CALLBACK_PORT"
    remove_env_export "WECHATPADPRO_CALLBACK_PATH"

    log_info "微信配置回滚完成"
    if confirm "是否重启 Gateway 使回滚生效？" "y"; then
        restart_gateway_for_channel
    fi
    return 0
}

config_wechat_langbot_setup() {
    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装"
        return 1
    fi

    ensure_openclaw_init

    local plugin_version="${OPENCLAW_WECHAT_PLUGIN_VERSION:-$WECHAT_PLUGIN_VERSION_DEFAULT}"
    local plugin_spec="${WECHAT_PLUGIN_LANGBOT}@${plugin_version}"
    local proxy_url=""
    local api_key=""
    local webhook_host=""
    local webhook_port=""
    local webhook_path=""

    webhook_host="$(get_gateway_host)"
    webhook_port="$(get_gateway_port)"
    webhook_path="$WECHATPAD_CALLBACK_PATH_DEFAULT"

    echo -e "${YELLOW}⚠️ 社区适配说明:${NC}"
    echo "  • 微信/WeChatPad 当前不在 OpenClaw 官方渠道列表中"
    echo "  • 此方案按 LangBot 适配器流程对接 WeChatPad 协议"
    echo "  • 插件固定版本安装，降低升级漂移风险"
    echo ""
    echo -e "${CYAN}参考字段（LangBot 文档）:${NC}"
    echo "  • WECHATPADPRO_BASEURL"
    echo "  • WECHATPADPRO_API_KEY"
    echo ""

    if ! confirm "继续安装并配置微信 WeChatPad 适配？" "n"; then
        log_info "已取消微信配置"
        return 0
    fi

    echo ""
    echo -e "${CYAN}安装插件: ${WHITE}${plugin_spec}${NC}"
    if openclaw plugins install "$plugin_spec" --pin; then
        log_info "微信社区插件安装成功"
    else
        log_warn "插件安装失败，尝试继续使用已安装版本"
        if ! openclaw plugins list 2>/dev/null | grep -Eqi "openclaw-wechat-channel|wechat"; then
            log_error "未检测到微信插件，无法继续"
            return 1
        fi
    fi

    openclaw plugins enable wechat > /dev/null 2>&1 || true
    ensure_plugin_in_allow "wechat"

    echo ""
    read_input "${YELLOW}LangBot/WeChatPad 代理地址 (如 https://your-proxy.example.com): ${NC}" proxy_url
    read_secret_input "${YELLOW}微信 API Key: ${NC}" api_key
    read_input "${YELLOW}回调 Host（默认 ${webhook_host}）: ${NC}" webhook_host
    webhook_host="${webhook_host:-$(get_gateway_host)}"
    read_input "${YELLOW}回调 Port（默认 ${webhook_port}）: ${NC}" webhook_port
    webhook_port="${webhook_port:-$(get_gateway_port)}"
    read_input "${YELLOW}回调 Path（默认 ${webhook_path}）: ${NC}" webhook_path
    webhook_path="${webhook_path:-$WECHATPAD_CALLBACK_PATH_DEFAULT}"

    if [ -z "$proxy_url" ] || [ -z "$api_key" ]; then
        log_error "proxy_url / api_key 不能为空"
        return 1
    fi
    if ! is_valid_port "$webhook_port"; then
        log_error "回调端口无效: $webhook_port"
        return 1
    fi

    # 注册渠道（部分版本可选）
    openclaw channels add --channel wechat > /dev/null 2>&1 || true

    # 写入主账号配置，采用 accounts.main 结构
    openclaw config set channels.wechat.enabled true > /dev/null 2>&1 || true
    openclaw config set channels.wechat.accounts.main.enabled true > /dev/null 2>&1 || true
    openclaw config set channels.wechat.accounts.main.name "wechatpad-main" > /dev/null 2>&1 || true
    openclaw config set channels.wechat.accounts.main.apiKey "$api_key" > /dev/null 2>&1 || true
    openclaw config set channels.wechat.accounts.main.proxyUrl "$proxy_url" > /dev/null 2>&1 || true
    openclaw config set channels.wechat.accounts.main.webhookHost "$webhook_host" > /dev/null 2>&1 || true
    openclaw config set channels.wechat.accounts.main.webhookPort "$webhook_port" > /dev/null 2>&1 || true
    openclaw config set channels.wechat.accounts.main.webhookPath "$webhook_path" > /dev/null 2>&1 || true

    # 顶层镜像字段，兼容部分社区插件读取路径
    openclaw config set channels.wechat.apiKey "$api_key" > /dev/null 2>&1 || true
    openclaw config set channels.wechat.proxyUrl "$proxy_url" > /dev/null 2>&1 || true
    openclaw config set channels.wechat.webhookHost "$webhook_host" > /dev/null 2>&1 || true
    openclaw config set channels.wechat.webhookPort "$webhook_port" > /dev/null 2>&1 || true
    openclaw config set channels.wechat.webhookPath "$webhook_path" > /dev/null 2>&1 || true

    upsert_env_export "WECHATPADPRO_BASEURL" "$proxy_url"
    upsert_env_export "WECHATPADPRO_API_KEY" "$api_key"
    upsert_env_export "WECHATPADPRO_CALLBACK_HOST" "$webhook_host"
    upsert_env_export "WECHATPADPRO_CALLBACK_PORT" "$webhook_port"
    upsert_env_export "WECHATPADPRO_CALLBACK_PATH" "$webhook_path"

    log_info "微信 WeChatPad 适配配置完成"
    echo -e "${CYAN}回调地址:${NC} ${WHITE}http://${webhook_host}:${webhook_port}${webhook_path}${NC}"

    if confirm "是否立即执行微信配置探针？" "y"; then
        probe_wechat_langbot_config || true
    fi
    if confirm "是否重启 Gateway 使配置生效？" "y"; then
        restart_gateway_for_channel
    fi
    return 0
}

config_wechat() {
    clear_screen
    print_header
    echo -e "${WHITE}🟢 微信（LangBot WeChatPad）${NC}"
    print_divider
    echo ""
    echo "  1) 配置 LangBot 适配器（WeChatPad 协议）"
    echo "  2) 微信配置探针"
    echo "  3) 回滚微信配置"
    echo "  0) 返回"
    echo ""
    read_input "${YELLOW}请选择 [0-3]: ${NC}" wechat_choice

    case "$wechat_choice" in
        1) config_wechat_langbot_setup ;;
        2) probe_wechat_langbot_config ;;
        3) rollback_wechat_langbot_config ;;
        0) return ;;
        *) log_error "无效选择" ;;
    esac
    press_enter
}

config_imessage() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🍎 配置 iMessage${NC}"
    print_divider
    echo ""
    
    echo -e "${YELLOW}⚠️ 注意: iMessage 仅支持 macOS${NC}"
    echo ""
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "iMessage 仅支持 macOS 系统"
        press_enter
        return
    fi
    
    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装"
        press_enter
        return
    fi
    
    echo -e "${CYAN}iMessage 配置需要:${NC}"
    echo "  1. 授予终端完整磁盘访问权限"
    echo "  2. 确保 Messages.app 已登录"
    echo ""
    echo -e "${YELLOW}系统偏好设置 → 隐私与安全性 → 完整磁盘访问权限 → 添加终端${NC}"
    echo ""
    
    if confirm "是否继续配置？"; then
        # 确保初始化
        ensure_openclaw_init
        
        # 启用 iMessage 插件
        echo ""
        log_info "启用 iMessage 插件..."
        openclaw plugins enable imessage 2>/dev/null || true
        ensure_plugin_in_allow "imessage"
        
        # 添加 iMessage channel
        echo ""
        log_info "配置 iMessage 渠道..."
        openclaw channels add --channel imessage 2>/dev/null || true
        
        echo ""
        log_info "iMessage 配置完成！"
        
        if confirm "是否重启 Gateway 使配置生效？" "y"; then
            restart_gateway_for_channel
        fi
    fi
    
    press_enter
}

# 安装飞书插件（仅官方包）
install_feishu_plugin() {
    echo -e "${YELLOW}安装飞书插件...${NC}"
    echo ""

    # 先清理同名插件，避免历史社区包与官方包冲突
    if openclaw plugins list 2>/dev/null | grep -qi "feishu"; then
        log_info "检测到已安装飞书插件，先执行重装清理..."
        openclaw plugins disable feishu > /dev/null 2>&1 || true
        openclaw plugins uninstall feishu --keep-files > /dev/null 2>&1 || true
    fi

    local preferred_version="${OPENCLAW_FEISHU_PLUGIN_VERSION:-}"
    local preferred_spec="$FEISHU_PLUGIN_OFFICIAL"
    if [ -n "$preferred_version" ]; then
        preferred_spec="${FEISHU_PLUGIN_OFFICIAL}@${preferred_version}"
    fi
    
    echo -e "${CYAN}正在安装飞书插件 ${preferred_spec} ...${NC}"
    echo ""
    
    # 仅安装官方插件包，并 pin 版本，降低后续升级漂移风险
    local install_output
    install_output=$(openclaw plugins install "$preferred_spec" --pin 2>&1)
    local install_exit=$?
    
    # 过滤掉 banner，显示关键信息
    echo "$install_output" | grep -v "^🦞" | grep -v "^$" | head -5
    
    if [ $install_exit -eq 0 ]; then
        openclaw plugins enable feishu > /dev/null 2>&1 || true
        ensure_plugin_in_allow "feishu"
        echo ""
        log_info "✅ 飞书插件安装成功！"
        return 0
    else
        echo ""
        log_warn "插件安装失败: $preferred_spec"
        
        echo ""
        log_error "飞书插件安装失败，请手动重试"
        echo -e "${CYAN}官方插件:${NC} ${WHITE}openclaw plugins install $FEISHU_PLUGIN_OFFICIAL${NC}"
        return 1
    fi
}

# 保存飞书配置（使用 openclaw 原生命令）
save_feishu_config() {
    local app_id="$1"
    local app_secret="$2"
    
    echo -e "${YELLOW}添加飞书渠道...${NC}"
    
    # 使用 openclaw channels add 添加飞书渠道
    local add_output
    add_output=$(openclaw channels add --channel feishu 2>&1)
    local add_exit=$?
    
    # 过滤掉 openclaw banner，只显示关键信息
    echo "$add_output" | grep -v "^🦞" | grep -v "^$" | head -3
    
    if [ $add_exit -ne 0 ]; then
        log_warn "飞书渠道可能已存在，继续配置..."
    fi
    
    # 使用官方推荐结构写入 credentials（accounts.main）
    echo -e "${YELLOW}配置 App ID...${NC}"
    local set_output
    set_output=$(openclaw config set channels.feishu.accounts.main.appId "$app_id" 2>&1)
    local set_exit=$?
    
    if [ $set_exit -ne 0 ]; then
        echo "$set_output" | grep -v "^🦞" | grep -v "^$"
        log_error "设置 App ID 失败"
        return 1
    fi
    echo "$set_output" | grep -v "^🦞" | grep -v "^$" | head -1
    
    echo -e "${YELLOW}配置 App Secret...${NC}"
    set_output=$(openclaw config set channels.feishu.accounts.main.appSecret "$app_secret" 2>&1)
    set_exit=$?
    
    if [ $set_exit -ne 0 ]; then
        echo "$set_output" | grep -v "^🦞" | grep -v "^$"
        log_error "设置 App Secret 失败"
        return 1
    fi
    echo "$set_output" | grep -v "^🦞" | grep -v "^$" | head -1
    
    # 保持最小必要配置，避免覆盖用户现有个性化设置
    openclaw config set channels.feishu.enabled true > /dev/null 2>&1 || true
    openclaw config set channels.feishu.accounts.main.enabled true > /dev/null 2>&1 || true
    openclaw config set channels.feishu.connectionMode websocket > /dev/null 2>&1 || true
    
    log_info "飞书渠道配置完成"
    return 0
}

# 飞书配置探针：检查插件、渠道与关键配置项
probe_feishu_config() {
    echo ""
    echo -e "${CYAN}━━━ 飞书配置探针 ━━━${NC}"
    echo ""
    
    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装，无法探针"
        return 1
    fi
    
    local plugin_ok=false
    local channel_ok=false
    
    if openclaw plugins list 2>/dev/null | grep -qi "feishu"; then
        plugin_ok=true
        log_info "飞书插件已安装"
    else
        log_warn "飞书插件未在 plugins list 中出现"
    fi
    
    if openclaw channels list 2>/dev/null | grep -qi "feishu"; then
        channel_ok=true
        log_info "飞书渠道已注册"
    else
        log_warn "飞书渠道未在 channels list 中出现"
    fi
    
    local mode=$(openclaw config get channels.feishu.connectionMode 2>/dev/null || echo "")
    if [ -n "$mode" ] && [ "$mode" != "undefined" ]; then
        log_info "连接模式: $mode"
    else
        log_warn "未读取到 channels.feishu.connectionMode"
    fi
    
    if [ "$plugin_ok" = true ] && [ "$channel_ok" = true ]; then
        log_info "飞书配置探针通过"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}排障建议:${NC}"
    echo "  1) openclaw doctor --fix"
    echo "  2) openclaw plugins update --all"
    echo "  3) openclaw gateway restart"
    return 1
}

config_feishu() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔷 配置飞书 (Feishu)${NC}"
    print_divider
    echo ""
    
    echo -e "${YELLOW}⚠️ 注意: 飞书接入依赖插件，请优先使用官方插件${NC}"
    echo ""
    
    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装"
        press_enter
        return
    fi
    
    echo -e "${CYAN}飞书接入说明:${NC}"
    echo ""
    echo -e "  ${WHITE}仅使用官方插件 @openclaw/feishu${NC}"
    echo ""
    echo -e "  ${GREEN}✓ 支持 WebSocket 连接（无需公网服务器）${NC}"
    echo -e "  ${GREEN}✓ 支持私聊和群聊${NC}"
    echo -e "  ${GREEN}✓ 支持图片、文件等多媒体${NC}"
    echo -e "  ${GREEN}✓ 个人账号即可使用，无需企业认证${NC}"
    echo ""
    echo -e "  ${YELLOW}📝 需要在飞书开放平台创建应用（免费，5分钟）${NC}"
    echo ""
    print_divider
    echo ""
    
    if confirm "是否开始配置飞书？"; then
        config_feishu_app
    fi
}

# 飞书企业自建应用配置
config_feishu_app() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔷 飞书应用配置${NC}"
    print_divider
    echo ""
    
    echo -e "${GREEN}✓ 个人账号即可使用，无需企业认证！${NC}"
    echo -e "${CYAN}  （"自建应用"只是飞书的命名，任何人都可以创建）${NC}"
    echo ""
    
    echo -e "${CYAN}配置步骤:${NC}"
    echo ""
    echo "  ${WHITE}第一步: 安装飞书插件${NC} (自动完成)"
    echo "    • 安装官方插件 @openclaw/feishu"
    echo ""
    echo "  ${WHITE}第二步: 飞书开放平台创建应用${NC}"
    echo "    1. 访问 https://open.feishu.cn/app (飞书)"
    echo "       或 https://open.larksuite.com/app (Lark 国际版)"
    echo "    2. 创建企业自建应用 → 添加「机器人」能力"
    echo "    3. 获取 App ID 和 App Secret"
    echo ""
    echo "  ${WHITE}第三步: 配置机器人权限${NC}"
    echo "    • 权限管理 → 建议使用「批量导入」(更稳)"
    echo "      - im:message (收发消息，必须)"
    echo "      - im:message:send_as_bot (发送消息，必须)"
    echo "      - im:resource (图片/文件，多媒体推荐)"
    echo "      - im:chat:readonly (读取群信息，推荐)"
    echo "    • 可选查看官方推荐 scopes JSON（脚本稍后可打印）"
    echo ""
    echo "  ${WHITE}第四步: 输入配置信息${NC}"
    echo "    • 在此输入 App ID 和 App Secret"
    echo "    • ${GREEN}使用长连接模式，无需 Verification Token${NC}"
    echo ""
    echo "  ${WHITE}第五步: 配置事件订阅（飞书后台）${NC}"
    echo "    • 事件与回调 → 选择「使用长连接接收事件」"
    echo "    • ${GREEN}无需公网服务器，无需 Webhook 地址${NC}"
    echo "    • 添加事件: im.message.receive_v1"
    echo ""
    echo "  ${WHITE}第六步: 发布应用并添加到群组${NC}"
    echo "    • 版本管理与发布 → 创建版本 → 发布"
    echo "    • 在飞书群组设置中添加机器人"
    echo ""
    print_divider
    echo ""
    
    if ! confirm "是否开始配置？"; then
        press_enter
        return
    fi
    
    # ========== 第一步：安装飞书插件 ==========
    echo ""
    echo -e "${WHITE}━━━ 第一步: 安装飞书插件 (自动) ━━━${NC}"
    echo ""
    
    if ! install_feishu_plugin; then
        log_error "飞书插件安装失败，已停止后续飞书配置。"
        press_enter
        return
    fi
    
    echo ""
    log_info "✅ 第一步完成！插件已就绪"
    echo ""
    
    # ========== 第二、三步提示 ==========
    echo -e "${WHITE}━━━ 第二、三步: 请在飞书开放平台完成 ━━━${NC}"
    echo ""
    echo -e "${CYAN}请打开飞书开放平台完成以下操作:${NC}"
    echo "  1. 访问 https://open.feishu.cn/app (飞书) 或 https://open.larksuite.com/app (Lark)"
    echo "  2. 创建企业自建应用 → 添加「机器人」能力"
    echo "  3. 获取 App ID 和 App Secret"
    echo "  4. 权限管理 → 建议「批量导入」权限 scopes"
    echo "     - 至少包含: im:message / im:message:send_as_bot"
    echo "     - 多媒体建议: im:resource"
    echo "     - 群信息建议: im:chat:readonly"
    echo ""
    echo -e "${GREEN}💡 提示: 使用长连接模式，无需配置公网 Webhook 地址${NC}"
    echo ""

    if confirm "是否显示官方推荐「权限管理 → 批量导入」JSON？" "n"; then
        echo ""
        echo -e "${CYAN}将以下 JSON 粘贴到飞书后台：权限管理 → 批量导入${NC}"
        cat << 'EOF'
{
  "scopes": {
    "tenant": [
      "aily:file:read",
      "aily:file:write",
      "application:application.app_message_stats.overview:readonly",
      "application:application:self_manage",
      "application:bot.menu:write",
      "cardkit:card:read",
      "cardkit:card:write",
      "contact:user.employee_id:readonly",
      "corehr:file:download",
      "event:ip_list",
      "im:chat.access_event.bot_p2p_chat:read",
      "im:chat.members:bot_access",
      "im:message",
      "im:message.group_at_msg:readonly",
      "im:message.p2p_msg:readonly",
      "im:message:readonly",
      "im:message:send_as_bot",
      "im:resource"
    ],
    "user": ["aily:file:read", "aily:file:write", "im:chat.access_event.bot_p2p_chat:read"]
  }
}
EOF
        echo ""
        echo -e "${GRAY}完整版步骤文档: https://github.com/${INSTALLER_REPO}/blob/main/docs/feishu-setup.md${NC}"
    fi
    
    if ! confirm "已完成飞书后台配置，继续输入信息？"; then
        press_enter
        return
    fi
    
    # ========== 第五步：输入配置并启动服务 ==========
    echo ""
    echo -e "${WHITE}━━━ 第五步: 输入配置并启动服务 ━━━${NC}"
    echo ""
    echo -e "${CYAN}📝 使用长连接模式，只需要 App ID 和 App Secret${NC}"
    echo -e "${GRAY}   (无需 Verification Token 和 Encrypt Key)${NC}"
    echo ""
    echo -en "${YELLOW}输入 App ID: ${NC}"
    read feishu_app_id < "$TTY_INPUT"
    read_secret_input "${YELLOW}输入 App Secret: ${NC}" feishu_app_secret
    
    if [ -z "$feishu_app_id" ] || [ -z "$feishu_app_secret" ]; then
        log_error "App ID 和 App Secret 不能为空"
        press_enter
        return
    fi
    
    echo ""
    log_info "正在保存配置..."
    
    # 使用专用函数保存飞书配置到 JSON 文件
    echo -e "${YELLOW}配置飞书渠道...${NC}"
    
    if save_feishu_config "$feishu_app_id" "$feishu_app_secret"; then
        log_info "飞书渠道配置成功！"
        probe_feishu_config || true
    else
        log_warn "配置保存失败，请检查"
    fi
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}✅ 配置已保存！${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "App ID: ${WHITE}${feishu_app_id:0:15}...${NC}"
    echo -e "连接模式: ${WHITE}WebSocket 长连接${NC}"
    echo -e "${GREEN}✓ 无需公网服务器${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  重要: 需要先启动 Gateway 服务！${NC}"
    echo -e "${CYAN}   启动后才能在飞书后台配置长连接${NC}"
    echo ""
    
    if confirm "是否现在启动/重启 Gateway？" "y"; then
        restart_gateway_for_channel
    fi
    
    echo ""
    echo -e "${WHITE}━━━ 第六步: 配置事件订阅 (飞书后台) ━━━${NC}"
    echo ""
    echo -e "${YELLOW}⚠️ 请确保 OpenClaw Gateway 服务已启动${NC}"
    echo ""
    echo -e "${CYAN}📋 在飞书开放平台完成以下配置:${NC}"
    echo ""
    echo -e "  ${WHITE}1. 事件与回调 → 选择「使用长连接接收事件」${NC}"
    echo -e "     ${GREEN}✓ 无需公网服务器，无需 Webhook 地址${NC}"
    echo -e "     ${YELLOW}⚠️ 如果无法保存，请确认 Gateway 已启动${NC}"
    echo ""
    echo -e "  ${WHITE}2. 添加事件订阅:${NC}"
    echo "     • im.message.receive_v1 (接收消息，必须)"
    echo "     • im.message.message_read_v1 (已读回执，可选)"
    echo "     • im.chat.member.bot.added_v1 (机器人入群，可选)"
    echo ""
    echo -e "${WHITE}━━━ 第七步: 添加机器人到群组 ━━━${NC}"
    echo ""
    echo -e "${CYAN}📋 在飞书客户端添加机器人:${NC}"
    echo "  1. 打开目标群组 → 设置（右上角 ⚙️）"
    echo "  2. 群机器人 → 添加机器人"
    echo "  3. 搜索你的机器人名称并添加"
    echo ""
    
    # 询问是否测试
    echo ""
    if confirm "是否发送测试消息验证配置？" "y"; then
        echo ""
        echo -e "${CYAN}如需发送测试消息，请输入群组 Chat ID:${NC}"
        echo -e "${GRAY}获取方式: 群设置 → 群信息 → 群号${NC}"
        echo ""
        echo -en "${YELLOW}Chat ID (留空跳过测试): ${NC}"
        read feishu_chat_id < "$TTY_INPUT"
        
        if [ -n "$feishu_chat_id" ]; then
            test_feishu_bot "$feishu_app_id" "$feishu_app_secret" "$feishu_chat_id"
        else
            test_feishu_bot "$feishu_app_id" "$feishu_app_secret"
        fi
    fi
    
    press_enter
}

# ================================ 身份配置 ================================

config_identity() {
    clear_screen
    print_header
    
    echo -e "${WHITE}👤 身份与个性配置${NC}"
    print_divider
    echo ""
    
    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装"
        press_enter
        return
    fi
    
    # 显示当前配置
    echo -e "${CYAN}当前配置:${NC}"
    openclaw config get identity 2>/dev/null || echo "  (未配置)"
    echo ""
    print_divider
    echo ""
    
    read -p "$(echo -e "${YELLOW}助手名称: ${NC}")" bot_name
    read -p "$(echo -e "${YELLOW}如何称呼你: ${NC}")" user_name
    read -p "$(echo -e "${YELLOW}时区 (如 Asia/Shanghai): ${NC}")" timezone
    
    # 使用 openclaw 命令设置
    [ -n "$bot_name" ] && openclaw config set identity.name "$bot_name" 2>/dev/null
    [ -n "$user_name" ] && openclaw config set identity.user_name "$user_name" 2>/dev/null
    [ -n "$timezone" ] && openclaw config set identity.timezone "$timezone" 2>/dev/null
    
    echo ""
    log_info "身份配置已更新！"
    
    press_enter
}

# ================================ 安全配置 ================================

config_security() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔒 安全配置${NC}"
    print_divider
    echo ""
    
    echo -e "${RED}⚠️ 警告: 以下设置涉及安全风险，请谨慎配置${NC}"
    echo ""
    
    print_menu_item "1" "允许执行系统命令" "⚙️"
    print_menu_item "2" "允许文件访问" "📁"
    print_menu_item "3" "允许网络浏览" "🌐"
    print_menu_item "4" "沙箱模式 (推荐开启)" "📦"
    print_menu_item "5" "配置白名单" "✅"
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    echo -en "${YELLOW}请选择 [0-5]: ${NC}"
    read choice < "$TTY_INPUT"
    
    case $choice in
        1)
            local enable_shell="false"
            if confirm "允许 OpenClaw 执行系统命令？这可能带来安全风险" "n"; then
                enable_shell="true"
            fi
            if check_openclaw_installed; then
                openclaw config set security.enable_shell_commands "$enable_shell" 2>/dev/null || true
            fi
            [ "$enable_shell" = "true" ] && log_info "已启用系统命令执行" || log_info "已禁用系统命令执行"
            ;;
        2)
            local enable_file="false"
            if confirm "允许 OpenClaw 读写文件？" "n"; then
                enable_file="true"
            fi
            if check_openclaw_installed; then
                openclaw config set security.enable_file_access "$enable_file" 2>/dev/null || true
            fi
            [ "$enable_file" = "true" ] && log_info "已启用文件访问" || log_info "已禁用文件访问"
            ;;
        3)
            local enable_web="false"
            if confirm "允许 OpenClaw 浏览网络？" "y"; then
                enable_web="true"
            fi
            if check_openclaw_installed; then
                openclaw config set security.enable_web_browsing "$enable_web" 2>/dev/null || true
            fi
            [ "$enable_web" = "true" ] && log_info "已启用网络浏览" || log_info "已禁用网络浏览"
            ;;
        4)
            local sandbox_mode="false"
            if confirm "启用沙箱模式？(推荐)" "y"; then
                sandbox_mode="true"
            fi
            if check_openclaw_installed; then
                openclaw config set security.sandbox_mode "$sandbox_mode" 2>/dev/null || true
            fi
            [ "$sandbox_mode" = "true" ] && log_info "已启用沙箱模式" || log_warn "已禁用沙箱模式，请注意安全风险"
            ;;
        5)
            config_whitelist
            ;;
        0)
            return
            ;;
    esac
    
    press_enter
    config_security
}

config_whitelist() {
    clear_screen
    print_header
    
    echo -e "${WHITE}✅ 配置白名单${NC}"
    print_divider
    echo ""
    
    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装"
        press_enter
        return
    fi
    
    echo -e "${CYAN}使用 openclaw 命令配置白名单:${NC}"
    echo ""
    echo "  openclaw config set security.allowed_paths '/path/to/dir1,/path/to/dir2'"
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入允许访问的目录 (逗号分隔): ${NC}")" paths
    
    if [ -n "$paths" ]; then
        openclaw config set security.allowed_paths "$paths" 2>/dev/null
        log_info "白名单配置已保存"
    fi
}

# ================================ 服务管理 ================================

stop_openclaw_for_uninstall() {
    log_info "正在停止 OpenClaw 服务..."
    if check_openclaw_installed; then
        openclaw gateway stop 2>/dev/null || true
        sleep 1
    fi
    local uninstall_pid
    uninstall_pid="$(get_gateway_pid)"
    if [ -n "$uninstall_pid" ]; then
        log_warn "强制停止残留进程 (PID: $uninstall_pid)"
        kill -9 "$uninstall_pid" 2>/dev/null || true
        sleep 1
    fi
}

remove_openclaw_system_services() {
    if [ -f "$HOME/Library/LaunchAgents/com.openclaw.agent.plist" ]; then
        log_info "移除 macOS 系统服务..."
        launchctl unload "$HOME/Library/LaunchAgents/com.openclaw.agent.plist" 2>/dev/null || true
        rm -f "$HOME/Library/LaunchAgents/com.openclaw.agent.plist" 2>/dev/null || true
    fi

    if [ -f "/etc/systemd/system/openclaw.service" ]; then
        log_info "移除 systemd 系统服务..."
        sudo systemctl stop openclaw 2>/dev/null || true
        sudo systemctl disable openclaw 2>/dev/null || true
        sudo rm -f /etc/systemd/system/openclaw.service 2>/dev/null || true
        sudo systemctl daemon-reload 2>/dev/null || true
    fi
}

uninstall_openclaw_global() {
    echo ""
    echo -e "${CYAN}执行全局卸载（保留 ~/.openclaw 目录）...${NC}"
    stop_openclaw_for_uninstall
    remove_openclaw_system_services

    log_info "卸载全局 npm 包 openclaw..."
    npm uninstall -g openclaw 2>&1 | grep -v "^npm" | head -8 || true

    if command -v openclaw >/dev/null 2>&1; then
        log_warn "openclaw 命令仍存在，请检查是否有多重安装源"
    else
        log_info "全局卸载完成"
    fi
}

uninstall_openclaw_directory_preserve_assets() {
    local oc_dir="$HOME/.openclaw"
    echo ""
    echo -e "${CYAN}执行目录卸载（保留 skills / plugins）...${NC}"

    if [ ! -d "$oc_dir" ]; then
        log_warn "未找到目录: $oc_dir"
        return 0
    fi

    local tmp_keep
    tmp_keep="$(mktemp -d)"

    if [ -d "$oc_dir/skills" ]; then
        cp -a "$oc_dir/skills" "$tmp_keep/skills" 2>/dev/null || true
    fi
    if [ -d "$oc_dir/plugins" ]; then
        cp -a "$oc_dir/plugins" "$tmp_keep/plugins" 2>/dev/null || true
    fi

    rm -rf "$oc_dir"
    mkdir -p "$oc_dir"
    chmod 700 "$oc_dir" 2>/dev/null || true

    if [ -d "$tmp_keep/skills" ]; then
        cp -a "$tmp_keep/skills" "$oc_dir/skills" 2>/dev/null || true
    fi
    if [ -d "$tmp_keep/plugins" ]; then
        cp -a "$tmp_keep/plugins" "$oc_dir/plugins" 2>/dev/null || true
    fi
    rm -rf "$tmp_keep"

    log_info "目录卸载完成：已保留 ~/.openclaw/skills 与 ~/.openclaw/plugins"
}

uninstall_openclaw_directory_full() {
    local oc_dir="$HOME/.openclaw"
    if [ -d "$oc_dir" ]; then
        rm -rf "$oc_dir"
        log_info "已删除目录: $oc_dir"
    else
        log_warn "未找到目录: $oc_dir"
    fi
}

openclaw_uninstall_menu() {
    clear_screen
    print_header
    echo -e "${WHITE}🗑️ OpenClaw 卸载中心${NC}"
    print_divider
    echo ""
    echo "  1) 全局卸载（移除命令、服务；保留 ~/.openclaw）"
    echo "  2) 目录卸载（仅清理 ~/.openclaw，保留 skills/plugins）"
    echo "  3) 完全卸载（全局 + 删除 ~/.openclaw）"
    echo "  0) 返回"
    echo ""
    read_input "${YELLOW}请选择 [0-3]: ${NC}" uninstall_choice

    case "$uninstall_choice" in
        1)
            if confirm "确认执行全局卸载？" "n"; then
                uninstall_openclaw_global
            else
                log_info "已取消"
            fi
            ;;
        2)
            if confirm "确认执行目录卸载并保留 skills/plugins？" "n"; then
                uninstall_openclaw_directory_preserve_assets
            else
                log_info "已取消"
            fi
            ;;
        3)
            if confirm "确认执行完全卸载？该操作不可恢复" "n"; then
                uninstall_openclaw_global
                uninstall_openclaw_directory_full
            else
                log_info "已取消"
            fi
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            ;;
    esac

    echo ""
    echo -e "${CYAN}如需重新安装:${NC}"
    echo "  curl -fsSL ${INSTALLER_RAW_URL}/install.sh | bash"
    press_enter
}

manage_service() {
    clear_screen
    print_header
    
    echo -e "${WHITE}⚡ 服务管理${NC}"
    print_divider
    echo ""
    
    # 使用端口检测判断服务状态（更可靠）
    local menu_status_pid
    menu_status_pid=$(get_gateway_pid)
    if [ -n "$menu_status_pid" ]; then
        echo -e "  当前状态: ${GREEN}● 运行中${NC} (PID: $menu_status_pid)"
    else
        echo -e "  当前状态: ${RED}● 已停止${NC}"
    fi
    echo ""
    
    print_menu_item "1" "启动服务" "▶️"
    print_menu_item "2" "停止服务" "⏹️"
    print_menu_item "3" "重启服务" "🔄"
    print_menu_item "4" "查看状态" "📊"
    print_menu_item "5" "查看日志" "📋"
    print_menu_item "6" "运行诊断并修复" "🔍"
    print_menu_item "7" "安装为系统服务" "⚙️"
    print_menu_item "9" "修改 Gateway 地址/端口" "🌐"
    echo ""
    echo -e "  ${RED}[8]${NC} 🗑️  卸载 OpenClaw"
    echo ""
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    echo -en "${YELLOW}请选择 [0-9]: ${NC}"
    read choice < "$TTY_INPUT"
    
    case $choice in
        1)
            echo ""
            if check_openclaw_installed; then
                # 先检查服务是否已经在运行（使用端口检测，更可靠）
                local port
                port="$(get_gateway_port)"
                local running_pid
                running_pid=$(get_port_pid "$port")
                
                if [ -n "$running_pid" ]; then
                    echo -e "${GREEN}✓ 服务已经在运行中！${NC} (PID: $running_pid)"
                    echo ""
                    
                    # 获取并显示 Dashboard URL
                    local dashboard_url=$(openclaw dashboard --no-open 2>/dev/null | grep -E "^https?://" | head -1)
                    if [ -n "$dashboard_url" ]; then
                        echo -e "${GREEN}Dashboard URL (带授权 token):${NC}"
                        echo -e "  ${WHITE}$dashboard_url${NC}"
                    else
                        echo -e "${YELLOW}提示: 运行 ${WHITE}openclaw dashboard${NC} 获取访问 URL"
                    fi
                    echo ""
                    
                    if confirm "是否重启服务？" "n"; then
                        # 使用官方 restart 命令
                        if [ -f "$OPENCLAW_ENV" ]; then
                            source "$OPENCLAW_ENV"
                        fi
                        openclaw gateway restart 2>&1 | head -5
                        sleep 2
                        log_info "服务已重启"
                    fi
                    
                    press_enter
                    manage_service
                    return
                fi
                
                # 检测端口是否被其他进程占用
                local port_pid
                port_pid=$(get_port_pid "$port")
                
                if [ -n "$port_pid" ]; then
                    echo -e "${YELLOW}检测到端口 $port 被其他进程占用 (PID: $port_pid)${NC}"
                    if confirm "是否停止占用端口的进程？" "y"; then
                        openclaw gateway stop > /dev/null 2>&1 || true
                        sleep 1
                        port_pid=$(get_port_pid "$port")
                        if [ -n "$port_pid" ]; then
                            kill -9 $port_pid 2>/dev/null || true
                            sleep 1
                        fi
                        log_info "已清理端口占用"
                    else
                        log_warn "端口被占用，无法启动新服务"
                        press_enter
                        manage_service
                        return
                    fi
                fi
                
                # 确保基础配置正确
                ensure_openclaw_init
                
                # 加载环境变量
                if [ -f "$OPENCLAW_ENV" ]; then
                    source "$OPENCLAW_ENV"
                    log_info "已加载环境变量"
                fi
                
                # 先运行 doctor --fix 确保配置有效（与重启保持一致）
                log_info "检查并修复配置..."
                yes | openclaw doctor --fix > /dev/null 2>&1 || true
                
                # 验证修复后的配置
                local config_check=$(openclaw doctor 2>&1 | head -5)
                if echo "$config_check" | grep -qi "Config invalid"; then
                    log_error "配置无效，无法自动修复"
                    echo ""
                    echo -e "${YELLOW}错误详情:${NC}"
                    echo "$config_check" | head -10
                    echo ""
                    echo -e "${CYAN}请手动运行: openclaw doctor --fix${NC}"
                    press_enter
                    manage_service
                    return
                fi
                
                log_info "正在启动服务..."
                
                # 后台启动 Gateway（使用 setsid 完全脱离终端）
                if command -v setsid &> /dev/null; then
                    if [ -f "$OPENCLAW_ENV" ]; then
                        setsid bash -c "source $OPENCLAW_ENV && exec openclaw gateway --port ${port}" > /tmp/openclaw-gateway.log 2>&1 &
                    else
                        setsid openclaw gateway --port "${port}" > /tmp/openclaw-gateway.log 2>&1 &
                    fi
                else
                    # 备用方案：nohup + disown
                    if [ -f "$OPENCLAW_ENV" ]; then
                        nohup bash -c "source $OPENCLAW_ENV && exec openclaw gateway --port ${port}" > /tmp/openclaw-gateway.log 2>&1 &
                    else
                        nohup openclaw gateway --port "${port}" > /tmp/openclaw-gateway.log 2>&1 &
                    fi
                    disown 2>/dev/null || true
                fi
                
                # 等待服务启动，多次检测端口
                local gateway_pid=""
                local check_count=0
                while [ $check_count -lt 5 ]; do
                    sleep 1
                    gateway_pid=$(get_gateway_pid)
                    if [ -n "$gateway_pid" ]; then
                        break
                    fi
                    check_count=$((check_count + 1))
                done
                
                # 最终检测：只要端口有服务就是成功（无论是刚启动的还是之前已运行的）
                if [ -n "$gateway_pid" ]; then
                    log_info "服务运行中 (PID: $gateway_pid)"
                    echo ""
                    
                    # 获取并显示 Dashboard URL（带 token）
                    echo -e "${CYAN}━━━ 获取 Dashboard URL ━━━${NC}"
                    local dashboard_url=$(openclaw dashboard --no-open 2>/dev/null | grep -E "^https?://" | head -1)
                    if [ -n "$dashboard_url" ]; then
                        echo ""
                        echo -e "${GREEN}✓ Dashboard URL (带授权 token):${NC}"
                        echo -e "  ${WHITE}$dashboard_url${NC}"
                        echo ""
                        echo -e "${YELLOW}⚠️  请使用此 URL 访问控制界面${NC}"
                    else
                        echo ""
                        echo -e "${YELLOW}提示: 运行以下命令获取带 token 的 Dashboard URL:${NC}"
                        echo -e "  ${WHITE}openclaw dashboard${NC}"
                    fi
                    
                    echo ""
                    echo -e "${CYAN}日志文件: /tmp/openclaw-gateway.log${NC}"
                    # 显示最近的日志
                    if [ -s /tmp/openclaw-gateway.log ]; then
                        echo ""
                        echo -e "${GRAY}最近日志:${NC}"
                        tail -5 /tmp/openclaw-gateway.log 2>/dev/null | sed 's/^/  /'
                    fi
                else
                    log_error "启动失败，端口 ${port} 无服务监听"
                    echo ""
                    
                    # 显示日志文件内容
                    if [ -s /tmp/openclaw-gateway.log ]; then
                        echo -e "${YELLOW}错误日志:${NC}"
                        tail -15 /tmp/openclaw-gateway.log 2>/dev/null | sed 's/^/  /'
                    fi
                    
                    echo ""
                    echo -e "${CYAN}━━━ 诊断信息 ━━━${NC}"
                    echo ""
                    
                    # 运行 doctor 获取配置状态
                    echo -e "${YELLOW}配置检查:${NC}"
                    openclaw doctor 2>&1 | head -15 | sed 's/^/  /'
                    
                    echo ""
                    echo -e "${CYAN}建议:${NC}"
                    echo -e "  1. 运行 ${WHITE}openclaw doctor --fix${NC} 修复配置"
                    echo -e "  2. 运行 ${WHITE}openclaw gateway${NC} 手动启动查看详细错误"
                fi
            else
                log_error "OpenClaw 未安装"
            fi
            ;;
        2)
            echo ""
            log_info "正在停止服务..."
            if check_openclaw_installed; then
                openclaw gateway stop 2>/dev/null || true
                sleep 1
                # 使用端口检测判断服务是否已停止（更可靠）
                local stop_pid
                stop_pid=$(get_gateway_pid)
                if [ -z "$stop_pid" ]; then
                    log_info "服务已停止"
                else
                    log_warn "服务可能仍在运行 (PID: $stop_pid)"
                    echo -e "  运行 ${WHITE}kill $stop_pid${NC} 强制停止"
                fi
            else
                log_error "OpenClaw 未安装"
            fi
            ;;
        3)
            echo ""
            log_info "正在重启服务..."
            if check_openclaw_installed; then
                # 确保配置正确
                ensure_openclaw_init
                
                # 加载环境变量
                if [ -f "$OPENCLAW_ENV" ]; then
                    source "$OPENCLAW_ENV"
                fi
                
                # 使用官方 restart 命令
                local restart_output
                restart_output=$(openclaw gateway restart 2>&1) || true
                local restart_exit=$?
                
                sleep 2
                
                # 使用端口检测判断服务是否启动成功（更可靠）
                local gateway_pid
                gateway_pid=$(get_gateway_pid)
                
                if [ -n "$gateway_pid" ]; then
                    log_info "服务已重启 (PID: $gateway_pid)"
                    echo ""
                    
                    # 获取并显示 Dashboard URL
                    local dashboard_url=$(openclaw dashboard --no-open 2>/dev/null | grep -E "^https?://" | head -1)
                    if [ -n "$dashboard_url" ]; then
                        echo -e "${GREEN}✓ Dashboard URL:${NC}"
                        echo -e "  ${WHITE}$dashboard_url${NC}"
                    else
                        echo -e "${YELLOW}提示: openclaw dashboard 获取访问 URL${NC}"
                    fi
                else
                    log_error "重启失败"
                    echo ""
                    echo -e "${YELLOW}命令输出:${NC}"
                    echo "$restart_output" | head -10 | sed 's/^/  /'
                    echo ""
                    
                    # 尝试多个日志来源
                    echo -e "${YELLOW}诊断信息:${NC}"
                    echo ""
                    
                    # 1. 临时日志
                    if [ -s /tmp/openclaw-gateway.log ]; then
                        echo -e "${CYAN}启动日志:${NC}"
                        tail -10 /tmp/openclaw-gateway.log 2>/dev/null | sed 's/^/  /'
                        echo ""
                    fi
                    
                    # 2. OpenClaw 系统日志
                    echo -e "${CYAN}系统日志 (最近 5 条):${NC}"
                    openclaw logs 2>/dev/null | tail -5 | sed 's/^/  /' || echo "  (无法获取)"
                    echo ""
                    
                    # 3. 检查 doctor 状态
                    echo -e "${CYAN}配置状态:${NC}"
                    openclaw doctor 2>&1 | grep -E "error|warning|✗|⚠" | head -5 | sed 's/^/  /' || echo "  (正常)"
                    echo ""
                    
                    # 4. 建议
                    echo -e "${CYAN}建议:${NC}"
                    echo "  • 运行 ${WHITE}openclaw doctor --fix${NC} 修复配置问题"
                    echo "  • 运行 ${WHITE}openclaw gateway start${NC} 手动启动"
                    echo "  • 查看完整日志: ${WHITE}openclaw logs${NC}"
                fi
            else
                log_error "OpenClaw 未安装"
            fi
            ;;
        4)
            echo ""
            if check_openclaw_installed; then
                openclaw status
            else
                log_error "OpenClaw 未安装"
            fi
            ;;
        5)
            echo ""
            if check_openclaw_installed; then
                echo -e "${CYAN}按 Ctrl+C 退出日志查看${NC}"
                sleep 1
                openclaw logs --follow
            else
                log_error "OpenClaw 未安装"
            fi
            ;;
        6)
            echo ""
            if check_openclaw_installed; then
                openclaw doctor --fix
            else
                log_error "OpenClaw 未安装"
            fi
            ;;
        7)
            echo ""
            if check_openclaw_installed; then
                log_info "正在安装系统服务..."
                openclaw gateway install
                log_info "系统服务已安装"
                echo ""
                echo -e "${CYAN}现在可以使用以下命令管理服务:${NC}"
                echo "  openclaw gateway start"
                echo "  openclaw gateway stop"
                echo "  openclaw gateway restart"
            else
                log_error "OpenClaw 未安装"
            fi
            ;;
        8)
            openclaw_uninstall_menu
            manage_service
            return
            ;;
        9)
            echo ""
            if ! check_openclaw_installed; then
                log_error "OpenClaw 未安装"
                press_enter
                manage_service
                return
            fi

            local current_host current_port new_host new_port
            current_host="$(get_gateway_host)"
            current_port="$(get_gateway_port)"
            echo -e "${CYAN}当前 Gateway 地址: ${WHITE}${current_host}:${current_port}${NC}"
            echo ""

            read_input "${YELLOW}新 Host（默认 ${current_host}）: ${NC}" new_host
            new_host="${new_host:-$current_host}"
            read_input "${YELLOW}新 Port（默认 ${current_port}）: ${NC}" new_port
            new_port="${new_port:-$current_port}"

            if ! is_valid_port "$new_port"; then
                log_error "端口无效: $new_port"
                press_enter
                manage_service
                return
            fi

            openclaw config set gateway.mode local > /dev/null 2>&1 || true
            openclaw config set gateway.host "$new_host" > /dev/null 2>&1 || true
            openclaw config set gateway.port "$new_port" > /dev/null 2>&1 || true
            openclaw config set gateway.bind "$new_host:$new_port" > /dev/null 2>&1 || true
            upsert_env_export "OPENCLAW_GATEWAY_HOST" "$new_host"
            upsert_env_export "OPENCLAW_GATEWAY_PORT" "$new_port"

            log_info "Gateway 地址已更新为 ${new_host}:${new_port}"
            if confirm "是否立即重启 Gateway 使新地址生效？" "y"; then
                restart_gateway_for_channel
            fi
            press_enter
            manage_service
            return
            ;;
        0)
            return
            ;;
    esac
    
    press_enter
    manage_service
}

# 确保 OpenClaw 基础配置正确
ensure_openclaw_init() {
    local OPENCLAW_DIR="$HOME/.openclaw"
    
    # 创建必要的目录
    mkdir -p "$OPENCLAW_DIR/agents/main/sessions" 2>/dev/null || true
    mkdir -p "$OPENCLAW_DIR/agents/main/agent" 2>/dev/null || true
    mkdir -p "$OPENCLAW_DIR/credentials" 2>/dev/null || true
    
    # 修复权限
    chmod 700 "$OPENCLAW_DIR" 2>/dev/null || true
    
    # 确保 gateway.mode 已设置
    local current_mode=$(openclaw config get gateway.mode 2>/dev/null)
    if [ -z "$current_mode" ] || [ "$current_mode" = "undefined" ]; then
        openclaw config set gateway.mode local 2>/dev/null || true
    fi
    
    # 检查 gateway.auth 配置，如果是 token 模式但没有 token，则自动生成
    local auth_mode=$(openclaw config get gateway.auth 2>/dev/null)
    if [ "$auth_mode" = "token" ]; then
        local auth_token=$(openclaw config get gateway.auth.token 2>/dev/null)
        if [ -z "$auth_token" ] || [ "$auth_token" = "undefined" ]; then
            # 自动生成一个随机 token
            local new_token=$(openssl rand -hex 32 2>/dev/null || cat /dev/urandom | head -c 32 | xxd -p 2>/dev/null || date +%s%N | sha256sum | head -c 64)
            openclaw config set gateway.auth.token "$new_token" 2>/dev/null || true
            log_info "已自动生成 Gateway Auth Token"
        fi
    fi
}

# 为 MiniMax 写入官方兼容 provider 配置，避免旧版本出现 Unknown model
ensure_minimax_provider_config() {
    local provider="$1"   # minimax|minimax-cn
    local model="$2"      # MiniMax-M2.5 / MiniMax-M2.5-highspeed
    local config_file="$3"
    local base_url="https://api.minimax.io/anthropic"
    if [ "$provider" = "minimax-cn" ]; then
        base_url="https://api.minimaxi.com/anthropic"
    fi

    mkdir -p "$(dirname "$config_file")" 2>/dev/null || true
    [ -f "$config_file" ] || echo "{}" > "$config_file"

    if command -v node &> /dev/null; then
        node -e "
const fs = require('fs');
const file = '$config_file';
const provider = '$provider';
const model = '$model';
const baseUrl = '$base_url';
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
cfg.models ||= {};
cfg.models.mode ||= 'merge';
cfg.models.providers ||= {};
const p = cfg.models.providers[provider] || {};
const models = Array.isArray(p.models) ? p.models : [];
const catalog = {
  'MiniMax-M2.5': { name: 'MiniMax M2.5' },
  'MiniMax-M2.5-highspeed': { name: 'MiniMax M2.5 Highspeed' },
};
const modelIds = new Set(models.map(m => m.id));
for (const id of ['MiniMax-M2.5', 'MiniMax-M2.5-highspeed']) {
  if (!modelIds.has(id)) {
    models.push({
      id,
      name: (catalog[id] && catalog[id].name) || id,
      reasoning: true,
      input: ['text'],
      cost: { input: 0.3, output: 1.2, cacheRead: 0.03, cacheWrite: 0.12 },
      contextWindow: 200000,
      maxTokens: 8192
    });
  }
}
cfg.models.providers[provider] = {
  ...p,
  baseUrl,
  api: 'anthropic-messages',
  authHeader: true,
  models
};
cfg.agents ||= {};
cfg.agents.defaults ||= {};
cfg.agents.defaults.models ||= {};
const ref = provider + '/' + model;
cfg.agents.defaults.models[ref] = { ...(cfg.agents.defaults.models[ref] || {}), alias: 'Minimax' };
fs.writeFileSync(file, JSON.stringify(cfg, null, 2));
" >/dev/null 2>&1 || true
    elif command -v python3 &> /dev/null; then
        python3 - <<PYEOF
import json, os
file = os.path.expanduser("$config_file")
provider = "$provider"
model = "$model"
base_url = "$base_url"
try:
    with open(file, "r") as f:
        cfg = json.load(f)
except Exception:
    cfg = {}
cfg.setdefault("models", {})
cfg["models"].setdefault("mode", "merge")
cfg["models"].setdefault("providers", {})
p = cfg["models"]["providers"].get(provider, {})
models = p.get("models", []) if isinstance(p.get("models"), list) else []
catalog = {
    "MiniMax-M2.5": "MiniMax M2.5",
    "MiniMax-M2.5-highspeed": "MiniMax M2.5 Highspeed",
}
existing = {m.get("id") for m in models if isinstance(m, dict)}
for mid in ("MiniMax-M2.5", "MiniMax-M2.5-highspeed"):
    if mid not in existing:
        models.append({
            "id": mid, "name": catalog.get(mid, mid), "reasoning": True, "input": ["text"],
            "cost": {"input": 0.3, "output": 1.2, "cacheRead": 0.03, "cacheWrite": 0.12},
            "contextWindow": 200000, "maxTokens": 8192
        })
cfg["models"]["providers"][provider] = {
    **(p if isinstance(p, dict) else {}),
    "baseUrl": base_url,
    "api": "anthropic-messages",
    "authHeader": True,
    "models": models
}
cfg.setdefault("agents", {}).setdefault("defaults", {}).setdefault("models", {})
cfg["agents"]["defaults"]["models"][f"{provider}/{model}"] = {"alias": "Minimax"}
with open(file, "w") as f:
    json.dump(cfg, f, indent=2)
PYEOF
    fi
}

# 保存 AI 配置到 OpenClaw 环境变量
# 参数: provider api_key model base_url [api_type]
save_openclaw_ai_config() {
    local provider="$1"
    local api_key="$2"
    local model="$3"
    local base_url="$4"
    local api_type="$5"  # 可选参数，用于指定 API 类型
    
    ensure_openclaw_init
    
    local env_file="$OPENCLAW_ENV"
    local config_file="$OPENCLAW_JSON"
    
    # 创建或更新环境变量文件
    cat > "$env_file" << EOF
# OpenClaw 环境变量配置
# 由配置菜单自动生成: $(date '+%Y-%m-%d %H:%M:%S')
EOF

    # 根据 provider 设置对应的环境变量
    case "$provider" in
        anthropic)
            echo "export ANTHROPIC_API_KEY=$api_key" >> "$env_file"
            [ -n "$base_url" ] && echo "export ANTHROPIC_BASE_URL=$base_url" >> "$env_file"
            ;;
        openai)
            echo "export OPENAI_API_KEY=$api_key" >> "$env_file"
            [ -n "$base_url" ] && echo "export OPENAI_BASE_URL=$base_url" >> "$env_file"
            ;;
        deepseek)
            echo "export DEEPSEEK_API_KEY=$api_key" >> "$env_file"
            echo "export DEEPSEEK_BASE_URL=${base_url:-https://api.deepseek.com}" >> "$env_file"
            ;;
        moonshot|kimi)
            echo "export MOONSHOT_API_KEY=$api_key" >> "$env_file"
            echo "export MOONSHOT_BASE_URL=${base_url:-https://api.moonshot.ai/v1}" >> "$env_file"
            ;;
        google|google-gemini-cli|google-antigravity)
            echo "export GOOGLE_API_KEY=$api_key" >> "$env_file"
            [ -n "$base_url" ] && echo "export GOOGLE_BASE_URL=$base_url" >> "$env_file"
            ;;
        groq)
            echo "export GROQ_API_KEY=$api_key" >> "$env_file"
            echo "export GROQ_BASE_URL=${base_url:-https://api.groq.com/openai/v1}" >> "$env_file"
            ;;
        mistral)
            echo "export MISTRAL_API_KEY=$api_key" >> "$env_file"
            echo "export MISTRAL_BASE_URL=${base_url:-https://api.mistral.ai/v1}" >> "$env_file"
            ;;
        openrouter)
            echo "export OPENROUTER_API_KEY=$api_key" >> "$env_file"
            echo "export OPENROUTER_BASE_URL=${base_url:-https://openrouter.ai/api/v1}" >> "$env_file"
            ;;
        ollama)
            echo "export OLLAMA_HOST=${base_url:-http://localhost:11434}" >> "$env_file"
            ;;
        xai)
            echo "export XAI_API_KEY=$api_key" >> "$env_file"
            ;;
        zai)
            echo "export ZAI_API_KEY=$api_key" >> "$env_file"
            ;;
        minimax|minimax-cn)
            echo "export MINIMAX_API_KEY=$api_key" >> "$env_file"
            ;;
        opencode|opencode-go)
            echo "export OPENCODE_API_KEY=$api_key" >> "$env_file"
            ;;
        novita)
            echo "export NOVITA_API_KEY=$api_key" >> "$env_file"
            echo "export NOVITA_BASE_URL=https://api.novita.ai/openai" >> "$env_file"
            ;;
    esac

    chmod 600 "$env_file"

    if [ "$provider" = "minimax" ] || [ "$provider" = "minimax-cn" ]; then
        ensure_minimax_provider_config "$provider" "$model" "$config_file"
    fi
    
    # 设置默认模型
    if check_openclaw_installed; then
        local openclaw_model=""
        local use_custom_provider=false
        
        # 如果使用自定义 BASE_URL，需要配置自定义 provider
        if [ -n "$base_url" ] && [ "$provider" = "anthropic" ]; then
            use_custom_provider=true
            configure_custom_provider "$provider" "$api_key" "$model" "$base_url" "$config_file"
            openclaw_model="anthropic-custom/$model"
        elif [ -n "$base_url" ] && [ "$provider" = "openai" ]; then
            use_custom_provider=true
            # 传递 API 类型参数（如果已设置）
            configure_custom_provider "$provider" "$api_key" "$model" "$base_url" "$config_file" "$api_type"
            openclaw_model="openai-custom/$model"
        else
            case "$provider" in
                anthropic)
                    openclaw_model="anthropic/$model"
                    ;;
                openai)
                    openclaw_model="openai/$model"
                    ;;
                groq)
                    openclaw_model="groq/$model"
                    ;;
                mistral)
                    openclaw_model="mistral/$model"
                    ;;
                deepseek)
                    openclaw_model="deepseek/$model"
                    ;;
                moonshot|kimi)
                    openclaw_model="moonshot/$model"
                    ;;
                openrouter)
                    openclaw_model="openrouter/$model"
                    ;;
                google)
                    openclaw_model="google/$model"
                    ;;
                ollama)
                    openclaw_model="ollama/$model"
                    ;;
                xai)
                    openclaw_model="xai/$model"
                    ;;
                zai)
                    openclaw_model="zai/$model"
                    ;;
                minimax)
                    openclaw_model="minimax/$model"
                    ;;
                minimax-cn)
                    openclaw_model="minimax-cn/$model"
                    ;;
                opencode)
                    openclaw_model="opencode/$model"
                    ;;
                opencode-go)
                    openclaw_model="opencode-go/$model"
                    ;;
                google-gemini-cli)
                    openclaw_model="google-gemini-cli/$model"
                    ;;
                google-antigravity)
                    openclaw_model="google-antigravity/$model"
                    ;;
                novita)
                    openclaw_model="novita/$model"
                    ;;
            esac
        fi
        
        if [ -n "$openclaw_model" ]; then
            # 加载环境变量并设置模型
            source "$env_file"
            local set_output=""
            if set_output=$(openclaw models set "$openclaw_model" 2>&1); then
                log_info "OpenClaw 默认模型已设置为: $openclaw_model"
            else
                log_warn "openclaw models set 失败，回退到配置写入"
                echo "$set_output" | head -3 | sed 's/^/  /'
                openclaw config set agents.defaults.model.primary "$openclaw_model" 2>/dev/null || true
                openclaw config set models.default "$openclaw_model" 2>/dev/null || true
            fi
        fi
    fi
    
    # 添加到 shell 配置文件
    local shell_rc=""
    if [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    fi
    
    if [ -n "$shell_rc" ]; then
        if ! grep -q "source.*openclaw/env" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# OpenClaw 环境变量" >> "$shell_rc"
            echo "[ -f \"$env_file\" ] && source \"$env_file\"" >> "$shell_rc"
        fi
    fi
    
    log_info "环境变量已保存到: $env_file"
}

# 配置自定义 provider（用于支持自定义 API 地址）
# 参数: provider api_key model base_url config_file [api_type]
configure_custom_provider() {
    local provider="$1"
    local api_key="$2"
    local model="$3"
    local base_url="$4"
    local config_file="$5"
    local custom_api_type="$6"  # 可选参数，用于覆盖默认 API 类型
    
    # 参数校验
    if [ -z "$model" ]; then
        log_error "模型名称不能为空"
        return 1
    fi
    
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空"
        return 1
    fi
    
    if [ -z "$base_url" ]; then
        log_error "API 地址不能为空"
        return 1
    fi
    
    log_info "配置自定义 Provider..."
    
    # 确保配置目录存在
    local config_dir=$(dirname "$config_file")
    mkdir -p "$config_dir" 2>/dev/null || true
    
    # 确定 API 类型
    # OpenClaw 支持: anthropic-messages, openai-responses, openai-completions
    # 如果传入了自定义 API 类型，使用传入的值；否则根据 provider 自动判断
    local api_type=""
    if [ -n "$custom_api_type" ]; then
        api_type="$custom_api_type"
    elif [ "$provider" = "anthropic" ]; then
        api_type="anthropic-messages"
    else
        api_type="openai-responses"
    fi
    local provider_id="${provider}-custom"
    
    # 先检查是否存在旧的自定义配置，并询问是否清理
    local do_cleanup="false"
    if [ -f "$config_file" ]; then
        # 检查是否有旧的自定义 provider 配置
        local has_old_config="false"
        if grep -q '"anthropic-custom"' "$config_file" 2>/dev/null || \
           grep -q '"openai-custom"' "$config_file" 2>/dev/null; then
            has_old_config="true"
        fi
        
        if [ "$has_old_config" = "true" ]; then
            echo ""
            echo -e "${CYAN}当前已有自定义 Provider 配置:${NC}"
            # 显示当前配置的 provider 和模型
            if command -v node &> /dev/null; then
                node -e "
const fs = require('fs');
try {
    const config = JSON.parse(fs.readFileSync('$config_file', 'utf8'));
    const providers = config.models?.providers || {};
    for (const [id, p] of Object.entries(providers)) {
        if (id.includes('-custom')) {
            console.log('  - Provider: ' + id);
            console.log('    API 地址: ' + p.baseUrl);
            if (p.models?.length) {
                console.log('    模型: ' + p.models.map(m => m.id).join(', '));
            }
        }
    }
} catch (e) {}
" 2>/dev/null
            fi
            echo ""
            echo -e "${YELLOW}是否清理旧的自定义配置？${NC}"
            echo -e "${GRAY}(清理可避免配置累积，推荐选择 Y)${NC}"
            if confirm "清理旧配置？" "y"; then
                do_cleanup="true"
            fi
        fi
    fi
    
    # 使用 node 或 python 来处理 JSON
    local config_success=false
    
    if command -v node &> /dev/null; then
        log_info "使用 node 配置自定义 Provider..."
        
        # 将变量写入临时文件，避免 shell 转义问题
        local tmp_vars="/tmp/openclaw_provider_vars_$$.json"
        cat > "$tmp_vars" << EOFVARS
{
    "config_file": "$config_file",
    "provider_id": "$provider_id",
    "base_url": "$base_url",
    "api_key": "$api_key",
    "model": "$model",
    "api_type": "$api_type",
    "do_cleanup": "$do_cleanup"
}
EOFVARS
        
        node -e "
const fs = require('fs');
const vars = JSON.parse(fs.readFileSync('$tmp_vars', 'utf8'));

let config = {};
try {
    config = JSON.parse(fs.readFileSync(vars.config_file, 'utf8'));
} catch (e) {
    config = {};
}

// 确保 models.providers 结构存在
if (!config.models) config.models = {};
if (!config.models.providers) config.models.providers = {};

// 根据用户选择决定是否清理旧配置
if (vars.do_cleanup === 'true') {
    delete config.models.providers['anthropic-custom'];
    delete config.models.providers['openai-custom'];
    if (config.models.configured) {
        config.models.configured = config.models.configured.filter(m => {
            if (m.startsWith('openai/claude')) return false;
            if (m.startsWith('openrouter/claude') && !m.includes('openrouter.ai')) return false;
            return true;
        });
    }
    if (config.models.aliases) {
        delete config.models.aliases['claude-custom'];
    }
    console.log('Old configurations cleaned up');
}

// 添加自定义 provider
config.models.providers[vars.provider_id] = {
    baseUrl: vars.base_url,
    apiKey: vars.api_key,
    models: [
        {
            id: vars.model,
            name: vars.model,
            api: vars.api_type,
            input: ['text','image'],
            contextWindow: 200000,
            maxTokens: 8192
        }
    ]
};

fs.writeFileSync(vars.config_file, JSON.stringify(config, null, 2));
console.log('Custom provider configured: ' + vars.provider_id);
" 2>&1
        local node_exit=$?
        rm -f "$tmp_vars" 2>/dev/null
        
        if [ $node_exit -eq 0 ]; then
            config_success=true
            log_info "自定义 Provider 已配置: $provider_id"
        else
            log_warn "node 配置失败 (exit: $node_exit)，尝试使用 python3..."
        fi
    fi
    
    # 如果 node 失败或不存在，尝试 python3
    if [ "$config_success" = false ] && command -v python3 &> /dev/null; then
        log_info "使用 python3 配置自定义 Provider..."
        
        # 将变量写入临时文件，避免 shell 转义问题
        local tmp_vars="/tmp/openclaw_provider_vars_$$.json"
        cat > "$tmp_vars" << EOFVARS
{
    "config_file": "$config_file",
    "provider_id": "$provider_id",
    "base_url": "$base_url",
    "api_key": "$api_key",
    "model": "$model",
    "api_type": "$api_type",
    "do_cleanup": "$do_cleanup"
}
EOFVARS
        
        python3 -c "
import json
import os

# 从临时文件读取变量
with open('$tmp_vars', 'r') as f:
    vars = json.load(f)

config = {}
config_file = vars['config_file']
if os.path.exists(config_file):
    try:
        with open(config_file, 'r') as f:
            config = json.load(f)
    except:
        config = {}

if 'models' not in config:
    config['models'] = {}
if 'providers' not in config['models']:
    config['models']['providers'] = {}

# 根据用户选择决定是否清理旧配置
if vars['do_cleanup'] == 'true':
    config['models']['providers'].pop('anthropic-custom', None)
    config['models']['providers'].pop('openai-custom', None)
    if 'configured' in config['models']:
        config['models']['configured'] = [
            m for m in config['models']['configured']
            if not (m.startswith('openai/claude') or 
                    (m.startswith('openrouter/claude') and 'openrouter.ai' not in m))
        ]
    if 'aliases' in config['models']:
        config['models']['aliases'].pop('claude-custom', None)
    print('Old configurations cleaned up')

config['models']['providers'][vars['provider_id']] = {
    'baseUrl': vars['base_url'],
    'apiKey': vars['api_key'],
    'models': [
        {
            'id': vars['model'],
            'name': vars['model'],
            'api': vars['api_type'],
            'input': ['text','image'],
            'contextWindow': 200000,
            'maxTokens': 8192
        }
    ]
}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
print('Custom provider configured: ' + vars['provider_id'])
" 2>&1
        local py_exit=$?
        rm -f "$tmp_vars" 2>/dev/null
        
        if [ $py_exit -eq 0 ]; then
            config_success=true
            log_info "自定义 Provider 已配置: $provider_id"
        else
            log_warn "python3 配置失败 (exit: $py_exit)"
        fi
    fi
    
    if [ "$config_success" = false ]; then
        log_warn "无法配置自定义 Provider（需要 node 或 python3）"
    fi
    
    # 验证配置文件是否正确写入
    if [ -f "$config_file" ]; then
        if grep -q "$provider_id" "$config_file" 2>/dev/null; then
            log_info "配置文件验证通过: $config_file"
        else
            log_warn "配置文件可能未正确写入，请检查: $config_file"
        fi
    fi
}

# ================================ 高级设置 ================================

ensure_auto_fix_openclaw_ready() {
    if ! command -v git &> /dev/null; then
        log_error "未检测到 git，无法同步 auto-fix-openclaw"
        return 1
    fi

    mkdir -p "$(dirname "$AUTO_FIX_OPENCLAW_DIR")"

    if [ -d "$AUTO_FIX_OPENCLAW_DIR/.git" ]; then
        log_info "检测到 auto-fix-openclaw，本地路径: $AUTO_FIX_OPENCLAW_DIR"
        if [ -n "$(git -C "$AUTO_FIX_OPENCLAW_DIR" status --porcelain 2>/dev/null)" ]; then
            log_warn "auto-fix-openclaw 存在本地改动，跳过自动 pull"
        else
            log_info "正在更新 auto-fix-openclaw..."
            git -C "$AUTO_FIX_OPENCLAW_DIR" pull --ff-only > /dev/null 2>&1 || log_warn "自动更新失败，可稍后手动更新"
        fi
    elif [ -d "$AUTO_FIX_OPENCLAW_DIR" ]; then
        log_warn "目录存在但不是 git 仓库: $AUTO_FIX_OPENCLAW_DIR"
    else
        log_info "正在克隆 auto-fix-openclaw..."
        if ! git clone --depth 1 "$AUTO_FIX_OPENCLAW_REPO_URL" "$AUTO_FIX_OPENCLAW_DIR"; then
            log_warn "主仓库克隆失败，尝试镜像源..."
            rm -rf "$AUTO_FIX_OPENCLAW_DIR" 2>/dev/null || true
            if ! git clone --depth 1 "$AUTO_FIX_OPENCLAW_REPO_MIRROR_URL" "$AUTO_FIX_OPENCLAW_DIR"; then
                log_error "克隆失败: $AUTO_FIX_OPENCLAW_REPO_URL"
                log_error "镜像也失败: $AUTO_FIX_OPENCLAW_REPO_MIRROR_URL"
                return 1
            fi
        fi
    fi

    if [ -f "$AUTO_FIX_OPENCLAW_BIN" ] && [ ! -x "$AUTO_FIX_OPENCLAW_BIN" ]; then
        chmod +x "$AUTO_FIX_OPENCLAW_BIN" 2>/dev/null || true
    fi

    if [ ! -x "$AUTO_FIX_OPENCLAW_BIN" ]; then
        log_error "未找到可执行文件: $AUTO_FIX_OPENCLAW_BIN"
        return 1
    fi

    log_info "auto-fix-openclaw 已就绪"
    return 0
}

run_auto_fix_openclaw_cmd() {
    if ! ensure_auto_fix_openclaw_ready; then
        return 1
    fi

    AUTO_FIX_OPENCLAW_CODEX_BIN="${AUTO_FIX_OPENCLAW_CODEX_BIN:-$(command -v codex || true)}" \
    AUTO_FIX_OPENCLAW_CLAUDE_CODE_BIN="${AUTO_FIX_OPENCLAW_CLAUDE_CODE_BIN:-$(command -v claude || command -v claude-code || true)}" \
    "$AUTO_FIX_OPENCLAW_BIN" "$@"
}

check_codex_ready() {
    if ! command -v codex &> /dev/null; then
        log_error "未检测到 codex CLI。请先安装 Codex CLI。"
        echo "  安装后执行: codex login"
        return 1
    fi

    if ! codex login status > /dev/null 2>&1; then
        log_error "Codex CLI 未完成登录配置。"
        echo "  请先执行: codex login"
        return 1
    fi

    return 0
}

run_auto_fix_provider_repair() {
    local provider="$1"

    # AI 修复统一要求：Codex 已安装且已登录（作为主修复/兜底引擎）
    if ! check_codex_ready; then
        return 1
    fi

    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装，无法执行修复"
        return 1
    fi

    case "$provider" in
        codex)
            if ! command -v codex &> /dev/null; then
                log_error "未检测到 codex CLI，请先安装并登录"
                return 1
            fi
            ;;
        claudecode)
            if ! command -v claude &> /dev/null && ! command -v claude-code &> /dev/null; then
                log_error "未检测到 claude CLI，请先安装并登录"
                return 1
            fi
            ;;
    esac

    local force_flag=""
    if confirm "即使当前网关健康也强制执行 AI 修复？" "n"; then
        force_flag="--force"
    fi

    echo ""
    log_info "将自动读取错误日志摘要，并向 ${provider} CLI 发起修复请求..."
    log_info "执行修复: auto-fix-openclaw repair-now --provider $provider"
    if [ -n "$force_flag" ]; then
        run_auto_fix_openclaw_cmd repair-now --provider "$provider" --source installer-menu "$force_flag"
    else
        run_auto_fix_openclaw_cmd repair-now --provider "$provider" --source installer-menu
    fi
}

choose_auto_fix_repair_provider() {
    echo ""
    echo -e "${WHITE}选择修复引擎${NC}"
    print_divider
    print_menu_item "1" "Codex CLI" "🤖"
    print_menu_item "2" "Claude CLI" "🧠"
    print_menu_item "0" "取消" "↩️"
    echo ""
    echo -en "${YELLOW}请选择 [0-2]: ${NC}"
    read provider_choice < "$TTY_INPUT"

    case "$provider_choice" in
        1)
            run_auto_fix_provider_repair codex
            ;;
        2)
            run_auto_fix_provider_repair claudecode
            ;;
        0)
            return 0
            ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac
}

ai_auto_fix_menu() {
    clear_screen
    print_header

    echo -e "${WHITE}🛠️ AI 自动修复 OpenClaw${NC}"
    print_divider
    echo ""
    echo -e "${GRAY}集成 auto-fix-openclaw，可调用 Codex/Claude CLI 执行修复${NC}"
    echo -e "${GRAY}仓库: ${AUTO_FIX_OPENCLAW_REPO_URL}${NC}"
    echo -e "${GRAY}路径: ${AUTO_FIX_OPENCLAW_DIR}${NC}"
    echo -e "${YELLOW}前置要求: 已安装并配置 Codex CLI（codex login）。${NC}"
    echo -e "${GRAY}执行 AI 修复时会自动读取错误日志摘要并发送修复请求。${NC}"
    echo ""

    print_menu_item "1" "同步/安装 auto-fix-openclaw" "📦"
    print_menu_item "2" "查看 auto-fix 状态" "📊"
    print_menu_item "3" "采集诊断 (doctor-dry-run)" "🧪"
    print_menu_item "4" "执行单次巡检 (run-once)" "🔁"
    print_menu_item "5" "执行 AI 修复（选择 Claude/Codex）" "🛠️"
    print_menu_item "0" "返回上级菜单" "↩️"
    echo ""

    echo -en "${YELLOW}请选择 [0-5]: ${NC}"
    read choice < "$TTY_INPUT"

    case "$choice" in
        1)
            ensure_auto_fix_openclaw_ready
            ;;
        2)
            run_auto_fix_openclaw_cmd status
            ;;
        3)
            run_auto_fix_openclaw_cmd doctor-dry-run
            ;;
        4)
            run_auto_fix_openclaw_cmd run-once --source installer-menu
            ;;
        5)
            choose_auto_fix_repair_provider
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            ;;
    esac

    press_enter
    ai_auto_fix_menu
}

backup_runtime_config_for_upgrade() {
    local backup_root="$HOME/.openclaw-upgrade-backups"
    mkdir -p "$backup_root"
    local backup_path="$backup_root/pre_upgrade_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_path"
    
    if [ -d "$CONFIG_DIR" ]; then
        cp -R "$CONFIG_DIR" "$backup_path/config_snapshot" 2>/dev/null || {
            log_error "创建升级备份失败"
            return 1
        }
    fi
    
    echo "$backup_path"
    return 0
}

restore_runtime_config_backup() {
    local backup_path="$1"
    if [ -z "$backup_path" ] || [ ! -d "$backup_path" ]; then
        log_error "备份目录无效，无法恢复"
        return 1
    fi
    if [ ! -d "$backup_path/config_snapshot" ]; then
        log_error "备份快照不存在，无法恢复: $backup_path/config_snapshot"
        return 1
    fi
    
    mkdir -p "$CONFIG_DIR"
    cp -R "$backup_path/config_snapshot/." "$CONFIG_DIR/" 2>/dev/null || {
        log_error "恢复配置备份失败: $backup_path"
        return 1
    }
    
    log_info "已恢复配置备份: $backup_path"
    return 0
}

run_openclaw_upgrade_pipeline() {
    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装"
        return 1
    fi
    
    local before_version
    before_version=$(openclaw --version 2>/dev/null || echo "unknown")
    log_info "当前版本: $before_version"
    
    local upgrade_log="$BACKUP_DIR/upgrade_$(date +%Y%m%d_%H%M%S).log"
    mkdir -p "$BACKUP_DIR"
    {
        echo "=== OpenClaw Upgrade Log ==="
        echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Before Version: $before_version"
    } >> "$upgrade_log"
    
    local backup_path
    backup_path=$(backup_runtime_config_for_upgrade) || return 1
    log_info "升级备份: $backup_path"
    echo "Backup Path: $backup_path" >> "$upgrade_log"
    
    local update_output=""
    local updated=false
    
    # 官方推荐升级命令
    if update_output=$(openclaw update --restart 2>&1); then
        updated=true
        log_info "OpenClaw 核心升级成功（openclaw update --restart）"
        {
            echo ""
            echo "[core-update] openclaw update --restart"
            echo "$update_output"
        } >> "$upgrade_log"
    else
        log_warn "openclaw update --restart 失败，尝试 npm 回退升级"
        echo "$update_output" | head -8 | sed 's/^/  /'
        {
            echo ""
            echo "[core-update-failed] openclaw update --restart"
            echo "$update_output"
        } >> "$upgrade_log"
        
        if update_output=$(npm update -g openclaw 2>&1); then
            updated=true
            log_warn "已使用 npm update -g openclaw 完成回退升级"
            {
                echo ""
                echo "[core-update-fallback] npm update -g openclaw"
                echo "$update_output"
            } >> "$upgrade_log"
        else
            log_error "核心升级失败"
            echo "$update_output" | head -8 | sed 's/^/  /'
            {
                echo ""
                echo "[core-update-fallback-failed] npm update -g openclaw"
                echo "$update_output"
            } >> "$upgrade_log"
            restore_runtime_config_backup "$backup_path" || true
            return 1
        fi
    fi
    
    if [ "$updated" != true ]; then
        log_error "升级状态未知，已中止"
        restore_runtime_config_backup "$backup_path" || true
        return 1
    fi
    
    # 升级后按官方链路执行 doctor
    log_info "运行 doctor 迁移与修复..."
    local doctor_output=""
    if openclaw doctor --help 2>/dev/null | grep -q -- "--non-interactive"; then
        if ! doctor_output=$(openclaw doctor --non-interactive 2>&1); then
            log_error "doctor 失败"
            {
                echo ""
                echo "[doctor-failed] openclaw doctor --non-interactive"
                echo "$doctor_output"
            } >> "$upgrade_log"
            restore_runtime_config_backup "$backup_path" || true
            return 1
        fi
        {
            echo ""
            echo "[doctor] openclaw doctor --non-interactive"
            echo "$doctor_output"
        } >> "$upgrade_log"
    else
        if ! doctor_output=$(yes | openclaw doctor --fix 2>&1); then
            log_error "doctor --fix 失败"
            {
                echo ""
                echo "[doctor-failed] yes | openclaw doctor --fix"
                echo "$doctor_output"
            } >> "$upgrade_log"
            restore_runtime_config_backup "$backup_path" || true
            return 1
        fi
        {
            echo ""
            echo "[doctor] yes | openclaw doctor --fix"
            echo "$doctor_output"
        } >> "$upgrade_log"
    fi
    
    # 升级后统一更新插件
    log_info "更新插件..."
    local plugins_output=""
    if ! plugins_output=$(openclaw plugins update --all 2>&1); then
        log_warn "plugins update --all 执行失败，请稍后手动执行"
        {
            echo ""
            echo "[plugins-update-failed] openclaw plugins update --all"
            echo "$plugins_output"
        } >> "$upgrade_log"
    else
        {
            echo ""
            echo "[plugins-update] openclaw plugins update --all"
            echo "$plugins_output"
        } >> "$upgrade_log"
    fi
    
    # 健康检查
    if openclaw health >/dev/null 2>&1; then
        log_info "健康检查通过"
    else
        log_warn "健康检查未通过，请运行 openclaw health / openclaw logs 排查"
    fi
    
    local after_version
    after_version=$(openclaw --version 2>/dev/null || echo "unknown")
    log_info "升级完成: $before_version -> $after_version"
    {
        echo ""
        echo "After Version: $after_version"
        echo "Result: success"
    } >> "$upgrade_log"
    log_info "升级日志: $upgrade_log"
    return 0
}

advanced_settings() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔧 高级设置${NC}"
    print_divider
    echo ""
    
    print_menu_item "1" "编辑环境变量" "📝"
    print_menu_item "2" "备份配置" "💾"
    print_menu_item "3" "恢复配置" "📥"
    print_menu_item "4" "重置配置" "🔄"
    print_menu_item "5" "清理日志" "🧹"
    print_menu_item "6" "更新 OpenClaw" "⬆️"
    print_menu_item "7" "卸载 OpenClaw" "🗑️"
    print_menu_item "8" "AI 自动修复 OpenClaw" "🛠️"
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    echo -en "${YELLOW}请选择 [0-8]: ${NC}"
    read choice < "$TTY_INPUT"
    
    case $choice in
        1)
            echo ""
            log_info "正在打开环境变量配置..."
            if [ -f "$OPENCLAW_ENV" ]; then
                if [ -n "$EDITOR" ]; then
                    $EDITOR "$OPENCLAW_ENV"
                elif command -v nano &> /dev/null; then
                    nano "$OPENCLAW_ENV"
                elif command -v vim &> /dev/null; then
                    vim "$OPENCLAW_ENV"
                else
                    cat "$OPENCLAW_ENV"
                fi
            else
                log_error "环境变量文件不存在: $OPENCLAW_ENV"
            fi
            ;;
        2)
            echo ""
            local backup_file=$(backup_config)
            if [ -n "$backup_file" ]; then
                log_info "配置已备份到: $backup_file"
            else
                log_error "备份失败"
            fi
            ;;
        3)
            restore_config
            ;;
        4)
            if confirm "确定要重置所有配置吗？这将删除当前配置" "n"; then
                rm -f "$OPENCLAW_ENV"
                rm -rf "$CONFIG_DIR/openclaw.json" 2>/dev/null
                log_info "配置已重置，请重新运行安装脚本"
            fi
            ;;
        5)
            if confirm "确定要清理日志吗？" "n"; then
                if check_openclaw_installed; then
                    openclaw logs clear 2>/dev/null || log_warn "OpenClaw 日志清理命令不可用"
                fi
                rm -f /tmp/openclaw-gateway.log 2>/dev/null
                log_info "日志已清理"
            fi
            ;;
        6)
            echo ""
            log_info "正在执行官方升级链路（core + doctor + plugins）..."
            run_openclaw_upgrade_pipeline
            ;;
        7)
            openclaw_uninstall_menu
            advanced_settings
            return
            ;;
        8)
            ai_auto_fix_menu
            ;;
        0)
            return
            ;;
    esac
    
    press_enter
    advanced_settings
}

restore_config() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📥 恢复配置${NC}"
    print_divider
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        log_error "没有找到备份文件"
        return
    fi
    
    echo -e "${CYAN}可用备份:${NC}"
    echo ""
    
    local i=1
    local backups=()
    for file in "$BACKUP_DIR"/*.bak; do
        if [ -f "$file" ]; then
            backups+=("$file")
            local filename=$(basename "$file")
            local date_str=$(echo "$filename" | grep -oE '[0-9]{8}_[0-9]{6}')
            echo "  [$i] $date_str - $filename"
            ((i++))
        fi
    done
    
    echo ""
    read -p "$(echo -e "${YELLOW}选择要恢复的备份 [1-$((i-1))]: ${NC}")" choice
    
    if [ -n "$choice" ] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
        local selected_backup="${backups[$((choice-1))]}"
        cp "$selected_backup" "$OPENCLAW_ENV"
        source "$OPENCLAW_ENV"
        log_info "环境配置已从备份恢复"
    else
        log_error "无效选择"
    fi
}

# ================================ 查看配置 ================================

view_config() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📋 当前配置${NC}"
    print_divider
    echo ""
    
    # 显示环境变量配置
    echo -e "${CYAN}环境变量配置 ($OPENCLAW_ENV):${NC}"
    echo ""
    if [ -f "$OPENCLAW_ENV" ]; then
        if command -v bat &> /dev/null; then
            bat --style=numbers --language=bash "$OPENCLAW_ENV"
        else
            cat -n "$OPENCLAW_ENV"
        fi
    else
        echo -e "  ${GRAY}(未配置)${NC}"
    fi
    
    echo ""
    print_divider
    echo ""
    
    # 显示 OpenClaw 配置
    if check_openclaw_installed; then
        echo -e "${CYAN}OpenClaw 配置:${NC}"
        echo ""
        openclaw config list 2>/dev/null || echo -e "  ${GRAY}(无法获取)${NC}"
        echo ""
        
        echo -e "${CYAN}已配置渠道:${NC}"
        echo ""
        openclaw channels list 2>/dev/null || echo -e "  ${GRAY}(无渠道)${NC}"
        echo ""
        
        echo -e "${CYAN}当前模型:${NC}"
        echo ""
        openclaw models status 2>/dev/null || echo -e "  ${GRAY}(未配置)${NC}"
    fi
    
    echo ""
    print_divider
    press_enter
}

# ================================ 快速测试 ================================

quick_test_menu() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🧪 快速测试${NC}"
    print_divider
    echo ""
    
    # 显示 OpenClaw 状态
    if check_openclaw_installed; then
        local version=$(openclaw --version 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}✓${NC} OpenClaw 已安装: $version"
    else
        echo -e "  ${YELLOW}⚠${NC} OpenClaw 未安装"
    fi
    echo ""
    print_divider
    echo ""
    
    echo -e "${CYAN}API 连接测试:${NC}"
    print_menu_item "1" "测试 AI API 连接" "🤖"
    print_menu_item "2" "测试 Telegram 机器人" "📨"
    print_menu_item "3" "测试 Discord 机器人" "🎮"
    print_menu_item "4" "测试 Slack 机器人" "💼"
    print_menu_item "5" "测试飞书机器人" "🔷"
    print_menu_item "6" "测试 Ollama 本地模型" "🟠"
    echo ""
    echo -e "${CYAN}OpenClaw 诊断 (需要已安装):${NC}"
    print_menu_item "7" "openclaw doctor (诊断)" "🔍"
    print_menu_item "8" "openclaw status (渠道状态)" "📊"
    print_menu_item "9" "openclaw health (Gateway 健康)" "💚"
    echo ""
    print_menu_item "a" "运行全部 API 测试" "🔄"
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    echo -en "${YELLOW}请选择 [0-9/a]: ${NC}"
    read choice < "$TTY_INPUT"
    
    case $choice in
        1) quick_test_ai ;;
        2) quick_test_telegram ;;
        3) quick_test_discord ;;
        4) quick_test_slack ;;
        5) quick_test_feishu ;;
        6) quick_test_ollama ;;
        7) quick_test_doctor ;;
        8) quick_test_status ;;
        9) quick_test_health ;;
        a|A) run_all_tests ;;
        0) return ;;
        *) log_error "无效选择"; press_enter; quick_test_menu ;;
    esac
}

quick_test_ai() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🤖 测试 AI API 连接${NC}"
    print_divider
    echo ""

    if ! check_openclaw_installed; then
        log_error "OpenClaw 未安装"
        press_enter
        quick_test_menu
        return
    fi
    
    # 读取环境变量（如果存在）
    [ -f "$OPENCLAW_ENV" ] && source "$OPENCLAW_ENV"
    
    local provider=""
    local api_key=""
    local base_url=""
    local model=""
    
    local model_ref=""
    model_ref="$(get_current_model_ref || true)"
    if [ -z "$model_ref" ]; then
        log_error "未检测到已生效默认模型，请先完成模型配置"
        press_enter
        quick_test_menu
        return
    fi

    provider="${model_ref%%/*}"
    model="${model_ref#*/}"

    # 按 provider 尝试读取对应 key（若为空也允许，因为可能使用 auth profile）
    case "$provider" in
        anthropic) api_key="$ANTHROPIC_API_KEY"; base_url="$ANTHROPIC_BASE_URL" ;;
        openai) api_key="$OPENAI_API_KEY"; base_url="$OPENAI_BASE_URL" ;;
        deepseek) api_key="$DEEPSEEK_API_KEY"; base_url="$DEEPSEEK_BASE_URL" ;;
        moonshot|kimi) api_key="$MOONSHOT_API_KEY"; base_url="$MOONSHOT_BASE_URL" ;;
        google|google-gemini-cli|google-antigravity) api_key="$GOOGLE_API_KEY"; base_url="$GOOGLE_BASE_URL" ;;
        openrouter) api_key="$OPENROUTER_API_KEY"; base_url="$OPENROUTER_BASE_URL" ;;
        groq) api_key="$GROQ_API_KEY"; base_url="$GROQ_BASE_URL" ;;
        mistral) api_key="$MISTRAL_API_KEY"; base_url="$MISTRAL_BASE_URL" ;;
        xai) api_key="$XAI_API_KEY" ;;
        zai) api_key="$ZAI_API_KEY" ;;
        minimax|minimax-cn|minimax-portal) api_key="$MINIMAX_API_KEY" ;;
        opencode|opencode-zen|opencode-go) api_key="$OPENCODE_API_KEY" ;;
        ollama|lmstudio) api_key="local-runtime" ;;
    esac
    
    echo -e "当前配置:"
    echo -e "  提供商: ${WHITE}$provider${NC}"
    echo -e "  模型: ${WHITE}${model:-未知}${NC}"
    [ -n "$base_url" ] && echo -e "  API 地址: ${WHITE}$base_url${NC}"
    
    test_ai_connection "$provider" "$api_key" "$model" "$base_url"
    
    press_enter
    quick_test_menu
}

quick_test_telegram() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📨 测试 Telegram 机器人${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}请输入 Telegram Bot Token 和 User ID 进行测试:${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}Bot Token: ${NC}")" token
    read -p "$(echo -e "${YELLOW}User ID: ${NC}")" user_id
    
    if [ -z "$token" ]; then
        log_error "Token 不能为空"
        press_enter
        quick_test_menu
        return
    fi
    
    test_telegram_bot "$token" "$user_id"
    
    press_enter
    quick_test_menu
}

quick_test_discord() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🎮 测试 Discord 机器人${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}请输入 Discord Bot Token 和 Channel ID 进行测试:${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}Bot Token: ${NC}")" token
    read -p "$(echo -e "${YELLOW}Channel ID: ${NC}")" channel_id
    
    if [ -z "$token" ]; then
        log_error "Token 不能为空"
        press_enter
        quick_test_menu
        return
    fi
    
    test_discord_bot "$token" "$channel_id"
    
    press_enter
    quick_test_menu
}

quick_test_slack() {
    clear_screen
    print_header
    
    echo -e "${WHITE}💼 测试 Slack 机器人${NC}"
    print_divider
    echo ""
    
    echo -e "${CYAN}请输入 Slack Bot Token 进行测试:${NC}"
    echo ""
    
    read_secret_input "${YELLOW}Bot Token (xoxb-...): ${NC}" bot_token
    
    if [ -z "$bot_token" ]; then
        log_error "Token 不能为空"
        press_enter
        quick_test_menu
        return
    fi
    
    test_slack_bot "$bot_token"
    
    press_enter
    quick_test_menu
}

quick_test_feishu() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔷 测试飞书机器人${NC}"
    print_divider
    echo ""
    
    local app_id=""
    local app_secret=""
    
    # 尝试从 JSON 配置文件中读取
    if [ -f "$OPENCLAW_JSON" ]; then
        if command -v node &> /dev/null; then
            app_id=$(node -e "
try {
    const config = JSON.parse(require('fs').readFileSync('$OPENCLAW_JSON', 'utf8'));
    console.log(config.channels?.feishu?.accounts?.main?.appId || config.channels?.feishu?.appId || '');
} catch (e) { console.log(''); }
" 2>/dev/null)
            app_secret=$(node -e "
try {
    const config = JSON.parse(require('fs').readFileSync('$OPENCLAW_JSON', 'utf8'));
    console.log(config.channels?.feishu?.accounts?.main?.appSecret || config.channels?.feishu?.appSecret || '');
} catch (e) { console.log(''); }
" 2>/dev/null)
        elif command -v python3 &> /dev/null; then
            app_id=$(python3 -c "
import json
try:
    with open('$OPENCLAW_JSON', 'r') as f:
        config = json.load(f)
    feishu = config.get('channels', {}).get('feishu', {})
    print(feishu.get('accounts', {}).get('main', {}).get('appId', feishu.get('appId', '')))
except: print('')
" 2>/dev/null)
            app_secret=$(python3 -c "
import json
try:
    with open('$OPENCLAW_JSON', 'r') as f:
        config = json.load(f)
    feishu = config.get('channels', {}).get('feishu', {})
    print(feishu.get('accounts', {}).get('main', {}).get('appSecret', feishu.get('appSecret', '')))
except: print('')
" 2>/dev/null)
        fi
    fi
    
    if [ -n "$app_id" ] && [ -n "$app_secret" ]; then
        echo -e "${GREEN}✓ 检测到已配置的飞书应用${NC}"
        echo -e "  App ID: ${WHITE}${app_id:0:15}...${NC}"
        echo ""
    else
        echo -e "${YELLOW}未检测到飞书配置，请手动输入:${NC}"
        echo ""
        echo -en "${YELLOW}App ID: ${NC}"
        read app_id < "$TTY_INPUT"
            read_secret_input "${YELLOW}App Secret: ${NC}" app_secret
        
        if [ -z "$app_id" ] || [ -z "$app_secret" ]; then
            log_error "App ID 和 App Secret 不能为空"
            press_enter
            quick_test_menu
            return
        fi
    fi
    
    echo ""
    echo -e "${CYAN}如需发送测试消息，请输入群组 Chat ID（留空跳过）:${NC}"
    echo -e "${GRAY}获取方式: 群设置 → 群信息 → 群号${NC}"
    echo ""
    echo -en "${YELLOW}Chat ID (可选): ${NC}"
    read chat_id < "$TTY_INPUT"
    
    test_feishu_bot "$app_id" "$app_secret" "$chat_id"
    
    press_enter
    quick_test_menu
}

quick_test_ollama() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🟠 测试 Ollama 连接${NC}"
    print_divider
    echo ""
    
    # 从环境变量读取或使用默认值
    local base_url="${OLLAMA_HOST:-http://localhost:11434}"
    local model="llama3"
    
    read -p "$(echo -e "${YELLOW}Ollama 地址 (默认: $base_url): ${NC}")" input_url
    [ -n "$input_url" ] && base_url="$input_url"
    
    read -p "$(echo -e "${YELLOW}模型名称 (默认: $model): ${NC}")" input_model
    [ -n "$input_model" ] && model="$input_model"
    
    test_ollama_connection "$base_url" "$model"
    
    press_enter
    quick_test_menu
}

quick_test_doctor() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔍 OpenClaw 诊断${NC}"
    print_divider
    
    run_openclaw_doctor
    
    press_enter
    quick_test_menu
}

quick_test_status() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📊 OpenClaw 渠道状态${NC}"
    print_divider
    
    run_openclaw_status
    
    press_enter
    quick_test_menu
}

quick_test_health() {
    clear_screen
    print_header
    
    echo -e "${WHITE}💚 Gateway 健康检查${NC}"
    print_divider
    
    run_openclaw_health
    
    press_enter
    quick_test_menu
}

run_all_tests() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔄 运行全部 API 测试${NC}"
    print_divider
    echo ""
    
    echo -e "${YELLOW}正在测试已配置的服务...${NC}"
    echo ""
    
    local total_tests=0
    local passed_tests=0
    
    # 从环境变量读取 AI 配置
    [ -f "$OPENCLAW_ENV" ] && source "$OPENCLAW_ENV"
    
    local provider=""
    local api_key=""
    local base_url=""
    local model=""
    local model_ref=""

    if check_openclaw_installed; then
        model_ref="$(get_current_model_ref || true)"
    fi
    if [ -n "$model_ref" ]; then
        provider="${model_ref%%/*}"
        model="${model_ref#*/}"
    fi

    case "$provider" in
        anthropic) api_key="$ANTHROPIC_API_KEY"; base_url="$ANTHROPIC_BASE_URL" ;;
        openai) api_key="$OPENAI_API_KEY"; base_url="$OPENAI_BASE_URL" ;;
        deepseek) api_key="$DEEPSEEK_API_KEY"; base_url="$DEEPSEEK_BASE_URL" ;;
        moonshot|kimi) api_key="$MOONSHOT_API_KEY"; base_url="$MOONSHOT_BASE_URL" ;;
        google|google-gemini-cli|google-antigravity) api_key="$GOOGLE_API_KEY"; base_url="$GOOGLE_BASE_URL" ;;
        openrouter) api_key="$OPENROUTER_API_KEY"; base_url="$OPENROUTER_BASE_URL" ;;
        groq) api_key="$GROQ_API_KEY"; base_url="$GROQ_BASE_URL" ;;
        mistral) api_key="$MISTRAL_API_KEY"; base_url="$MISTRAL_BASE_URL" ;;
        xai) api_key="$XAI_API_KEY" ;;
        zai) api_key="$ZAI_API_KEY" ;;
        minimax|minimax-cn|minimax-portal) api_key="$MINIMAX_API_KEY" ;;
        opencode|opencode-go|opencode-zen) api_key="$OPENCODE_API_KEY" ;;
        ollama|lmstudio) api_key="local-runtime" ;;
    esac
    
    if [ -n "$provider" ]; then
        total_tests=$((total_tests + 1))
        echo -e "${CYAN}[测试 $total_tests] AI API ($provider / $model)${NC}"
        if test_ai_connection "$provider" "$api_key" "$model" "$base_url"; then
            passed_tests=$((passed_tests + 1))
        else
            log_error "AI API 测试失败"
        fi
        echo ""
    else
        log_warn "未检测到默认模型，跳过 AI API 测试"
    fi
    
    # 渠道测试提示
    echo ""
    echo -e "${CYAN}渠道测试:${NC}"
    echo -e "  使用 ${WHITE}快速测试${NC} 菜单手动测试各个渠道"
    echo -e "  或运行 ${WHITE}openclaw channels list${NC} 查看已配置渠道"
    echo ""
    
    # 汇总结果
    echo ""
    print_divider
    echo ""
    echo -e "${WHITE}测试结果汇总:${NC}"
    echo -e "  总测试数: $total_tests"
    echo -e "  通过: ${GREEN}$passed_tests${NC}"
    echo -e "  失败: ${RED}$((total_tests - passed_tests))${NC}"
    
    if [ $passed_tests -eq $total_tests ] && [ $total_tests -gt 0 ]; then
        echo ""
        echo -e "${GREEN}✓ 所有测试通过！${NC}"
    elif [ $total_tests -eq 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠ 没有可测试的配置，请先完成相关配置${NC}"
    fi
    
    # 如果 OpenClaw 已安装，提示可用的诊断命令
    if check_openclaw_installed; then
        echo ""
        echo -e "${CYAN}提示: 可使用以下命令进行更详细的诊断:${NC}"
        echo "  • openclaw doctor  - 健康检查 + 修复建议"
        echo "  • openclaw status  - 渠道状态"
        echo "  • openclaw health  - Gateway 健康状态"
    fi
    
    press_enter
    quick_test_menu
}

# ================================ 主菜单 ================================

show_main_menu() {
    clear_screen
    print_header
    
    echo -e "${WHITE}请选择操作:${NC}"
    echo ""
    
    print_menu_item "1" "系统状态" "📊"
    print_menu_item "2" "AI 模型配置" "🤖"
    print_menu_item "3" "消息渠道配置" "📱"
    print_menu_item "4" "身份与个性配置" "👤"
    print_menu_item "5" "安全设置" "🔒"
    print_menu_item "6" "服务管理" "⚡"
    print_menu_item "7" "快速测试" "🧪"
    print_menu_item "8" "高级设置" "🔧"
    print_menu_item "9" "查看当前配置" "📋"
    echo ""
    print_menu_item "0" "退出" "🚪"
    echo ""
    print_divider
}

main() {
    # 检查依赖
    check_dependencies
    
    # 确保配置目录存在
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$BACKUP_DIR"

    # 快捷模式：安装脚本可直接跳转到指定配置页
    case "${1:-}" in
        --model-only)
            config_ai_model
            echo ""
            echo -e "${CYAN}模型配置流程结束。${NC}"
            exit 0
            ;;
        --channels-only)
            config_channels
            echo ""
            echo -e "${CYAN}消息渠道配置流程结束。${NC}"
            exit 0
            ;;
    esac
    
    # 主循环
    while true; do
        show_main_menu
        echo -en "${YELLOW}请选择 [0-9]: ${NC}"
        if ! read choice < "$TTY_INPUT"; then
            echo ""
            log_error "无法读取输入（TTY 不可用），退出配置菜单。"
            exit 1
        fi
        
        case $choice in
            1) show_status ;;
            2) config_ai_model ;;
            3) config_channels ;;
            4) config_identity ;;
            5) config_security ;;
            6) manage_service ;;
            7) quick_test_menu ;;
            8) advanced_settings ;;
            9) view_config ;;
            0)
                echo ""
                echo -e "${CYAN}再见！🦞${NC}"
                exit 0
                ;;
            *)
                log_error "无效选择"
                press_enter
                ;;
        esac
    done
}

# 执行主函数
main "$@"
