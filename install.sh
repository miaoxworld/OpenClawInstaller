#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   🦞 OpenClaw 一键部署脚本 v1.0.5                                          ║
# ║   🔥 Dasheng Brand: Monkey King's Wrath                                   ║
# ║   智能 AI 助手部署工具 - 支持多平台多模型                                    ║
# ║                                                                           ║
# ║   GitHub: https://github.com/leecyno1/auto-install-Openclaw               ║
# ║   官方文档: https://docs.openclaw.ai                                       ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# 使用方法:
#   curl -fsSL https://raw.githubusercontent.com/leecyno1/auto-install-Openclaw/main/install.sh | bash
#   或本地执行: chmod +x install.sh && ./install.sh
#

set -e

# ================================ TTY 检测 ================================
# 当通过 curl | bash 运行时，stdin 是管道，需要从 /dev/tty 读取用户输入
if [ -t 0 ]; then
    # stdin 是终端
    TTY_INPUT="/dev/stdin"
else
    # stdin 是管道，使用 /dev/tty
    if [ -e /dev/tty ]; then
        TTY_INPUT="/dev/tty"
    else
        TTY_INPUT="/dev/null"
    fi
fi

# ================================ 颜色定义 ================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # 无颜色

# ================================ 配置变量 ================================
# 兼容旧环境变量命名（clawdbot -> openclaw）
map_legacy_env() {
    local new_key="$1"
    local legacy_key="$2"
    if [ -z "${!new_key:-}" ] && [ -n "${!legacy_key:-}" ]; then
        export "$new_key=${!legacy_key}"
    fi
}

map_legacy_env "OPENCLAW_NO_ONBOARD" "CLAWDBOT_NO_ONBOARD"
map_legacy_env "OPENCLAW_NO_PROMPT" "CLAWDBOT_NO_PROMPT"
map_legacy_env "OPENCLAW_DRY_RUN" "CLAWDBOT_DRY_RUN"
map_legacy_env "OPENCLAW_INSTALL_METHOD" "CLAWDBOT_INSTALL_METHOD"
map_legacy_env "OPENCLAW_VERSION" "CLAWDBOT_VERSION"
map_legacy_env "OPENCLAW_BETA" "CLAWDBOT_BETA"
map_legacy_env "OPENCLAW_GIT_DIR" "CLAWDBOT_GIT_DIR"
map_legacy_env "OPENCLAW_GIT_UPDATE" "CLAWDBOT_GIT_UPDATE"
map_legacy_env "OPENCLAW_VERBOSE" "CLAWDBOT_VERBOSE"

OPENCLAW_VERSION="${OPENCLAW_VERSION:-latest}"
CONFIG_DIR="$HOME/.openclaw"
MIN_NODE_MAJOR=22
MIN_NODE_MINOR=12
INSTALLER_NAME="auto-install-Openclaw"
INSTALLER_VERSION="1.0.5"
BRAND_NAME="Monkey King's Wrath"
BRAND_CN_NAME="大圣引擎"
GITHUB_REPO="${GITHUB_REPO:-leecyno1/auto-install-Openclaw}"
GITHUB_RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main"
OFFICIAL_INSTALL_URL="https://openclaw.ai/install.sh"
OFFICIAL_DOCS_URL="https://docs.openclaw.ai"
INSTALLER_MIRROR_RAW_URL="${OPENCLAW_INSTALLER_MIRROR_RAW_URL:-https://mirror.ghproxy.com/${GITHUB_RAW_URL}}"
OFFICIAL_INSTALL_MIRROR_URL="${OPENCLAW_OFFICIAL_INSTALL_MIRROR_URL:-}"
CURL_CONNECT_TIMEOUT="${OPENCLAW_CURL_CONNECT_TIMEOUT:-8}"
CURL_MAX_TIME="${OPENCLAW_CURL_MAX_TIME:-30}"

NO_ONBOARD="${OPENCLAW_NO_ONBOARD:-0}"
NO_PROMPT="${OPENCLAW_NO_PROMPT:-0}"
DRY_RUN="${OPENCLAW_DRY_RUN:-0}"
VERBOSE="${OPENCLAW_VERBOSE:-0}"
INSTALL_METHOD="${OPENCLAW_INSTALL_METHOD:-npm}"
USE_BETA="${OPENCLAW_BETA:-0}"
GIT_DIR="${OPENCLAW_GIT_DIR:-$HOME/openclaw}"
GIT_UPDATE="${OPENCLAW_GIT_UPDATE:-1}"
HELP=0

# ================================ 工具函数 ================================

print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                    OpenClaw Installer / Config                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo "🔥 大圣之怒傻瓜Openclaw安装/维护助手 🔥 🔖 Version: v${INSTALLER_VERSION}"
    echo -e "${NC}"
}

print_exit_hint() {
    local exit_code="${1:-0}"
    echo ""
    if [ "$exit_code" -eq 0 ]; then
        echo -e "${GREEN}安装脚本执行结束。${NC}"
    else
        echo -e "${YELLOW}安装脚本提前退出（状态码: ${exit_code}）。${NC}"
    fi
    echo -e "${CYAN}后续可执行命令:${NC}"
    echo "  source ~/.openclaw/env && openclaw doctor"
    echo "  source ~/.openclaw/env && openclaw models status --probe --check"
    echo "  bash ~/.openclaw/config-menu.sh  # 或 bash ./config-menu.sh"
    echo ""
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

download_with_fallback() {
    local output_path="$1"
    shift
    local url=""
    for url in "$@"; do
        [ -z "$url" ] && continue
        if curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_MAX_TIME" "$url" -o "$output_path"; then
            log_info "下载成功: $url"
            return 0
        fi
        log_warn "下载失败: $url"
    done
    return 1
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

print_usage() {
    cat <<EOF
${INSTALLER_NAME} (OpenClaw 安装增强版)

用法:
  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash -s -- [选项]

选项:
  --install-method, --method npm|git   安装方式 (默认: npm)
  --npm                                等价于 --install-method npm
  --git, --github                      等价于 --install-method git
  --version <version|dist-tag>         指定 OpenClaw 版本 (默认: latest)
  --beta                               优先使用 beta dist-tag
  --git-dir, --dir <path>              git 安装目录 (默认: ~/openclaw)
  --no-git-update                      禁止更新已有 git checkout
  --no-onboard                         跳过本脚本 AI 初始化向导
  --onboard                            强制执行本脚本 AI 初始化向导
  --no-prompt                          非交互模式（使用默认值）
  --dry-run                            只显示执行计划，不做变更
  --verbose                            详细日志
  --help, -h                           显示帮助

环境变量:
  OPENCLAW_INSTALL_METHOD=git|npm
  OPENCLAW_VERSION=latest|next|<semver>
  OPENCLAW_BETA=0|1
  OPENCLAW_GIT_DIR=<path>
  OPENCLAW_GIT_UPDATE=0|1
  OPENCLAW_NO_ONBOARD=0|1
  OPENCLAW_NO_PROMPT=0|1
  OPENCLAW_DRY_RUN=0|1
  OPENCLAW_VERBOSE=0|1
  OPENCLAW_INSTALLER_MIRROR_RAW_URL=<mirror_raw_url>
  OPENCLAW_OFFICIAL_INSTALL_MIRROR_URL=<mirror_install_sh_url>
  OPENCLAW_CURL_CONNECT_TIMEOUT=<seconds>
  OPENCLAW_CURL_MAX_TIME=<seconds>
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --install-method|--method)
                INSTALL_METHOD="$2"
                shift 2
                ;;
            --npm)
                INSTALL_METHOD="npm"
                shift
                ;;
            --git|--github)
                INSTALL_METHOD="git"
                shift
                ;;
            --version)
                OPENCLAW_VERSION="$2"
                shift 2
                ;;
            --beta)
                USE_BETA=1
                shift
                ;;
            --git-dir|--dir)
                GIT_DIR="$2"
                shift 2
                ;;
            --no-git-update)
                GIT_UPDATE=0
                shift
                ;;
            --no-onboard)
                NO_ONBOARD=1
                shift
                ;;
            --onboard)
                NO_ONBOARD=0
                shift
                ;;
            --no-prompt)
                NO_PROMPT=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --help|-h)
                HELP=1
                shift
                ;;
            *)
                echo "忽略未知参数: $1"
                shift
                ;;
        esac
    done
}

# 从 TTY 读取用户输入（支持 curl | bash 模式）
read_input() {
    local prompt="$1"
    local var_name="$2"
    echo -en "$prompt"
    read $var_name < "$TTY_INPUT"
}

# 从 TTY 读取敏感输入（默认不回显）
read_secret_input() {
    local prompt="$1"
    local var_name="$2"
    echo -e "${GRAY}（自动隐藏，直接粘贴后回车即可）${NC}"
    echo -en "$prompt"
    if stty -echo < "$TTY_INPUT" 2>/dev/null; then
        read $var_name < "$TTY_INPUT"
        stty echo < "$TTY_INPUT" 2>/dev/null || true
    else
        read $var_name < "$TTY_INPUT"
    fi
    echo ""
}

confirm() {
    local message="$1"
    local default="${2:-y}"
    
    if [ "$NO_PROMPT" = "1" ] || [ "$TTY_INPUT" = "/dev/null" ]; then
        [ "$default" = "y" ]
        return $?
    fi

    if [ "$default" = "y" ]; then
        local prompt="[Y/n]"
    else
        local prompt="[y/N]"
    fi
    
    echo -en "${YELLOW}$message $prompt: ${NC}"
    read response < "$TTY_INPUT"
    response=${response:-$default}
    
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

resolve_beta_version() {
    npm view openclaw dist-tags.beta 2>/dev/null || true
}

normalize_install_options() {
    if [ "$INSTALL_METHOD" != "npm" ] && [ "$INSTALL_METHOD" != "git" ]; then
        log_error "无效安装方式: $INSTALL_METHOD（仅支持 npm|git）"
        exit 2
    fi

    if [ "$USE_BETA" = "1" ]; then
        local beta_version
        beta_version="$(resolve_beta_version)"
        if [ -n "$beta_version" ] && [ "$beta_version" != "undefined" ] && [ "$beta_version" != "null" ]; then
            OPENCLAW_VERSION="$beta_version"
            log_info "检测到 beta 版本: $OPENCLAW_VERSION"
        else
            log_warn "未找到 beta dist-tag，回退 latest"
            OPENCLAW_VERSION="latest"
        fi
    fi
}

print_install_plan() {
    echo ""
    echo -e "${CYAN}安装计划:${NC}"
    echo "  - installer: $INSTALLER_NAME"
    echo "  - install_method: $INSTALL_METHOD"
    echo "  - openclaw_version: $OPENCLAW_VERSION"
    echo "  - no_onboard: $NO_ONBOARD"
    echo "  - no_prompt: $NO_PROMPT"
    echo "  - dry_run: $DRY_RUN"
    echo "  - verbose: $VERBOSE"
    if [ "$INSTALL_METHOD" = "git" ]; then
        echo "  - git_dir: $GIT_DIR"
        echo "  - git_update: $GIT_UPDATE"
    fi
}

# ================================ 系统检测 ================================

detect_os() {
    log_step "检测操作系统..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            OS_VERSION=$VERSION_ID
        fi
        PACKAGE_MANAGER=""
        if command -v apt-get &> /dev/null; then
            PACKAGE_MANAGER="apt"
        elif command -v yum &> /dev/null; then
            PACKAGE_MANAGER="yum"
        elif command -v dnf &> /dev/null; then
            PACKAGE_MANAGER="dnf"
        elif command -v pacman &> /dev/null; then
            PACKAGE_MANAGER="pacman"
        fi
        log_info "检测到 Linux 系统: $OS $OS_VERSION (包管理器: $PACKAGE_MANAGER)"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        OS_VERSION=$(sw_vers -productVersion)
        PACKAGE_MANAGER="brew"
        log_info "检测到 macOS 系统: $OS_VERSION"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        log_info "检测到 Windows 系统 (Git Bash/Cygwin)"
    else
        log_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "检测到以 root 用户运行"
        if ! confirm "建议使用普通用户运行，是否继续？" "n"; then
            exit 1
        fi
    fi
}

ensure_sudo_privileges() {
    # root 用户无需 sudo
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi

    # Linux 下依赖安装和 systemd 操作需要 sudo
    if [[ "$OS" != "macos" ]]; then
        if ! check_command sudo; then
            log_error "未检测到 sudo，无法安装系统依赖。请安装 sudo 或使用 root 运行。"
            exit 1
        fi

        log_step "检查并请求 sudo 权限..."
        if ! sudo -v; then
            log_error "sudo 授权失败，安装已中止。"
            echo -e "${YELLOW}请确认当前用户在 sudoers 中，或改用 root 运行。${NC}"
            exit 1
        fi

        # 保持 sudo 会话，避免中途过期导致命令失败
        (
            while true; do
                sudo -n true 2>/dev/null || exit 0
                sleep 50
            done
        ) &
        SUDO_KEEPALIVE_PID=$!
        trap 'if [ -n "${SUDO_KEEPALIVE_PID:-}" ]; then kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true; fi' EXIT

        log_info "sudo 权限已就绪"
    fi
}

# ================================ 依赖检查与安装 ================================

check_command() {
    command -v "$1" &> /dev/null
}

get_gateway_pid() {
    get_port_pid 18789
}

get_port_pid() {
    local port="$1"
    local pid=""
    if check_command lsof; then
        pid=$(lsof -ti :"$port" 2>/dev/null | head -1)
    fi
    if [ -z "$pid" ] && check_command pgrep; then
        pid=$(pgrep -f "openclaw gateway" 2>/dev/null | head -1)
    fi
    echo "$pid"
}

install_homebrew() {
    if ! check_command brew; then
        log_step "安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # 添加到 PATH
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
}

install_nodejs() {
    log_step "检查 Node.js..."
    
    if check_command node; then
        local node_major
        local node_minor
        node_major=$(node -v | sed 's/^v//' | cut -d'.' -f1)
        node_minor=$(node -v | sed 's/^v//' | cut -d'.' -f2)
        if [ "$node_major" -gt "$MIN_NODE_MAJOR" ] || { [ "$node_major" -eq "$MIN_NODE_MAJOR" ] && [ "$node_minor" -ge "$MIN_NODE_MINOR" ]; }; then
            log_info "Node.js 版本满足要求: $(node -v)"
            return 0
        else
            log_warn "Node.js 版本过低: $(node -v)，需要 v${MIN_NODE_MAJOR}.${MIN_NODE_MINOR}+"
        fi
    fi
    
    log_step "安装 Node.js ${MIN_NODE_MAJOR}.x ..."
    
    case "$OS" in
        macos)
            install_homebrew
            brew install node@22
            brew link --overwrite node@22
            ;;
        ubuntu|debian)
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        centos|rhel|fedora)
            curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
            sudo yum install -y nodejs
            ;;
        arch|manjaro)
            sudo pacman -S nodejs npm --noconfirm
            ;;
        *)
            log_error "无法自动安装 Node.js，请手动安装 v${MIN_NODE_MAJOR}.${MIN_NODE_MINOR}+"
            exit 1
            ;;
    esac
    
    log_info "Node.js 安装完成: $(node -v)"
}

install_git() {
    if ! check_command git; then
        log_step "安装 Git..."
        case "$OS" in
            macos)
                install_homebrew
                brew install git
                ;;
            ubuntu|debian)
                sudo apt-get update && sudo apt-get install -y git
                ;;
            centos|rhel|fedora)
                sudo yum install -y git
                ;;
            arch|manjaro)
                sudo pacman -S git --noconfirm
                ;;
        esac
    fi
    log_info "Git 版本: $(git --version)"
}

install_dependencies() {
    log_step "检查并安装依赖..."
    
    # 安装基础依赖
    case "$OS" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y curl wget jq
            ;;
        centos|rhel|fedora)
            sudo yum install -y curl wget jq
            ;;
        macos)
            install_homebrew
            brew install curl wget jq
            ;;
    esac
    
    install_git
    install_nodejs
}

# ================================ OpenClaw 安装 ================================

create_directories() {
    log_step "创建配置目录..."
    
    mkdir -p "$CONFIG_DIR"
    
    log_info "配置目录: $CONFIG_DIR"
}

install_openclaw_via_official() {
    local -a args
    args=(--install-method "$INSTALL_METHOD" --no-onboard)

    if [ "$NO_PROMPT" = "1" ]; then
        args+=(--no-prompt)
    fi
    if [ "$VERBOSE" = "1" ]; then
        args+=(--verbose)
    fi
    if [ "$DRY_RUN" = "1" ]; then
        args+=(--dry-run)
    fi
    if [ "$USE_BETA" = "1" ]; then
        args+=(--beta)
    elif [ -n "$OPENCLAW_VERSION" ] && [ "$OPENCLAW_VERSION" != "latest" ]; then
        args+=(--version "$OPENCLAW_VERSION")
    fi
    if [ "$INSTALL_METHOD" = "git" ]; then
        args+=(--git-dir "$GIT_DIR")
        if [ "$GIT_UPDATE" = "0" ]; then
            args+=(--no-git-update)
        fi
    fi

    log_info "调用官方安装器以确保核心安装行为与上游一致..."
    local tmp_script
    tmp_script="$(mktemp /tmp/openclaw-install.XXXXXX.sh)"
    if ! download_with_fallback "$tmp_script" "$OFFICIAL_INSTALL_URL" "$OFFICIAL_INSTALL_MIRROR_URL"; then
        rm -f "$tmp_script" 2>/dev/null || true
        return 1
    fi
    bash "$tmp_script" "${args[@]}"
    local install_exit=$?
    rm -f "$tmp_script" 2>/dev/null || true
    return "$install_exit"
}

ensure_openclaw_on_path() {
    # 尝试从常见 npm 全局安装位置补充 PATH，避免“已安装但当前 shell 不可见”
    local npm_prefix=""
    local npm_bin=""
    local candidate=""

    if check_command npm; then
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

    if check_command openclaw; then
        command -v openclaw
        return 0
    fi
    if check_command claw; then
        command -v claw
        return 0
    fi

    if check_command npm && check_command node; then
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
const bin=(pkg.bin&& (pkg.bin.openclaw||pkg.bin.claw)) || "";
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

get_current_model_ref() {
    if ! check_command openclaw; then
        return 1
    fi

    local model_ref=""
    if check_command node; then
        model_ref=$(openclaw models status --json 2>/dev/null | node -e '
const fs = require("fs");
try {
  const raw = fs.readFileSync(0, "utf8");
  const data = JSON.parse(raw || "{}");
  const v = (data.resolvedDefault || data.defaultModel || "").trim();
  if (v) process.stdout.write(v);
} catch {}
' 2>/dev/null || true)
    elif check_command python3; then
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

install_openclaw() {
    log_step "安装 OpenClaw..."
    
    # 检查是否已安装
    if check_command openclaw; then
        local current_version=$(openclaw --version 2>/dev/null || echo "unknown")
        log_warn "OpenClaw 已安装 (版本: $current_version)"
        if ! confirm "是否重新安装/更新？"; then
            init_openclaw_config
            return 0
        fi
    fi

    if ! install_openclaw_via_official; then
        if [ "$INSTALL_METHOD" != "npm" ]; then
            log_error "官方安装器执行失败，且当前为 git 安装模式，无法安全回退"
            exit 1
        fi
        log_warn "官方安装器执行失败，回退到 npm 安装"
        npm install -g "openclaw@$OPENCLAW_VERSION" --unsafe-perm
    fi
    
    # 验证安装
    local claw_bin=""
    claw_bin="$(resolve_openclaw_bin || true)"
    if [ -n "$claw_bin" ]; then
        local claw_dir
        claw_dir="$(dirname "$claw_bin")"
        case ":$PATH:" in
            *":$claw_dir:"*) ;;
            *) export PATH="$claw_dir:$PATH" ;;
        esac

        # 某些版本仅暴露 claw 命令；自动提供 openclaw shim
        if ! check_command openclaw && [ "$(basename "$claw_bin")" = "claw" ]; then
            local shim_dir=""
            local shim_target=""
            shim_dir="$(dirname "$claw_bin")"
            if [ -d "$shim_dir" ] && [ -w "$shim_dir" ]; then
                shim_target="$shim_dir/openclaw"
            else
                shim_dir="$HOME/.local/bin"
                mkdir -p "$shim_dir" 2>/dev/null || true
                shim_target="$shim_dir/openclaw"
            fi

            cat > "$shim_target" <<EOF
#!/bin/sh
exec "$claw_bin" "\$@"
EOF
            chmod +x "$shim_target" 2>/dev/null || true
            case ":$PATH:" in
                *":$shim_dir:"*) ;;
                *) export PATH="$shim_dir:$PATH" ;;
            esac
            log_info "已创建 openclaw 命令兼容 shim: $shim_target"
        fi

        log_info "OpenClaw 安装成功: $("$claw_bin" --version 2>/dev/null || echo 'installed')"
        init_openclaw_config
    else
        log_error "OpenClaw 安装后未在当前 PATH 中发现可执行文件"
        if check_command npm; then
            local npm_prefix_hint
            npm_prefix_hint="$(npm config get prefix 2>/dev/null || true)"
            if [ -n "$npm_prefix_hint" ] && [ "$npm_prefix_hint" != "undefined" ] && [ "$npm_prefix_hint" != "null" ]; then
                echo -e "${YELLOW}可能的修复方式:${NC}"
                echo "  export PATH=\"$npm_prefix_hint/bin:\$PATH\""
                echo "  hash -r"
                echo "  command -v openclaw && openclaw --version"
            fi
        fi
        exit 1
    fi
}

# 初始化 OpenClaw 配置
init_openclaw_config() {
    log_step "初始化 OpenClaw 配置..."
    
    local OPENCLAW_DIR="$HOME/.openclaw"
    
    # 创建必要的目录
    mkdir -p "$OPENCLAW_DIR/agents/main/sessions"
    mkdir -p "$OPENCLAW_DIR/agents/main/agent"
    mkdir -p "$OPENCLAW_DIR/credentials"
    
    # 修复权限
    chmod 700 "$OPENCLAW_DIR" 2>/dev/null || true
    
    # 设置 gateway.mode 为 local
    if check_command openclaw; then
        openclaw config set gateway.mode local 2>/dev/null || true
        log_info "Gateway 模式已设置为 local"
        
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

# 配置 OpenClaw 使用的 AI 模型和 API Key
configure_openclaw_model() {
    log_step "配置 OpenClaw AI 模型..."
    
    local env_file="$HOME/.openclaw/env"
    local openclaw_json="$HOME/.openclaw/openclaw.json"
    
    # 创建环境变量文件
    cat > "$env_file" << EOF
# OpenClaw 环境变量配置
# 由安装脚本自动生成: $(date '+%Y-%m-%d %H:%M:%S')
EOF

    # 根据 AI_PROVIDER 设置对应的环境变量
    case "$AI_PROVIDER" in
        anthropic)
            echo "export ANTHROPIC_API_KEY=$AI_KEY" >> "$env_file"
            [ -n "$BASE_URL" ] && echo "export ANTHROPIC_BASE_URL=$BASE_URL" >> "$env_file"
            ;;
        openai)
            echo "export OPENAI_API_KEY=$AI_KEY" >> "$env_file"
            [ -n "$BASE_URL" ] && echo "export OPENAI_BASE_URL=$BASE_URL" >> "$env_file"
            ;;
        deepseek)
            echo "export DEEPSEEK_API_KEY=$AI_KEY" >> "$env_file"
            echo "export DEEPSEEK_BASE_URL=${BASE_URL:-https://api.deepseek.com}" >> "$env_file"
            ;;
        moonshot|kimi)
            echo "export MOONSHOT_API_KEY=$AI_KEY" >> "$env_file"
            echo "export MOONSHOT_BASE_URL=${BASE_URL:-https://api.moonshot.ai/v1}" >> "$env_file"
            ;;
        google|google-gemini-cli|google-antigravity)
            echo "export GOOGLE_API_KEY=$AI_KEY" >> "$env_file"
            [ -n "$BASE_URL" ] && echo "export GOOGLE_BASE_URL=$BASE_URL" >> "$env_file"
            ;;
        groq)
            echo "export GROQ_API_KEY=$AI_KEY" >> "$env_file"
            echo "export GROQ_BASE_URL=${BASE_URL:-https://api.groq.com/openai/v1}" >> "$env_file"
            ;;
        mistral)
            echo "export MISTRAL_API_KEY=$AI_KEY" >> "$env_file"
            echo "export MISTRAL_BASE_URL=${BASE_URL:-https://api.mistral.ai/v1}" >> "$env_file"
            ;;
        openrouter)
            echo "export OPENROUTER_API_KEY=$AI_KEY" >> "$env_file"
            echo "export OPENROUTER_BASE_URL=${BASE_URL:-https://openrouter.ai/api/v1}" >> "$env_file"
            ;;
        ollama)
            echo "export OLLAMA_HOST=${BASE_URL:-http://localhost:11434}" >> "$env_file"
            ;;
        xai)
            echo "export XAI_API_KEY=$AI_KEY" >> "$env_file"
            ;;
        zai)
            echo "export ZAI_API_KEY=$AI_KEY" >> "$env_file"
            ;;
        minimax|minimax-cn)
            echo "export MINIMAX_API_KEY=$AI_KEY" >> "$env_file"
            ;;
        opencode|opencode-go)
            echo "export OPENCODE_API_KEY=$AI_KEY" >> "$env_file"
            ;;
    esac
    
    chmod 600 "$env_file"
    log_info "环境变量配置已保存到: $env_file"

    if [ "$AI_PROVIDER" = "minimax" ] || [ "$AI_PROVIDER" = "minimax-cn" ]; then
        ensure_minimax_provider_config "$AI_PROVIDER" "$AI_MODEL" "$openclaw_json"
    fi
    
    # 设置默认模型
    if check_command openclaw; then
        local openclaw_model=""
        local use_custom_provider=false
        
        # 如果使用自定义 BASE_URL，需要配置自定义 provider
        if [ -n "$BASE_URL" ] && [ "$AI_PROVIDER" = "anthropic" ]; then
            use_custom_provider=true
            configure_custom_provider "$AI_PROVIDER" "$AI_KEY" "$AI_MODEL" "$BASE_URL" "$openclaw_json"
            openclaw_model="anthropic-custom/$AI_MODEL"
        elif [ -n "$BASE_URL" ] && [ "$AI_PROVIDER" = "openai" ]; then
            use_custom_provider=true
            # 传递 API 类型参数（如果已设置）
            configure_custom_provider "$AI_PROVIDER" "$AI_KEY" "$AI_MODEL" "$BASE_URL" "$openclaw_json" "$AI_API_TYPE"
            openclaw_model="openai-custom/$AI_MODEL"
        else
            case "$AI_PROVIDER" in
                anthropic)
                    openclaw_model="anthropic/$AI_MODEL"
                    ;;
                openai)
                    openclaw_model="openai/$AI_MODEL"
                    ;;
                groq)
                    openclaw_model="groq/$AI_MODEL"
                    ;;
                mistral)
                    openclaw_model="mistral/$AI_MODEL"
                    ;;
                deepseek)
                    openclaw_model="deepseek/$AI_MODEL"
                    ;;
                moonshot|kimi)
                    openclaw_model="moonshot/$AI_MODEL"
                    ;;
                openrouter)
                    openclaw_model="openrouter/$AI_MODEL"
                    ;;
                google)
                    openclaw_model="google/$AI_MODEL"
                    ;;
                google-gemini-cli)
                    openclaw_model="google-gemini-cli/$AI_MODEL"
                    ;;
                google-antigravity)
                    openclaw_model="google-antigravity/$AI_MODEL"
                    ;;
                ollama)
                    openclaw_model="ollama/$AI_MODEL"
                    ;;
                xai)
                    openclaw_model="xai/$AI_MODEL"
                    ;;
                zai)
                    openclaw_model="zai/$AI_MODEL"
                    ;;
                minimax)
                    openclaw_model="minimax/$AI_MODEL"
                    ;;
                minimax-cn)
                    openclaw_model="minimax-cn/$AI_MODEL"
                    ;;
                opencode)
                    openclaw_model="opencode/$AI_MODEL"
                    ;;
                opencode-go)
                    openclaw_model="opencode-go/$AI_MODEL"
                    ;;
            esac
        fi
        
        if [ -n "$openclaw_model" ]; then
            # 加载环境变量
            source "$env_file"
            
            # 设置默认模型（显示错误信息以便调试）
            local set_result
            local set_exit=0
            if set_result=$(openclaw models set "$openclaw_model" 2>&1); then
                set_exit=0
            else
                set_exit=$?
            fi
            
            if [ $set_exit -eq 0 ]; then
                log_info "默认模型已设置为: $openclaw_model"
            else
                log_warn "模型设置可能失败: $openclaw_model"
                echo -e "  ${GRAY}$set_result${NC}" | head -3
                
                # 尝试直接使用 config set
                log_info "尝试使用 config set 设置模型..."
                openclaw config set agents.defaults.model.primary "$openclaw_model" 2>/dev/null || true
                openclaw config set models.default "$openclaw_model" 2>/dev/null || true
            fi
        fi
    fi
    
    # 添加到 shell 配置文件
    add_env_to_shell "$env_file"
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
    
    log_step "配置自定义 Provider..."
    
    # 确保配置目录存在
    local config_dir=$(dirname "$config_file")
    mkdir -p "$config_dir" 2>/dev/null || true
    
    # 确定 API 类型
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
    
    # 读取现有配置或创建新配置
    local config_json="{}"
    if [ -f "$config_file" ]; then
        config_json=$(cat "$config_file")
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

# 添加环境变量到 shell 配置
add_env_to_shell() {
    local env_file="$1"
    local shell_rc=""
    
    if [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        shell_rc="$HOME/.bash_profile"
    fi
    
    if [ -n "$shell_rc" ]; then
        # 检查是否已添加
        if ! grep -q "source.*openclaw/env" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# OpenClaw 环境变量" >> "$shell_rc"
            echo "[ -f \"$env_file\" ] && source \"$env_file\"" >> "$shell_rc"
            log_info "环境变量已添加到: $shell_rc"
        fi
    fi
}

# ================================ 配置向导 ================================

# create_default_config 已移除 - OpenClaw 使用 openclaw.json 和环境变量

run_onboard_wizard() {
    log_step "运行配置向导..."
    
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           🧙 OpenClaw 核心配置向导${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 检查是否已有配置
    local skip_ai_config=false
    local skip_identity_config=false
    local env_file="$HOME/.openclaw/env"
    
    if [ -f "$env_file" ]; then
        echo -e "${YELLOW}检测到已有配置！${NC}"
        echo ""
        
        # 显示当前模型配置
        if check_command openclaw; then
            echo -e "${CYAN}当前 OpenClaw 配置:${NC}"
            openclaw models status 2>/dev/null | head -10 || true
            echo ""
        fi
        
        # 询问是否重新配置 AI
        if ! confirm "是否重新配置 AI 模型提供商？" "n"; then
            skip_ai_config=true
            log_info "使用现有 AI 配置"
            
            if confirm "是否测试现有 API 连接？" "y"; then
                # 从 env 文件读取配置进行测试
                source "$env_file"
                # 获取当前模型（优先使用官方 models status JSON）
                local current_model_ref
                current_model_ref="$(get_current_model_ref || true)"
                AI_MODEL="${current_model_ref#*/}"
                if [ -n "$ANTHROPIC_API_KEY" ]; then
                    AI_PROVIDER="anthropic"
                    AI_KEY="$ANTHROPIC_API_KEY"
                    BASE_URL="$ANTHROPIC_BASE_URL"
                elif [ -n "$MOONSHOT_API_KEY" ]; then
                    AI_PROVIDER="moonshot"
                    AI_KEY="$MOONSHOT_API_KEY"
                    BASE_URL="$MOONSHOT_BASE_URL"
                elif [ -n "$MINIMAX_API_KEY" ]; then
                    AI_PROVIDER="minimax"
                    AI_KEY="$MINIMAX_API_KEY"
                elif [ -n "$OPENROUTER_API_KEY" ]; then
                    AI_PROVIDER="openrouter"
                    AI_KEY="$OPENROUTER_API_KEY"
                    BASE_URL="$OPENROUTER_BASE_URL"
                elif [ -n "$MISTRAL_API_KEY" ]; then
                    AI_PROVIDER="mistral"
                    AI_KEY="$MISTRAL_API_KEY"
                    BASE_URL="$MISTRAL_BASE_URL"
                elif [ -n "$GROQ_API_KEY" ]; then
                    AI_PROVIDER="groq"
                    AI_KEY="$GROQ_API_KEY"
                    BASE_URL="$GROQ_BASE_URL"
                elif [ -n "$OPENAI_API_KEY" ]; then
                    AI_PROVIDER="openai"
                    AI_KEY="$OPENAI_API_KEY"
                    BASE_URL="$OPENAI_BASE_URL"
                elif [ -n "$GOOGLE_API_KEY" ]; then
                    AI_PROVIDER="google"
                    AI_KEY="$GOOGLE_API_KEY"
                    BASE_URL="$GOOGLE_BASE_URL"
                elif [ -n "$XAI_API_KEY" ]; then
                    AI_PROVIDER="xai"
                    AI_KEY="$XAI_API_KEY"
                elif [ -n "$ZAI_API_KEY" ]; then
                    AI_PROVIDER="zai"
                    AI_KEY="$ZAI_API_KEY"
                fi
                test_api_connection
            fi
        fi
        
        echo ""
    else
        echo -e "${CYAN}接下来将引导你完成核心配置，包括:${NC}"
        echo "  1. 选择 AI 模型提供商"
        echo "  2. 配置 API 连接"
        echo "  3. 测试 API 连接"
        echo "  4. 消息渠道配置"
        echo ""
    fi
    
    # AI 配置
    if [ "$skip_ai_config" = false ]; then
        setup_ai_provider
        # 先配置 OpenClaw（设置环境变量和自定义 provider），然后再测试
        configure_openclaw_model
        test_api_connection
    else
        # 即使跳过配置，也可选择测试连接
        if confirm "是否测试现有 API 连接？" "y"; then
            test_api_connection
        fi
    fi
    
    # 模型配置完成后，自动进入消息渠道配置
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  第 3 步: 消息渠道配置${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if confirm "现在进入消息渠道配置？" "y"; then
        if ! run_config_menu --channels-only; then
            log_warn "消息渠道配置菜单启动失败，可稍后手动运行: bash ./config-menu.sh"
        fi
    fi

    log_info "模型与消息渠道配置流程已完成！"
}

# ================================ AI Provider 配置 ================================

setup_ai_provider() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  第 1 步: 选择 AI 模型提供商${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  1)  🟣 Anthropic Claude"
    echo "  2)  🟢 OpenAI GPT"
    echo "  3)  🔵 DeepSeek"
    echo "  4)  🌙 Kimi (Moonshot)"
    echo "  5)  🔴 Google Gemini"
    echo "  6)  🔄 OpenRouter (多模型网关)"
    echo "  7)  ⚡ Groq (超快推理)"
    echo "  8)  🌬️ Mistral AI"
    echo "  9)  🟠 Ollama (本地模型)"
    echo "  10) 𝕏 xAI Grok"
    echo "  11) 🇨🇳 智谱 GLM (Zai)"
    echo "  12) 🤖 MiniMax"
    echo "  13) 🆓 OpenCode (免费多模型)"
    echo "  14) ☁️ Azure OpenAI"
    echo "  15) 🧪 Google Gemini CLI"
    echo "  16) 🚀 Google Antigravity"
    echo ""
    echo -e "${GRAY}说明:${NC}"
    echo -e "${GRAY}  • 本安装向导提供官方常用提供商的快速入口（与官方文档对齐的精简集）${NC}"
    echo -e "${GRAY}  • 更多提供商（如 Venice / Qwen / Vercel Gateway 等）可在安装后运行：${NC}"
    echo -e "${GRAY}    openclaw onboard 或 bash ~/.openclaw/config-menu.sh${NC}"
    echo -e "${GRAY}  • 官方模型文档: https://docs.openclaw.ai/providers/models${NC}"
    echo -e "${GRAY}  • 支持自定义 API 地址（通过 openclaw.json 配置自定义 Provider）${NC}"
    echo ""
    echo -en "${YELLOW}请选择 AI 提供商 [1-16] (默认: 1): ${NC}"; read ai_choice < "$TTY_INPUT"
    ai_choice=${ai_choice:-1}
    
    case $ai_choice in
        1)
            AI_PROVIDER="anthropic"
            echo ""
            echo -e "${CYAN}配置 Anthropic Claude${NC}"
            echo -e "${GRAY}官方 API: https://console.anthropic.com/${NC}"
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方 API): ${NC}"; read BASE_URL < "$TTY_INPUT"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) claude-sonnet-4-6 (推荐, 官方默认)"
            echo "  2) claude-opus-4-6 (最强)"
            echo "  3) claude-haiku-4-5 (快速)"
            echo "  4) claude-sonnet-4-5 (兼容)"
            echo "  5) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-5] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="claude-opus-4-6" ;;
                3) AI_MODEL="claude-haiku-4-5" ;;
                4) AI_MODEL="claude-sonnet-4-5" ;;
                5) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="claude-sonnet-4-6" ;;
            esac
            ;;
        2)
            AI_PROVIDER="openai"
            echo ""
            echo -e "${CYAN}配置 OpenAI GPT${NC}"
            echo -e "${GRAY}官方 API: https://platform.openai.com/${NC}"
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方 API): ${NC}"; read BASE_URL < "$TTY_INPUT"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) gpt-5.1-codex (推荐, 官方默认)"
            echo "  2) gpt-5.4 (最新通用)"
            echo "  3) gpt-5.1"
            echo "  4) gpt-5.1-codex-mini (经济)"
            echo "  5) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-5] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="gpt-5.4" ;;
                3) AI_MODEL="gpt-5.1" ;;
                4) AI_MODEL="gpt-5.1-codex-mini" ;;
                5) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="gpt-5.1-codex" ;;
            esac
            # 如果使用自定义 API 地址，询问 API 类型
            AI_API_TYPE=""
            if [ -n "$BASE_URL" ]; then
                echo ""
                echo -e "${CYAN}选择 API 兼容格式:${NC}"
                echo "  1) openai-responses (OpenAI 官方 Responses API)"
                echo "  2) openai-completions (兼容 /v1/chat/completions 端点)"
                echo -e "${GRAY}提示: 大多数第三方服务使用 openai-completions 格式${NC}"
                echo -en "${YELLOW}选择 API 格式 [1-2] (默认: 2): ${NC}"; read api_type_choice < "$TTY_INPUT"
                case $api_type_choice in
                    1) AI_API_TYPE="openai-responses" ;;
                    *) AI_API_TYPE="openai-completions" ;;
                esac
            fi
            ;;
        3)
            AI_PROVIDER="deepseek"
            echo ""
            echo -e "${CYAN}配置 DeepSeek${NC}"
            echo -e "${GRAY}官方 API: https://platform.deepseek.com/${NC}"
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方 API): ${NC}"; read BASE_URL < "$TTY_INPUT"
            BASE_URL=${BASE_URL:-"https://api.deepseek.com"}
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) deepseek-chat (V3.2, 推荐)"
            echo "  2) deepseek-reasoner (R1, 推理)"
            echo "  3) deepseek-coder"
            echo "  4) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="deepseek-reasoner" ;;
                3) AI_MODEL="deepseek-coder" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="deepseek-chat" ;;
            esac
            ;;
        4)
            AI_PROVIDER="moonshot"
            echo ""
            echo -e "${CYAN}配置 Kimi (Moonshot)${NC}"
            echo -e "${GRAY}官方控制台: https://platform.moonshot.cn/${NC}"
            echo ""
            echo "选择区域:"
            echo "  1) 国际版 API (api.moonshot.ai)"
            echo "  2) 国内版 API (api.moonshot.cn)"
            echo -en "${YELLOW}选择区域 [1-2] (默认: 1): ${NC}"; read kimi_region < "$TTY_INPUT"
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方 API): ${NC}"; read BASE_URL < "$TTY_INPUT"
            if [ -z "$BASE_URL" ]; then
                if [ "$kimi_region" = "2" ]; then
                    BASE_URL="https://api.moonshot.cn/v1"
                else
                    BASE_URL="https://api.moonshot.ai/v1"
                fi
            fi
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) kimi-k2.5 (推荐, 官方默认)"
            echo "  2) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-2] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="kimi-k2.5" ;;
            esac
            ;;
        5)
            AI_PROVIDER="google"
            echo ""
            echo -e "${CYAN}配置 Google Gemini${NC}"
            echo -e "${GRAY}获取 API Key: https://aistudio.google.com/apikey${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方): ${NC}"; read BASE_URL < "$TTY_INPUT"
            echo ""
            echo "选择模型:"
            echo "  1) gemini-3.1-pro-preview (推荐, 官方默认)"
            echo "  2) gemini-3-flash-preview"
            echo "  3) gemini-2.5-pro"
            echo "  4) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="gemini-3-flash-preview" ;;
                3) AI_MODEL="gemini-2.5-pro" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="gemini-3.1-pro-preview" ;;
            esac
            ;;
        6)
            AI_PROVIDER="openrouter"
            echo ""
            echo -e "${CYAN}配置 OpenRouter${NC}"
            echo -e "${GRAY}获取 API Key: https://openrouter.ai/${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方): ${NC}"; read BASE_URL < "$TTY_INPUT"
            BASE_URL=${BASE_URL:-"https://openrouter.ai/api/v1"}
            echo ""
            echo "选择模型:"
            echo "  1) auto (推荐, 官方默认)"
            echo "  2) anthropic/claude-opus-4.6"
            echo "  3) openai/gpt-5.1-codex"
            echo "  4) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="anthropic/claude-opus-4.6" ;;
                3) AI_MODEL="openai/gpt-5.1-codex" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="auto" ;;
            esac
            ;;
        7)
            AI_PROVIDER="groq"
            echo ""
            echo -e "${CYAN}配置 Groq${NC}"
            echo -e "${GRAY}获取 API Key: https://console.groq.com/${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方): ${NC}"; read BASE_URL < "$TTY_INPUT"
            BASE_URL=${BASE_URL:-"https://api.groq.com/openai/v1"}
            echo ""
            echo "选择模型:"
            echo "  1) llama-3.3-70b-versatile (推荐)"
            echo "  2) llama-3.1-8b-instant"
            echo "  3) mixtral-8x7b-32768"
            echo "  4) 自定义"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="llama-3.1-8b-instant" ;;
                3) AI_MODEL="mixtral-8x7b-32768" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="llama-3.3-70b-versatile" ;;
            esac
            ;;
        8)
            AI_PROVIDER="mistral"
            echo ""
            echo -e "${CYAN}配置 Mistral AI${NC}"
            echo -e "${GRAY}获取 API Key: https://console.mistral.ai/${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方): ${NC}"; read BASE_URL < "$TTY_INPUT"
            BASE_URL=${BASE_URL:-"https://api.mistral.ai/v1"}
            echo ""
            echo "选择模型:"
            echo "  1) mistral-large-latest (推荐)"
            echo "  2) mistral-small-latest"
            echo "  3) codestral-latest"
            echo "  4) 自定义"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="mistral-small-latest" ;;
                3) AI_MODEL="codestral-latest" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="mistral-large-latest" ;;
            esac
            ;;
        9)
            AI_PROVIDER="ollama"
            AI_KEY=""
            echo ""
            echo -e "${CYAN}配置 Ollama 本地模型${NC}"
            echo ""
            echo -en "${YELLOW}Ollama 地址 (默认: http://localhost:11434): ${NC}"; read BASE_URL < "$TTY_INPUT"
            BASE_URL=${BASE_URL:-"http://localhost:11434"}
            echo ""
            echo "选择模型:"
            echo "  1) llama3"
            echo "  2) llama3:70b"
            echo "  3) mistral"
            echo "  4) 自定义"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="llama3:70b" ;;
                3) AI_MODEL="mistral" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="llama3" ;;
            esac
            ;;
        10)
            AI_PROVIDER="xai"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 xAI Grok${NC}"
            echo -e "${GRAY}获取 API Key: https://console.x.ai/${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) grok-4 (推荐, 官方默认)"
            echo "  2) grok-4-fast"
            echo "  3) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-3] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="grok-4-fast" ;;
                3) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="grok-4" ;;
            esac
            ;;
        11)
            AI_PROVIDER="zai"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 智谱 GLM (Zai)${NC}"
            echo -e "${GRAY}获取 API Key: https://open.bigmodel.cn/${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) glm-5 (推荐)"
            echo "  2) glm-4.7"
            echo "  3) glm-4.7-flash"
            echo "  4) glm-4.7-flashx"
            echo "  5) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-5] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="glm-4.7" ;;
                3) AI_MODEL="glm-4.7-flash" ;;
                4) AI_MODEL="glm-4.7-flashx" ;;
                5) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="glm-5" ;;
            esac
            ;;
        12)
            AI_PROVIDER="minimax"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 MiniMax${NC}"
            echo ""
            echo "选择区域:"
            echo "  1) 国际版 (minimax)"
            echo "  2) 国内版 (minimax-cn)"
            echo -en "${YELLOW}选择区域 [1-2] (默认: 1): ${NC}"; read region_choice < "$TTY_INPUT"
            if [ "$region_choice" = "2" ]; then
                AI_PROVIDER="minimax-cn"
                echo -e "${GRAY}获取 API Key: https://platform.minimaxi.com/${NC}"
            else
                echo -e "${GRAY}获取 API Key: https://platform.minimax.io/${NC}"
            fi
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) MiniMax-M2.5 (推荐，官方)"
            echo "  2) MiniMax-M2.5-highspeed (高速)"
            echo "  3) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-3] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="MiniMax-M2.5-highspeed" ;;
                3) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="MiniMax-M2.5" ;;
            esac
            ;;
        13)
            AI_PROVIDER="opencode"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 OpenCode${NC}"
            echo -e "${GRAY}获取 API Key: https://opencode.ai/auth${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) claude-opus-4-6 (推荐, Zen 默认)"
            echo "  2) gpt-5.1-codex"
            echo "  3) gpt-5.2"
            echo "  4) gemini-3-pro"
            echo "  5) glm-4.7"
            echo "  6) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-6] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="gpt-5.1-codex" ;;
                3) AI_MODEL="gpt-5.2" ;;
                4) AI_MODEL="gemini-3-pro" ;;
                5) AI_MODEL="glm-4.7" ;;
                6) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="claude-opus-4-6" ;;
            esac
            ;;
        14)
            # Azure OpenAI 走 OpenAI 兼容协议
            AI_PROVIDER="openai"
            AI_API_TYPE="openai-completions"
            echo ""
            echo -e "${CYAN}配置 Azure OpenAI${NC}"
            echo -e "${GRAY}说明: 请输入 Azure Endpoint（示例: https://<resource>.openai.azure.com）${NC}"
            echo ""
            echo -en "${YELLOW}Azure Endpoint: ${NC}"; read azure_endpoint < "$TTY_INPUT"
            echo -en "${YELLOW}Azure 部署名(Deployment Name): ${NC}"; read azure_deployment < "$TTY_INPUT"
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            if [ -z "$azure_endpoint" ] || [ -z "$azure_deployment" ] || [ -z "$AI_KEY" ]; then
                log_warn "Azure OpenAI 信息不完整，回退到 OpenAI 默认配置"
                BASE_URL=""
                AI_MODEL="gpt-5.1-codex"
            else
                BASE_URL="${azure_endpoint%/}/openai/deployments/${azure_deployment}"
                AI_MODEL="$azure_deployment"
            fi
            ;;
        15)
            AI_PROVIDER="google-gemini-cli"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 Google Gemini CLI${NC}"
            echo -e "${GRAY}获取 API Key: https://aistudio.google.com/apikey${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) gemini-3.1-pro-preview (推荐)"
            echo "  2) gemini-3-flash-preview"
            echo "  3) gemini-3.1-flash-lite-preview"
            echo "  4) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="gemini-3-flash-preview" ;;
                3) AI_MODEL="gemini-3.1-flash-lite-preview" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="gemini-3.1-pro-preview" ;;
            esac
            ;;
        16)
            AI_PROVIDER="google-antigravity"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 Google Antigravity${NC}"
            echo -e "${GRAY}获取 API Key: https://aistudio.google.com/apikey${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) gemini-3-pro-high (推荐)"
            echo "  2) gemini-3-pro-low"
            echo "  3) gemini-3-flash"
            echo "  4) claude-opus-4-6-thinking"
            echo "  5) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-5] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="gemini-3-pro-low" ;;
                3) AI_MODEL="gemini-3-flash" ;;
                4) AI_MODEL="claude-opus-4-6-thinking" ;;
                5) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="gemini-3-pro-high" ;;
            esac
            ;;
        *)
            # 默认使用 Anthropic
            AI_PROVIDER="anthropic"
            echo ""
            echo -e "${CYAN}配置 Anthropic Claude${NC}"
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方): ${NC}"; read BASE_URL < "$TTY_INPUT"
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            AI_MODEL="claude-sonnet-4-6"
            ;;
    esac
    
    echo ""
    log_info "AI Provider 配置完成"
    echo -e "  提供商: ${WHITE}$AI_PROVIDER${NC}"
    echo -e "  模型: ${WHITE}$AI_MODEL${NC}"
    [ -n "$BASE_URL" ] && echo -e "  API 地址: ${WHITE}$BASE_URL${NC}"
}

# ================================ API 连接测试 ================================

test_api_connection() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  第 2 步: 测试 API 连接${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local test_passed=false
    
    # 确保环境变量已加载
    local env_file="$HOME/.openclaw/env"
    [ -f "$env_file" ] && source "$env_file"
    
    if ! check_command openclaw; then
        echo -e "${YELLOW}OpenClaw 未安装，跳过测试${NC}"
        return 0
    fi
    
    local current_model_ref
    current_model_ref="$(get_current_model_ref || true)"
    echo -e "${CYAN}当前模型配置:${NC}"
    openclaw models status 2>&1 | head -12
    echo ""
    [ -n "$current_model_ref" ] && echo -e "${CYAN}目标模型:${NC} ${WHITE}${current_model_ref}${NC}" && echo ""

    echo -e "${YELLOW}运行官方模型探针 (openclaw models status --probe --check)...${NC}"
    local probe_output=""
    local probe_exit=0
    set +e
    probe_output=$(openclaw models status --probe --check --json 2>&1)
    probe_exit=$?
    set -e

    if [ $probe_exit -eq 0 ]; then
        test_passed=true
        echo -e "${GREEN}✓ OpenClaw AI 测试成功（探针通过）${NC}"
    else
        echo -e "${RED}✗ 模型探针失败${NC}"
        echo "$probe_output" | head -10 | sed 's/^/  /'
        echo ""
        echo -e "${YELLOW}尝试本地 agent 调用获取详细错误...${NC}"
        local agent_output=""
        local agent_exit=1
        if [ -n "$current_model_ref" ]; then
            set +e
            agent_output=$(openclaw agent --local --model "$current_model_ref" --message "只回复 OK" 2>&1)
            agent_exit=$?
            set -e
        else
            set +e
            agent_output=$(openclaw agent --local --message "只回复 OK" 2>&1)
            agent_exit=$?
            set -e
        fi
        if [ $agent_exit -eq 0 ] && ! echo "$agent_output" | grep -qiE "error|failed|401|403|Unknown model"; then
            test_passed=true
            echo -e "${GREEN}✓ OpenClaw AI 测试成功（agent 调用通过）${NC}"
        else
            echo -e "${RED}✗ OpenClaw AI 调用失败${NC}"
            echo "$agent_output" | head -10 | sed 's/^/  /'
        fi
    fi

    if [ "$test_passed" = false ]; then
        echo -e "${RED}API 连接测试失败${NC}"
        echo ""
        echo "建议运行以下命令手动配置:"
        echo "  openclaw configure --section model"
        echo "  openclaw doctor"
        echo ""
        if confirm "是否仍然继续安装？" "y"; then
            log_warn "跳过连接测试，继续安装..."
            return 0
        else
            echo "安装已取消"
            exit 1
        fi
    fi
    
    return 0
}

# ================================ 身份配置 ================================

setup_identity() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  第 3 步: 设置身份信息${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -en "${YELLOW}给你的 AI 助手起个名字 (默认: Clawd): ${NC}"; read BOT_NAME < "$TTY_INPUT"
    BOT_NAME=${BOT_NAME:-"Clawd"}
    
    echo -en "${YELLOW}AI 如何称呼你 (默认: 主人): ${NC}"; read USER_NAME < "$TTY_INPUT"
    USER_NAME=${USER_NAME:-"主人"}
    
    echo -en "${YELLOW}你的时区 (默认: Asia/Shanghai): ${NC}"; read TIMEZONE < "$TTY_INPUT"
    TIMEZONE=${TIMEZONE:-"Asia/Shanghai"}
    
    echo ""
    log_info "身份配置完成"
    echo -e "  助手名称: ${WHITE}$BOT_NAME${NC}"
    echo -e "  你的称呼: ${WHITE}$USER_NAME${NC}"
    echo -e "  时区: ${WHITE}$TIMEZONE${NC}"
    
    # 初始化渠道配置变量
    TELEGRAM_ENABLED="false"
    DISCORD_ENABLED="false"
    SHELL_ENABLED="false"
    FILE_ACCESS="false"
}


# ================================ 服务管理 ================================

setup_daemon() {
    if confirm "是否设置开机自启动？" "y"; then
        log_step "配置系统服务..."
        
        case "$OS" in
            macos)
                setup_launchd
                ;;
            *)
                setup_systemd
                ;;
        esac
    fi
}

setup_systemd() {
    cat > /tmp/openclaw.service << EOF
[Unit]
Description=OpenClaw AI Assistant
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$(which openclaw) gateway start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo mv /tmp/openclaw.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable openclaw
    
    log_info "Systemd 服务已配置"
}

setup_launchd() {
    mkdir -p "$HOME/Library/LaunchAgents"
    
    cat > "$HOME/Library/LaunchAgents/com.openclaw.agent.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.openclaw.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which openclaw)</string>
        <string>gateway</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$CONFIG_DIR/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$CONFIG_DIR/stderr.log</string>
</dict>
</plist>
EOF

    launchctl load "$HOME/Library/LaunchAgents/com.openclaw.agent.plist" 2>/dev/null || true
    
    log_info "LaunchAgent 已配置"
}

# ================================ 完成安装 ================================

print_success() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}                    🎉 安装完成！🎉${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}配置目录:${NC}"
    echo "  OpenClaw 配置: ~/.openclaw/"
    echo "  环境变量配置: ~/.openclaw/env"
    echo ""
    echo -e "${CYAN}常用命令:${NC}"
    echo "  openclaw gateway start   # 后台启动服务"
    echo "  openclaw gateway stop    # 停止服务"
    echo "  openclaw gateway status  # 查看状态"
    echo "  openclaw models status   # 查看模型配置"
    echo "  openclaw channels list   # 查看渠道列表"
    echo "  openclaw doctor          # 诊断问题"
    echo ""
    echo -e "${PURPLE}📚 官方文档: $OFFICIAL_DOCS_URL${NC}"
    echo -e "${PURPLE}💬 社区支持: https://github.com/$GITHUB_REPO/discussions${NC}"
    echo ""
}

# 启动 OpenClaw Gateway 服务
start_openclaw_service() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           🚀 启动 OpenClaw 服务${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 加载环境变量
    local env_file="$HOME/.openclaw/env"
    if [ -f "$env_file" ]; then
        source "$env_file"
        log_info "已加载环境变量"
    fi
    
    # 使用端口检测判断是否已有服务在运行（更可靠）
    local existing_pid
    existing_pid=$(get_gateway_pid)
    if [ -n "$existing_pid" ]; then
        log_warn "OpenClaw Gateway 已在运行 (PID: $existing_pid)"
        echo ""
        if confirm "是否重启服务？" "y"; then
            openclaw gateway stop 2>/dev/null || true
            sleep 2
        else
            return 0
        fi
    fi
    
    # 后台启动 Gateway（使用 setsid 完全脱离终端）
    log_step "正在后台启动 Gateway..."
    
    if command -v setsid &> /dev/null; then
        if [ -f "$env_file" ]; then
            setsid bash -c "source $env_file && exec openclaw gateway --port 18789" > /tmp/openclaw-gateway.log 2>&1 &
        else
            setsid openclaw gateway --port 18789 > /tmp/openclaw-gateway.log 2>&1 &
        fi
    else
        # 备用方案：nohup + disown
        if [ -f "$env_file" ]; then
            nohup bash -c "source $env_file && exec openclaw gateway --port 18789" > /tmp/openclaw-gateway.log 2>&1 &
        else
            nohup openclaw gateway --port 18789 > /tmp/openclaw-gateway.log 2>&1 &
        fi
        disown 2>/dev/null || true
    fi
    
    # 等待服务启动
    sleep 3
    
    # 使用端口检测判断服务是否启动成功（更可靠）
    local gateway_pid
    gateway_pid=$(get_gateway_pid)
    if [ -n "$gateway_pid" ]; then
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}           ✓ OpenClaw Gateway 已启动！(PID: $gateway_pid)${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${CYAN}查看状态:${NC} openclaw gateway status"
        echo -e "  ${CYAN}查看日志:${NC} tail -f /tmp/openclaw-gateway.log"
        echo -e "  ${CYAN}停止服务:${NC} openclaw gateway stop"
        echo ""
        log_info "OpenClaw 现在可以接收消息了！"
    else
        log_error "Gateway 启动失败"
        echo ""
        echo -e "${YELLOW}请查看日志: tail -f /tmp/openclaw-gateway.log${NC}"
        echo -e "${YELLOW}或手动启动: source ~/.openclaw/env && openclaw gateway${NC}"
    fi
}

# 下载并运行配置菜单
run_config_menu() {
    local menu_args=("$@")
    local config_menu_path="./config-menu.sh"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local local_config_menu="$script_dir/config-menu.sh"
    local menu_script=""
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           🔧 启动配置菜单${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 检查本地是否已有配置菜单
    local has_local_menu=false
    if [ -f "$local_config_menu" ]; then
        has_local_menu=true
        menu_script="$local_config_menu"
    elif [ -f "$config_menu_path" ]; then
        has_local_menu=true
        menu_script="$config_menu_path"
    fi
    
    # 如果本地已有配置菜单，询问是否更新
    if [ "$has_local_menu" = true ]; then
        log_info "检测到本地配置菜单: $menu_script"
        echo ""
        if confirm "是否从 GitHub 更新到最新版本？" "n"; then
            log_step "从 GitHub 下载最新配置菜单..."
            if download_with_fallback "$config_menu_path.tmp" "$GITHUB_RAW_URL/config-menu.sh" "$INSTALLER_MIRROR_RAW_URL/config-menu.sh"; then
                mv "$config_menu_path.tmp" "$config_menu_path"
                chmod +x "$config_menu_path"
                log_info "配置菜单已更新: $config_menu_path"
                menu_script="$config_menu_path"
            else
                rm -f "$config_menu_path.tmp" 2>/dev/null
                log_warn "下载失败，继续使用本地版本"
            fi
        else
            log_info "使用本地配置菜单"
        fi
    else
        # 本地没有配置菜单，从 GitHub 下载
        log_step "从 GitHub 下载配置菜单..."
        if download_with_fallback "$config_menu_path.tmp" "$GITHUB_RAW_URL/config-menu.sh" "$INSTALLER_MIRROR_RAW_URL/config-menu.sh"; then
            mv "$config_menu_path.tmp" "$config_menu_path"
            chmod +x "$config_menu_path"
            log_info "配置菜单已下载: $config_menu_path"
            menu_script="$config_menu_path"
        else
            rm -f "$config_menu_path.tmp" 2>/dev/null
            log_error "配置菜单下载失败"
            echo -e "${YELLOW}你可以稍后手动下载运行:${NC}"
            echo "  bash -c 'set -e; tmp=\"\$(mktemp)\"; for u in \"$GITHUB_RAW_URL/config-menu.sh\" \"$INSTALLER_MIRROR_RAW_URL/config-menu.sh\"; do if curl -fsSL --proto \"=https\" --tlsv1.2 --connect-timeout ${CURL_CONNECT_TIMEOUT} --max-time ${CURL_MAX_TIME} \"\$u\" -o \"\$tmp\"; then bash \"\$tmp\"; rm -f \"\$tmp\"; exit 0; fi; done; rm -f \"\$tmp\"; echo \"All sources failed\"; exit 1'"
            return 1
        fi
    fi
    
    # 确保有执行权限
    chmod +x "$menu_script" 2>/dev/null || true
    
    # 启动配置菜单（使用 /dev/tty 确保交互正常）
    echo ""
    if [ -e /dev/tty ]; then
        bash "$menu_script" "${menu_args[@]}" < /dev/tty
    else
        bash "$menu_script" "${menu_args[@]}"
    fi
    return $?
}

# ================================ 主函数 ================================

main() {
    parse_args "$@"
    if [ "$HELP" = "1" ]; then
        print_usage
        exit 0
    fi
    normalize_install_options

    print_banner
    print_install_plan
    
    echo -e "${YELLOW}⚠️  警告: OpenClaw 需要完全的计算机权限${NC}"
    echo -e "${YELLOW}    不建议在主要工作电脑上安装，建议使用专用服务器或虚拟机${NC}"
    echo ""

    if [ "$DRY_RUN" = "1" ]; then
        log_info "dry-run 模式：仅输出计划，不执行安装"
        exit 0
    fi

    if ! confirm "是否继续安装？"; then
        echo "安装已取消"
        exit 0
    fi
    
    echo ""
    detect_os
    check_root
    ensure_sudo_privileges
    install_dependencies
    create_directories
    install_openclaw
    if [ "$NO_ONBOARD" = "1" ]; then
        log_info "已按参数跳过 AI 初始化向导 (--no-onboard)"
    else
        run_onboard_wizard
    fi
    setup_daemon
    print_success
    
    # 询问是否启动服务
    if confirm "是否现在启动 OpenClaw 服务？" "y"; then
        start_openclaw_service
    else
        echo ""
        echo -e "${CYAN}稍后可以通过以下命令启动服务:${NC}"
        echo "  source ~/.openclaw/env && openclaw gateway"
        echo ""
    fi
    
    # 询问是否打开配置菜单进行详细配置
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           📝 配置菜单（命令行版）${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GRAY}配置菜单支持: 渠道配置、身份设置、安全配置、服务管理等${NC}"
    echo ""
    echo -e "${WHITE}💡 下次可以直接运行配置菜单:${NC}"
    echo -e "   ${CYAN}bash ./config-menu.sh${NC}"
    echo ""
    if confirm "是否现在打开配置菜单？" "n"; then
        run_config_menu
    else
        echo ""
        echo -e "${CYAN}稍后可以通过以下命令打开配置菜单:${NC}"
        echo "  bash ./config-menu.sh"
        echo ""
    fi
    
    echo ""
    echo -e "${GREEN}🦞 OpenClaw 安装完成！祝你使用愉快！${NC}"
    echo ""
}

# 始终输出收尾提示，避免用户感知“无响应直接退出”
trap 'print_exit_hint "$?"' EXIT

# 执行主函数
main "$@"
