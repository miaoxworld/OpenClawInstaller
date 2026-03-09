#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   🦞 OpenClaw 一键部署脚本 v2.0.1                                          ║
# ║   智能 AI 助手部署工具 - 支持多平台多模型                                    ║
# ║                                                                           ║
# ║   GitHub: https://github.com/MarcusDog/OpenClawInstaller                  ║
# ║   官方文档: https://docs.openclaw.ai                                       ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# 使用方法:
#   curl -fsSL https://raw.githubusercontent.com/MarcusDog/OpenClawInstaller/main/install.sh | bash
#   或本地执行: chmod +x install.sh && ./install.sh
#

# 不使用 set -e，改为手动错误处理以支持自动修复和重试
set +e
set -o pipefail

# ================================ TTY 检测 ================================
# 当通过 curl | bash 运行时，stdin 是管道，需要从 /dev/tty 读取用户输入
if [ -t 0 ]; then
    # stdin 是终端
    TTY_INPUT="/dev/stdin"
else
    # stdin 是管道，使用 /dev/tty
    TTY_INPUT="/dev/tty"
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
OPENCLAW_VERSION="latest"
CONFIG_DIR="$HOME/.openclaw"
MIN_NODE_VERSION=22
GITHUB_REPO="MarcusDog/OpenClawInstaller"
GITHUB_RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main"
WINDOWS_MODE=""  # native 或 wsl2
CUSTOM_PROVIDER_NAME=""  # 自定义 API Provider 名称
MAX_RETRY=3  # 错误重试次数
EXTRA_MODELS=""  # 附加模型列表（逗号分隔）

# DeepSeek 预置配置（首次配置时自动应用）
AUTO_USE_DEEPSEEK_PRESET=true
DEEPSEEK_PRESET_API_KEY="sk-0afa31b8d9e044ea986d9b8a643a2920"
DEEPSEEK_PRESET_BASE_URL="https://api.deepseek.com/v1/chat/completions"
DEEPSEEK_PRESET_DEFAULT_MODEL="deepseek-chat"
DEEPSEEK_PRESET_EXTRA_MODELS="deepseek-reasoner"

# ================================ 工具函数 ================================

print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
    
     ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗██╗      █████╗ ██╗    ██╗
    ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██║     ██╔══██╗██║    ██║
    ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║     ███████║██║ █╗ ██║
    ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║     ██╔══██║██║███╗██║
    ╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗███████╗██║  ██║╚███╔███╔╝
     ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝   
                                                                         
              🦞 智能 AI 助手一键部署工具 v2.0.1 🦞
    
EOF
    echo -e "${NC}"
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

# 从 TTY 读取用户输入（支持 curl | bash 模式）
read_input() {
    local prompt="$1"
    local var_name="$2"
    echo -en "$prompt"
    read $var_name < "$TTY_INPUT"
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
    read response < "$TTY_INPUT"
    response=${response:-$default}
    
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# 打印下一步提示
print_next_step() {
    local step_num="$1"
    local description="$2"
    local command="$3"
    local purpose="$4"
    echo ""
    echo -e "${PURPLE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC} ${WHITE}📋 下一步 (${step_num}): ${description}${NC}"
    if [ -n "$command" ]; then
        echo -e "${PURPLE}│${NC} ${GRAY}命令:${NC} ${CYAN}${command}${NC}"
    fi
    if [ -n "$purpose" ]; then
        echo -e "${PURPLE}│${NC} ${GRAY}目的:${NC} ${purpose}"
    fi
    echo -e "${PURPLE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# 打印步骤完成提示
print_step_done() {
    local step_num="$1"
    local description="$2"
    echo -e "${GREEN}  ✓ 步骤 ${step_num} 完成: ${description}${NC}"
}

# ================================ 错误诊断与自动修复 ================================

# 诊断错误并尝试自动修复
# 返回 0 表示已修复可重试，返回 1 表示无法自动修复
diagnose_and_fix() {
    local error_output="$1"
    local context="$2"
    local fixed=false

    # npm 权限问题 (EACCES)
    if echo "$error_output" | grep -qi "EACCES\|permission denied.*npm"; then
        log_info "🔧 检测到 npm 权限问题，正在修复..."
        mkdir -p "$HOME/.npm-global" 2>/dev/null || true
        npm config set prefix "$HOME/.npm-global" 2>/dev/null || true
        export PATH="$HOME/.npm-global/bin:$PATH"
        log_info "已设置 npm 全局目录为 \$HOME/.npm-global"
        fixed=true
    fi

    # Windows PowerShell 执行策略导致 npm.ps1 无法运行
    if echo "$error_output" | grep -qi "npm\.ps1\|running scripts is disabled\|cannot be loaded because running scripts"; then
        log_info "🔧 检测到 PowerShell 执行策略问题，尝试自动修复..."
        if command -v powershell.exe &> /dev/null; then
            fix_powershell_execution_policy
            log_info "已尝试设置执行策略为 RemoteSigned"
            fixed=true
        fi
    fi

    # Windows 文件锁定/杀软占用导致安装失败
    if echo "$error_output" | grep -qi "EPERM\|EBUSY\|operation not permitted\|rename"; then
        log_info "🔧 检测到文件占用问题，尝试重置 npm 缓存目录..."
        mkdir -p "$HOME/.npm-cache" 2>/dev/null || true
        npm config set cache "$HOME/.npm-cache" 2>/dev/null || true
        npm cache clean --force 2>/dev/null || true
        fixed=true
    fi

    # npm 网络超时
    if echo "$error_output" | grep -qi "ETIMEDOUT\|ECONNRESET\|ENOTFOUND\|EAI_AGAIN\|fetch failed\|network"; then
        log_info "🔧 检测到网络问题，尝试切换 npm 镜像源..."
        local current_registry
        current_registry=$(npm config get registry 2>/dev/null) || true
        if echo "$current_registry" | grep -q "npmmirror"; then
            npm config set registry https://registry.npmjs.org 2>/dev/null || true
            log_info "已切换回 npm 官方源"
        else
            npm config set registry https://registry.npmmirror.com 2>/dev/null || true
            log_info "已切换到国内 npmmirror 镜像源"
        fi
        fixed=true
    fi

    # npm 缓存损坏
    if echo "$error_output" | grep -qi "ENOTEMPTY\|EINTEGRITY\|cache.*corrupt\|Verification failed"; then
        log_info "🔧 检测到 npm 缓存问题，正在清理..."
        npm cache clean --force 2>/dev/null || true
        log_info "npm 缓存已清理"
        fixed=true
    fi

    # npm 安装状态异常（idealTree/Tracker）
    if echo "$error_output" | grep -qi "idealTree\|Tracker .* already exists\|cb\(\) never called"; then
        log_info "🔧 检测到 npm 安装状态异常，正在重置 npm 状态..."
        npm cache clean --force 2>/dev/null || true
        rm -rf "$HOME/.npm/_locks" 2>/dev/null || true
        rm -rf "$HOME/.npm/_cacache/tmp" 2>/dev/null || true
        fixed=true
    fi

    # 代理配置导致的请求失败
    if echo "$error_output" | grep -qi "proxy\|tunneling socket\|ECONNREFUSED .*proxy"; then
        log_info "🔧 检测到代理问题，尝试清理 npm 代理配置..."
        npm config delete proxy 2>/dev/null || true
        npm config delete https-proxy 2>/dev/null || true
        npm config delete noproxy 2>/dev/null || true
        fixed=true
    fi

    # apt-get 锁定
    if echo "$error_output" | grep -qi "dpkg.*lock\|apt.*lock\|Could not get lock"; then
        log_info "🔧 检测到 apt 锁定，等待释放..."
        sleep 5
        sudo rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
        sudo rm -f /var/lib/apt/lists/lock 2>/dev/null || true
        sudo dpkg --configure -a 2>/dev/null || true
        fixed=true
    fi

    # 缺少编译工具 (node-gyp)
    if echo "$error_output" | grep -qi "make.*not found\|gcc.*not found\|g++.*not found\|gyp ERR\|node-gyp"; then
        log_info "🔧 检测到缺少编译工具，正在安装..."
        case "$OS" in
            ubuntu|debian) sudo apt-get install -y build-essential python3 2>/dev/null || true ;;
            centos|rhel|fedora) sudo yum groupinstall -y "Development Tools" 2>/dev/null || true ;;
            macos) xcode-select --install 2>/dev/null || true ;;
        esac
        fixed=true
    fi

    # Node.js 版本不兼容
    if echo "$error_output" | grep -qi "engine.*node\|Unsupported engine\|requires.*node"; then
        log_info "🔧 检测到 Node.js 版本不兼容"
        log_warn "当前 Node.js: $(node -v 2>/dev/null || echo '未安装')"
        log_info "需要 Node.js v${MIN_NODE_VERSION}+，请手动升级"
        fixed=true
    fi

    # 端口占用
    if echo "$error_output" | grep -qi "EADDRINUSE\|address already in use\|port.*already"; then
        log_info "🔧 检测到端口占用，尝试释放..."
        local port=18789
        local pid
        pid=$(get_port_pid "$port")
        if [ -n "$pid" ]; then
            if command -v powershell.exe &> /dev/null; then
                powershell.exe -NoProfile -Command "Stop-Process -Id $pid -Force" 2>/dev/null || kill "$pid" 2>/dev/null || true
            else
                kill "$pid" 2>/dev/null || true
            fi
            sleep 2
            log_info "已停止占用端口 $port 的进程 (PID: $pid)"
            fixed=true
        fi
    fi

    # SSL/TLS 证书问题
    if echo "$error_output" | grep -qi "SSL\|CERT_\|certificate.*expired\|self.signed"; then
        log_info "🔧 检测到 SSL 证书问题，尝试修复..."
        npm config set strict-ssl false 2>/dev/null || true
        export NODE_TLS_REJECT_UNAUTHORIZED=0
        log_warn "已临时放宽 SSL 检查 (建议后续修复系统证书)"
        fixed=true
    fi

    # 磁盘空间不足
    if echo "$error_output" | grep -qi "ENOSPC\|No space left\|disk.*full"; then
        log_info "🔧 检测到磁盘空间不足，尝试清理..."
        npm cache clean --force 2>/dev/null || true
        case "$OS" in
            ubuntu|debian)
                sudo apt-get clean 2>/dev/null || true
                sudo apt-get autoremove -y 2>/dev/null || true
                ;;
        esac
        log_warn "已清理缓存。如空间仍不足请手动清理磁盘"
        fixed=true
    fi

    # 内存不足
    if echo "$error_output" | grep -qi "ENOMEM\|out of memory\|Cannot allocate\|JavaScript heap"; then
        log_warn "⚠️  检测到内存不足"
        echo -e "${YELLOW}建议:${NC}"
        echo -e "  1. 关闭其他占用内存的程序"
        echo -e "  2. 增加 Node.js 内存限制:"
        echo -e "     ${CYAN}export NODE_OPTIONS='--max-old-space-size=4096'${NC}"
        export NODE_OPTIONS="--max-old-space-size=4096"
        fixed=true
    fi

    # DNS 解析失败
    if echo "$error_output" | grep -qi "getaddrinfo.*ENOTFOUND\|DNS.*failed"; then
        log_info "🔧 检测到 DNS 解析问题..."
        if [ -f /etc/resolv.conf ]; then
            echo -e "${YELLOW}当前 DNS:${NC}"
            grep "nameserver" /etc/resolv.conf 2>/dev/null | head -2
            echo -e "${YELLOW}可手动修改 /etc/resolv.conf 添加:${NC}"
            echo -e "  ${CYAN}nameserver 8.8.8.8${NC}"
            echo -e "  ${CYAN}nameserver 114.114.114.114${NC}"
        fi
        npm config set registry https://registry.npmmirror.com 2>/dev/null || true
        fixed=true
    fi

    # OpenClaw 命令找不到（PATH 问题）
    if echo "$error_output" | grep -qi "openclaw: command not found\|not recognized as an internal or external command"; then
        log_info "🔧 检测到 PATH 问题，尝试修复 openclaw 命令路径..."
        ensure_windows_runtime_paths
        local npm_prefix
        npm_prefix=$(npm config get prefix 2>/dev/null) || true
        if [ -n "$npm_prefix" ]; then
            export PATH="$npm_prefix/bin:$PATH"
            export PATH="$npm_prefix:$PATH"  # Windows npm 全局目录
        fi
        fixed=true
    fi

    if [ "$fixed" = true ]; then
        return 0
    fi
    return 1
}

# 带错误自动修复的 npm 全局安装
safe_npm_install() {
    local package="$1"
    local attempt=0

    while [ $attempt -lt $MAX_RETRY ]; do
        attempt=$((attempt + 1))
        log_step "[$attempt/$MAX_RETRY] 安装 $package..."

        local error_output
        error_output=$(npm install -g "$package" --unsafe-perm 2>&1)
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            log_info "$package 安装成功"
            return 0
        fi

        log_warn "安装失败 ($attempt/$MAX_RETRY)"
        echo "$error_output" | tail -5

        if [ $attempt -lt $MAX_RETRY ]; then
            if diagnose_and_fix "$error_output" "npm install $package"; then
                log_info "已自动修复，重新尝试安装..."
                sleep 2
            else
                log_warn "无法自动修复，等待 ${attempt}s 后重试..."
                sleep $attempt
            fi
        fi
    done

    log_error "$package 安装最终失败 (已重试 $MAX_RETRY 次)"
    echo ""
    echo -e "${YELLOW}排查建议:${NC}"
    echo -e "  1. 检查网络: ${CYAN}ping registry.npmjs.org${NC}"
    echo -e "  2. 切换镜像: ${CYAN}npm config set registry https://registry.npmmirror.com${NC}"
    echo -e "  3. 清理缓存: ${CYAN}npm cache clean --force${NC}"
    echo -e "  4. 手动安装: ${CYAN}npm install -g $package${NC}"
    return 1
}

# ================================ 版本检测 ================================

check_latest_version() {
    log_step "检查 OpenClaw 最新版本..."

    local latest_version=""

    # 尝试从 npm 获取最新版本
    if check_command npm; then
        latest_version=$(npm view openclaw version 2>/dev/null) || true
    fi

    # 如果 npm 失败，尝试从 GitHub API 获取
    if [ -z "$latest_version" ] && check_command curl; then
        latest_version=$(curl -fsSL "https://api.github.com/repos/openclaw/openclaw/releases/latest" 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"v\([^"]*\)".*/\1/') || true
    fi

    if [ -n "$latest_version" ]; then
        log_info "OpenClaw 最新版本: v${latest_version}"
        OPENCLAW_VERSION="$latest_version"
    else
        log_warn "无法获取最新版本信息，将使用 latest 标签安装"
        OPENCLAW_VERSION="latest"
    fi

    # 检查是否已安装并对比版本
    if check_command openclaw; then
        local current_version
        current_version=$(openclaw --version 2>/dev/null | sed 's/[^0-9.]//g') || true
        if [ -n "$current_version" ] && [ -n "$latest_version" ]; then
            if [ "$current_version" = "$latest_version" ]; then
                log_info "当前已安装最新版本: v${current_version}"
            else
                log_warn "当前版本: v${current_version}，最新版本: v${latest_version}"
                log_info "将在安装步骤中更新到最新版本"
            fi
        fi
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
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}           🪟 Windows 安装方式选择${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${CYAN}[1]${NC} 🖥️  ${WHITE}Windows 本地安装 (PowerShell)${NC}"
        echo -e "      ${GRAY}直接在 Windows 上安装，适合不想使用 WSL 的用户${NC}"
        echo -e "      ${GRAY}步骤: 安装 Node.js → npm 安装 OpenClaw → 运行向导${NC}"
        echo ""
        echo -e "  ${CYAN}[2]${NC} 🐧 ${WHITE}WSL2 + Ubuntu 安装 (推荐)${NC}"
        echo -e "      ${GRAY}在 WSL2 中运行，提供完整 Linux 环境，官方推荐方式${NC}"
        echo -e "      ${GRAY}步骤: 启用 WSL2 → 安装 Ubuntu → 安装 OpenClaw${NC}"
        echo ""
        echo -e "${YELLOW}提示: WSL2 方式兼容性更好，推荐首次安装用户选择${NC}"
        echo ""
        echo -en "${YELLOW}请选择安装方式 [1-2] (默认: 2): ${NC}"; read win_choice < "$TTY_INPUT"
        win_choice=${win_choice:-2}

        case $win_choice in
            1)
                WINDOWS_MODE="native"
                log_info "已选择: Windows 本地安装 (PowerShell)"
                ;;
            *)
                WINDOWS_MODE="wsl2"
                log_info "已选择: WSL2 + Ubuntu 安装"
                ;;
        esac

        ensure_windows_runtime_paths
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

# ================================ 依赖检查与安装 ================================

check_command() {
    local cmd="$1"
    command -v "$cmd" &> /dev/null && return 0
    command -v "${cmd}.cmd" &> /dev/null && return 0
    command -v "${cmd}.exe" &> /dev/null && return 0
    return 1
}

# Windows 环境下修复 PATH 并补齐命令 shim（npm.cmd/openclaw.cmd/node.exe）
ensure_windows_runtime_paths() {
    if [ "$OS" != "windows" ] && [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "cygwin" ]]; then
        return 0
    fi

    local appdata_unix=""
    if command -v powershell.exe &> /dev/null; then
        local appdata_win
        appdata_win=$(powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('ApplicationData')" 2>/dev/null | tr -d '\r') || true
        if [ -n "$appdata_win" ] && command -v cygpath &> /dev/null; then
            appdata_unix=$(cygpath -u "$appdata_win" 2>/dev/null) || true
        fi
    fi

    local candidates=(
        "$HOME/AppData/Roaming/npm"
        "/c/Users/$USER/AppData/Roaming/npm"
        "$appdata_unix/npm"
    )

    local p
    for p in "${candidates[@]}"; do
        [ -z "$p" ] && continue
        if [ -d "$p" ]; then
            case ":$PATH:" in
                *":$p:"*) ;;
                *) export PATH="$p:$PATH" ;;
            esac
        fi
    done

    if ! command -v npm &> /dev/null && command -v npm.cmd &> /dev/null; then
        npm() { npm.cmd "$@"; }
    fi
    if ! command -v openclaw &> /dev/null && command -v openclaw.cmd &> /dev/null; then
        openclaw() { openclaw.cmd "$@"; }
    fi
    if ! command -v node &> /dev/null && command -v node.exe &> /dev/null; then
        node() { node.exe "$@"; }
    fi
}

# 获取端口对应进程 PID（跨平台，优先 lsof，Windows 回退 PowerShell）
get_port_pid() {
    local port="$1"
    local pid=""

    if command -v lsof &> /dev/null; then
        pid=$(lsof -ti :"$port" 2>/dev/null | head -1) || true
    fi

    if [ -z "$pid" ] && command -v powershell.exe &> /dev/null; then
        pid=$(powershell.exe -NoProfile -Command "(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)" 2>/dev/null | tr -d '\r') || true
    fi

    echo "$pid"
}

# 修复 Windows 下 PowerShell 执行策略，避免 npm.ps1/openclaw.ps1 被拦截
fix_powershell_execution_policy() {
    if [ "$OS" != "windows" ] && [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "cygwin" ]]; then
        return 0
    fi

    if command -v powershell.exe &> /dev/null; then
        powershell.exe -NoProfile -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force" 2>/dev/null || true
    fi
}

# 显示 Dashboard 访问方式（优先 openclaw dashboard；失败时给 token 指引）
show_dashboard_access_hint() {
    if ! check_command openclaw; then
        return 0
    fi

    local dashboard_url
    dashboard_url=$(openclaw dashboard --no-open 2>/dev/null | grep -E "^https?://" | head -1)

    echo ""
    if [ -n "$dashboard_url" ]; then
        echo -e "${GREEN}Dashboard 访问地址:${NC}"
        echo -e "  ${WHITE}$dashboard_url${NC}"
    else
        echo -e "${YELLOW}未能自动获取 Dashboard URL，可执行:${NC}"
        echo -e "  ${WHITE}openclaw dashboard${NC}"
        local auth_token
        auth_token=$(openclaw config get gateway.auth.token 2>/dev/null || true)
        if [ -n "$auth_token" ] && [ "$auth_token" != "undefined" ]; then
            echo -e "${CYAN}如页面提示 unauthorized，请在 Dashboard 鉴权框粘贴 gateway.auth.token${NC}"
        else
            echo -e "${YELLOW}未检测到 gateway.auth.token，可运行:${NC}"
            echo -e "  ${WHITE}openclaw doctor --generate-gateway-token${NC}"
        fi
    fi
}

# Windows 专项自检：ExecutionPolicy / APPDATA npm / WSL / 代理DNS / 端口 / 文件锁
run_windows_preflight_check() {
    local mode="$1"
    [ -z "$mode" ] && mode="native"

    if [ "$OS" != "windows" ] && [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "cygwin" ]]; then
        return 0
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           🩺 Windows 专项自检（安装前）${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    ensure_windows_runtime_paths

    local has_issue=false

    # 1) ExecutionPolicy
    echo -e "${CYAN}[1/6] 检查 PowerShell ExecutionPolicy${NC}"
    local policy=""
    if command -v powershell.exe &> /dev/null; then
        policy=$(powershell.exe -NoProfile -Command "Get-ExecutionPolicy -Scope CurrentUser" 2>/dev/null | tr -d '\r') || true
        if [ "$policy" = "Restricted" ] || [ "$policy" = "AllSigned" ]; then
            echo -e "  ${YELLOW}⚠ 当前策略: ${policy}${NC}"
            has_issue=true
        else
            echo -e "  ${GREEN}✓ 当前策略: ${policy:-Unknown}${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ 未找到 powershell.exe，跳过${NC}"
    fi

    # 2) APPDATA\\npm 与 PATH
    echo -e "${CYAN}[2/6] 检查 %APPDATA%\\npm 路径与命令 shim${NC}"
    local appdata_unix=""
    local npm_dir=""
    if command -v powershell.exe &> /dev/null; then
        local appdata_win
        appdata_win=$(powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('ApplicationData')" 2>/dev/null | tr -d '\r') || true
        if [ -n "$appdata_win" ] && command -v cygpath &> /dev/null; then
            appdata_unix=$(cygpath -u "$appdata_win" 2>/dev/null) || true
            npm_dir="$appdata_unix/npm"
        fi
    fi
    [ -z "$npm_dir" ] && npm_dir="$HOME/AppData/Roaming/npm"

    if [ -d "$npm_dir" ]; then
        echo -e "  ${GREEN}✓ 目录存在: $npm_dir${NC}"
    else
        echo -e "  ${YELLOW}⚠ 目录不存在: $npm_dir (首次安装可忽略)${NC}"
    fi

    case ":$PATH:" in
        *":$npm_dir:"*) echo -e "  ${GREEN}✓ PATH 已包含 npm 全局目录${NC}" ;;
        *)
            echo -e "  ${YELLOW}⚠ PATH 未包含 npm 全局目录${NC}"
            has_issue=true
            ;;
    esac

    if check_command npm; then
        echo -e "  ${GREEN}✓ npm 命令可用${NC}"
    else
        echo -e "  ${YELLOW}⚠ npm 命令不可用${NC}"
        has_issue=true
    fi

    # 3) WSL 状态
    echo -e "${CYAN}[3/6] 检查 WSL 状态${NC}"
    if command -v wsl.exe &> /dev/null; then
        local wsl_status
        wsl_status=$(wsl.exe --status 2>&1 | tr -d '\r') || true
        if echo "$wsl_status" | grep -qiE "Default Version: 2|默认版本.*2|WSL 2"; then
            echo -e "  ${GREEN}✓ WSL2 已启用${NC}"
        else
            echo -e "  ${YELLOW}⚠ WSL2 未启用或状态不完整${NC}"
            [ "$mode" = "wsl2" ] && has_issue=true
        fi
    else
        echo -e "  ${YELLOW}⚠ wsl.exe 不可用${NC}"
        [ "$mode" = "wsl2" ] && has_issue=true
    fi

    # 4) 代理与 DNS
    echo -e "${CYAN}[4/6] 检查代理与 DNS${NC}"
    local npm_proxy npm_https_proxy npm_registry
    npm_proxy=$(npm config get proxy 2>/dev/null || true)
    npm_https_proxy=$(npm config get https-proxy 2>/dev/null || true)
    npm_registry=$(npm config get registry 2>/dev/null || echo "https://registry.npmjs.org")

    if [ -n "$npm_proxy" ] && [ "$npm_proxy" != "null" ]; then
        echo -e "  ${YELLOW}⚠ npm proxy: $npm_proxy${NC}"
        has_issue=true
    else
        echo -e "  ${GREEN}✓ npm proxy 未设置${NC}"
    fi

    if [ -n "$npm_https_proxy" ] && [ "$npm_https_proxy" != "null" ]; then
        echo -e "  ${YELLOW}⚠ npm https-proxy: $npm_https_proxy${NC}"
        has_issue=true
    else
        echo -e "  ${GREEN}✓ npm https-proxy 未设置${NC}"
    fi

    if command -v powershell.exe &> /dev/null; then
        local dns_ok
        dns_ok=$(powershell.exe -NoProfile -Command "try { Resolve-DnsName registry.npmjs.org -ErrorAction Stop | Out-Null; 'OK' } catch { 'FAIL' }" 2>/dev/null | tr -d '\r') || true
        if [ "$dns_ok" = "OK" ]; then
            echo -e "  ${GREEN}✓ DNS 解析正常 (registry.npmjs.org)${NC}"
        else
            echo -e "  ${YELLOW}⚠ DNS 解析异常${NC}"
            has_issue=true
        fi
    fi
    echo -e "  ${GRAY}当前 registry: ${npm_registry}${NC}"

    # 5) 端口占用
    echo -e "${CYAN}[5/6] 检查端口 18789 占用${NC}"
    local port_pid=""
    if command -v lsof &> /dev/null; then
        port_pid=$(lsof -ti :18789 2>/dev/null | head -1) || true
    fi
    if [ -z "$port_pid" ] && command -v powershell.exe &> /dev/null; then
        port_pid=$(powershell.exe -NoProfile -Command "(Get-NetTCPConnection -LocalPort 18789 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)" 2>/dev/null | tr -d '\r') || true
    fi
    if [ -n "$port_pid" ]; then
        echo -e "  ${YELLOW}⚠ 端口 18789 已被占用 (PID: $port_pid)${NC}"
        has_issue=true
    else
        echo -e "  ${GREEN}✓ 端口 18789 可用${NC}"
    fi

    # 6) 杀软/文件锁风险检查
    echo -e "${CYAN}[6/6] 检查文件锁风险（npm 缓存写入测试）${NC}"
    local lock_test_dir="$HOME/.npm-cache"
    local lock_test_file="$lock_test_dir/openclaw-lock-test-$$.tmp"
    mkdir -p "$lock_test_dir" 2>/dev/null || true
    if echo "ok" > "$lock_test_file" 2>/dev/null && mv "$lock_test_file" "$lock_test_file.renamed" 2>/dev/null; then
        rm -f "$lock_test_file.renamed" 2>/dev/null || true
        echo -e "  ${GREEN}✓ 缓存目录可写可重命名${NC}"
    else
        rm -f "$lock_test_file" "$lock_test_file.renamed" 2>/dev/null || true
        echo -e "  ${YELLOW}⚠ 检测到缓存目录写入/重命名异常，可能存在文件锁${NC}"
        has_issue=true
    fi

    echo ""
    if [ "$has_issue" = true ]; then
        log_warn "Windows 自检发现潜在风险，建议先自动修复"
        echo ""
        echo -e "${CYAN}可执行修复命令:${NC}"
        echo "  powershell -Command \"Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force\""
        echo "  npm config delete proxy"
        echo "  npm config delete https-proxy"
        echo "  npm cache clean --force"
        echo "  setx PATH \"%PATH%;%APPDATA%\\npm\""
        echo "  # 端口占用时(管理员 PowerShell): netstat -ano | findstr :18789"
        echo ""

        if confirm "是否执行一键自动修复（推荐）？" "y"; then
            command -v powershell.exe &> /dev/null && powershell.exe -NoProfile -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force" 2>/dev/null || true
            npm config delete proxy 2>/dev/null || true
            npm config delete https-proxy 2>/dev/null || true
            npm config delete noproxy 2>/dev/null || true
            npm cache clean --force 2>/dev/null || true
            ensure_windows_runtime_paths

            if [ -n "$port_pid" ] && confirm "检测到 18789 占用，是否尝试结束该进程？" "n"; then
                powershell.exe -NoProfile -Command "Stop-Process -Id $port_pid -Force" 2>/dev/null || true
            fi

            log_info "自动修复已执行，继续安装流程"
        else
            log_warn "你选择跳过自动修复，安装过程中如报错可回到此步骤处理"
        fi
    else
        log_info "Windows 自检通过，继续安装"
    fi
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
        local node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_version" -ge "$MIN_NODE_VERSION" ]; then
            log_info "Node.js 版本满足要求: $(node -v)"
            return 0
        else
            log_warn "Node.js 版本过低: $(node -v)，需要 v$MIN_NODE_VERSION+"
        fi
    fi
    
    log_step "安装 Node.js $MIN_NODE_VERSION..."
    
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
            log_error "无法自动安装 Node.js，请手动安装 v$MIN_NODE_VERSION+"
            exit 1
            ;;
    esac
    
    # 验证安装结果，如果失败尝试自动修复
    if ! check_command node; then
        log_warn "Node.js 安装可能失败，尝试自动诊断..."
        diagnose_and_fix "node not found after install on $OS" "install nodejs"
        # 重试一次
        case "$OS" in
            ubuntu|debian)
                curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - 2>/dev/null || true
                sudo apt-get install -y nodejs 2>/dev/null || true
                ;;
            centos|rhel|fedora)
                curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash - 2>/dev/null || true
                sudo yum install -y nodejs 2>/dev/null || true
                ;;
        esac
    fi

    if check_command node; then
        log_info "Node.js 安装完成: $(node -v)"
    else
        log_error "Node.js 安装失败，请手动安装 v$MIN_NODE_VERSION+"
        echo -e "  下载地址: ${CYAN}https://nodejs.org/zh-cn${NC}"
        exit 1
    fi
}

install_git() {
    if ! check_command git; then
        log_step "安装 Git..."
        case "$OS" in
            macos)
                install_homebrew
                brew install git 2>&1 || log_warn "Git 安装失败"
                ;;
            ubuntu|debian)
                sudo apt-get update 2>/dev/null || true
                sudo apt-get install -y git 2>&1 || log_warn "Git 安装失败"
                ;;
            centos|rhel|fedora)
                sudo yum install -y git 2>&1 || log_warn "Git 安装失败"
                ;;
            arch|manjaro)
                sudo pacman -S git --noconfirm 2>&1 || log_warn "Git 安装失败"
                ;;
        esac
    fi
    if check_command git; then
        log_info "Git 版本: $(git --version)"
    else
        log_warn "Git 未安装，部分功能可能受限"
    fi
}

install_dependencies() {
    log_step "检查并安装依赖..."
    
    # 安装基础依赖（非致命错误仅警告）
    case "$OS" in
        ubuntu|debian)
            sudo apt-get update 2>&1 || {
                log_warn "apt-get update 失败，尝试修复..."
                sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock 2>/dev/null || true
                sudo dpkg --configure -a 2>/dev/null || true
                sudo apt-get update 2>&1 || log_warn "apt-get update 仍然失败，继续安装..."
            }
            sudo apt-get install -y curl wget jq 2>&1 || log_warn "部分基础工具安装失败"
            ;;
        centos|rhel|fedora)
            sudo yum install -y curl wget jq 2>&1 || log_warn "部分基础工具安装失败"
            ;;
        macos)
            install_homebrew
            brew install curl wget jq 2>&1 || log_warn "部分基础工具安装失败"
            ;;
    esac
    
    install_git
    install_nodejs
}

# ================================ Windows 本地安装 ================================

install_windows_native() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           🖥️ Windows 本地 (PowerShell) 安装流程${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    ensure_windows_runtime_paths
    fix_powershell_execution_policy
    run_windows_preflight_check "native"

    # === 步骤 1: 检查 Node.js ===
    print_next_step "1/5" "检查 Node.js 环境" "node -v" "OpenClaw 运行需要 Node.js 22 或更高版本"

    local node_ok=false
    if check_command node; then
        local node_version
        node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_version" -ge "$MIN_NODE_VERSION" ]; then
            log_info "Node.js 版本满足要求: $(node -v)"
            node_ok=true
            print_step_done "1/5" "Node.js 环境就绪"
        else
            log_warn "Node.js 版本过低: $(node -v)，需要 v$MIN_NODE_VERSION+"
        fi
    fi

    if [ "$node_ok" = false ]; then
        echo ""
        echo -e "${RED}Node.js 未安装或版本过低${NC}"
        echo ""
        echo -e "${WHITE}请按以下步骤安装 Node.js:${NC}"
        echo ""
        echo -e "  ${CYAN}1.${NC} 打开浏览器访问: ${PURPLE}https://nodejs.org/zh-cn${NC}"
        echo -e "  ${CYAN}2.${NC} 下载 ${WHITE}Windows 安装包 (LTS v22.x)${NC}"
        echo -e "  ${CYAN}3.${NC} 双击运行安装程序，一路点击 ${WHITE}Next${NC}"
        echo -e "  ${CYAN}4.${NC} 安装时勾选 ${WHITE}「Automatically install the necessary tools」${NC} (可选)"
        echo -e "  ${CYAN}5.${NC} 安装完成后，${WHITE}关闭并重新打开${NC} Git Bash 终端"
        echo ""
        echo -e "${YELLOW}安装完成后，重新运行本脚本即可继续${NC}"
        echo ""

        if ! confirm "Node.js 是否已安装完成？" "n"; then
            echo ""
            echo -e "${YELLOW}请先安装 Node.js，然后重新运行安装脚本:${NC}"
            echo -e "  ${CYAN}./install.sh${NC}"
            exit 0
        fi

        # 重新检查
        if check_command node; then
            local recheck_version
            recheck_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
            if [ "$recheck_version" -ge "$MIN_NODE_VERSION" ]; then
                log_info "Node.js 安装成功: $(node -v)"
                node_ok=true
            fi
        fi

        if [ "$node_ok" = false ]; then
            log_error "Node.js 仍未检测到，请确认安装后重新打开终端"
            echo -e "${YELLOW}提示: 安装 Node.js 后需要重新打开 Git Bash 终端${NC}"
            exit 1
        fi
    fi

    # === 步骤 2: 设置 PowerShell 执行策略 ===
    print_next_step "2/5" "设置 PowerShell 执行策略" "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" "允许 PowerShell 运行 npm 脚本"

    log_step "检查 PowerShell 执行策略..."
    if command -v powershell.exe &> /dev/null; then
        local current_policy
        current_policy=$(powershell.exe -Command "Get-ExecutionPolicy -Scope CurrentUser" 2>/dev/null | tr -d '\r') || true
        if [ "$current_policy" = "Restricted" ] || [ "$current_policy" = "AllSigned" ]; then
            log_warn "当前执行策略为 $current_policy，需要修改"
            echo -e "${YELLOW}将自动设置执行策略为 RemoteSigned...${NC}"
            fix_powershell_execution_policy
            log_info "PowerShell 执行策略已更新"
        else
            log_info "PowerShell 执行策略已满足要求: $current_policy"
        fi
    else
        log_warn "未找到 powershell.exe，跳过执行策略设置"
    fi
    print_step_done "2/5" "PowerShell 执行策略配置完成"

    # === 步骤 3: 检查 npm 并设置国内镜像 (可选) ===
    print_next_step "3/5" "检查 npm 并安装 OpenClaw" "npm install -g openclaw@latest" "全局安装 OpenClaw 到 Windows 系统"

    if ! check_command npm; then
        ensure_windows_runtime_paths
        log_error "npm 未找到，请确认 Node.js 安装正确"
        echo -e "${YELLOW}提示: 如果 npm 命令报错，尝试在 PowerShell 中运行:${NC}"
        echo -e "  ${CYAN}Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser${NC}"
        echo -e "  ${CYAN}setx PATH \"%PATH%;%APPDATA%\\npm\"${NC}"
        exit 1
    fi
    log_info "npm 版本: $(npm -v)"

    # 可选: 设置 npm 镜像
    echo ""
    if confirm "是否设置 npm 国内镜像？(提高下载速度)" "n"; then
        npm config set registry https://registry.npmmirror.com 2>/dev/null || true
        log_info "npm 镜像已设置为: https://registry.npmmirror.com"
    fi

    # === 步骤 4: 安装 OpenClaw ===
    print_next_step "4/5" "安装 OpenClaw" "npm install -g openclaw@${OPENCLAW_VERSION}" "安装 OpenClaw 主程序（可能需要几分钟）"

    log_step "正在安装 OpenClaw..."

    # 检查是否已安装
    if check_command openclaw; then
        local current_version
        current_version=$(openclaw --version 2>/dev/null || echo "unknown")
        log_warn "OpenClaw 已安装 (版本: $current_version)"
        if ! confirm "是否重新安装/更新到最新版本？"; then
            print_step_done "4/5" "使用现有 OpenClaw 版本"
            init_openclaw_config
            return 0
        fi
    fi

    log_info "正在从 npm 安装 OpenClaw (版本: ${OPENCLAW_VERSION})..."
    echo -e "${GRAY}(安装过程可能需要几分钟，请耐心等待...)${NC}"
    if safe_npm_install "openclaw@$OPENCLAW_VERSION"; then
        log_info "npm 安装完成"
    else
        log_warn "npm 自动安装失败，尝试备用方案..."
        ensure_windows_runtime_paths
        npm install -g openclaw@$OPENCLAW_VERSION --force 2>&1 | tail -5 || true
    fi

    # 验证安装
    ensure_windows_runtime_paths
    if check_command openclaw; then
        log_info "OpenClaw 安装成功: $(openclaw --version 2>/dev/null || echo 'installed')"
        print_step_done "4/5" "OpenClaw 安装完成"
    else
        log_error "OpenClaw 安装失败"
        echo ""
        echo -e "${YELLOW}常见问题排查:${NC}"
        echo -e "  ${CYAN}1.${NC} 确认以管理员身份运行 Git Bash"
        echo -e "  ${CYAN}2.${NC} 检查 npm 全局路径是否在 PATH 中:"
        echo -e "     ${GRAY}npm config get prefix${NC}"
        echo -e "  ${CYAN}3.${NC} 将 npm 全局路径添加到系统 PATH 环境变量"
        echo -e "     ${GRAY}通常为: C:\\Users\\<你的用户名>\\AppData\\Roaming\\npm${NC}"
        echo -e "  ${CYAN}3b.${NC} 也可执行: ${GRAY}setx PATH \"%PATH%;%APPDATA%\\npm\"${NC}"
        echo -e "  ${CYAN}4.${NC} Windows Defender 可能阻止了安装，添加排除项:"
        echo -e "     ${GRAY}C:\\Users\\<你的用户名>\\AppData\\Roaming\\npm${NC}"
        echo -e "     ${GRAY}C:\\Users\\<你的用户名>\\.openclaw${NC}"
        echo ""
        echo -e "${YELLOW}或者尝试在 PowerShell (管理员) 中运行:${NC}"
        echo -e "  ${CYAN}npm install -g openclaw@latest --force${NC}"
        exit 1
    fi

    # === 步骤 5: 运行 onboard 向导 ===
    print_next_step "5/5" "运行配置向导" "openclaw onboard --install-daemon" "引导你完成 AI 模型、渠道等核心配置"

    init_openclaw_config
}

# ================================ WSL2 安装 ================================

install_windows_wsl2() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           🐧 WSL2 + Ubuntu 安装流程${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GRAY}WSL2 提供完整的 Linux 环境，是 OpenClaw 在 Windows 上的推荐部署方式${NC}"
    echo ""

    ensure_windows_runtime_paths
    run_windows_preflight_check "wsl2"

    # === 步骤 1: 检查 WSL2 是否已安装 ===
    print_next_step "1/7" "检查 WSL2 环境" "wsl --status" "检测 WSL2 是否已启用"

    local wsl_installed=false
    local wsl_has_distro=false

    if command -v wsl.exe &> /dev/null; then
        local wsl_status
        wsl_status=$(wsl.exe --status 2>&1 | tr -d '\r') || true
        if echo "$wsl_status" | grep -qi "Default Version: 2\|默认版本.*2\|WSL 2"; then
            wsl_installed=true
            log_info "WSL2 已启用"
        fi

        # 检查是否有已安装的 Linux 发行版
        local wsl_list
        wsl_list=$(wsl.exe --list --quiet 2>/dev/null | tr -d '\r' | grep -v "^$") || true
        if [ -n "$wsl_list" ]; then
            wsl_has_distro=true
            log_info "检测到已安装的 WSL 发行版:"
            echo "$wsl_list" | head -5 | sed 's/^/  - /'
        fi
    fi

    if [ "$wsl_installed" = false ]; then
        echo ""
        echo -e "${YELLOW}WSL2 未启用，需要先启用 WSL2${NC}"
        echo ""
        echo -e "${WHITE}即将自动启用 WSL2，需要管理员权限...${NC}"
        echo ""

        if confirm "是否自动启用 WSL2？" "y"; then
            print_next_step "1a" "启用 WSL 功能" "dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux" "启用 Windows 子系统 for Linux"

            log_step "启用 WSL 功能..."
            # 需要管理员权限，通过 powershell.exe 提升权限
            powershell.exe -Command "Start-Process powershell -ArgumentList '-Command', 'dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart; dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart; wsl --set-default-version 2' -Verb RunAs -Wait" 2>/dev/null || true

            echo ""
            echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║  ⚠️  需要重启计算机以完成 WSL2 启用！                         ║${NC}"
            echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${WHITE}重启后请按以下步骤继续:${NC}"
            echo ""
            echo -e "  ${CYAN}步骤 1:${NC} 打开 ${WHITE}Microsoft Store${NC}，搜索 ${WHITE}「Ubuntu 22.04 LTS」${NC} 并安装"
            echo -e "  ${CYAN}步骤 2:${NC} 启动 Ubuntu，设置用户名和密码"
            echo -e "  ${CYAN}步骤 3:${NC} 在 Ubuntu 终端中运行以下命令完成安装:"
            echo ""
            echo -e "  ${WHITE}# 更新系统${NC}"
            echo -e "  ${CYAN}sudo apt update && sudo apt upgrade -y${NC}"
            echo -e "  ${WHITE}# 安装基础工具${NC}"
            echo -e "  ${CYAN}sudo apt install -y curl git wget build-essential${NC}"
            echo -e "  ${WHITE}# 安装 Node.js 22${NC}"
            echo -e "  ${CYAN}curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -${NC}"
            echo -e "  ${CYAN}sudo apt install -y nodejs${NC}"
            echo -e "  ${WHITE}# 安装 OpenClaw${NC}"
            echo -e "  ${CYAN}npm install -g openclaw@latest${NC}"
            echo -e "  ${WHITE}# 运行配置向导${NC}"
            echo -e "  ${CYAN}openclaw onboard --install-daemon${NC}"
            echo ""
            echo -e "${YELLOW}或者直接运行一键安装脚本:${NC}"
            echo -e "  ${CYAN}curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash${NC}"
            echo ""

            if confirm "是否现在重启计算机？" "n"; then
                log_info "正在重启计算机..."
                powershell.exe -Command "Restart-Computer -Force" 2>/dev/null || shutdown.exe /r /t 5
            fi
            exit 0
        else
            echo ""
            echo -e "${WHITE}请手动在 PowerShell (管理员) 中执行以下命令:${NC}"
            echo ""
            echo -e "  ${CYAN}# 启用 WSL 功能${NC}"
            echo -e "  ${CYAN}dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart${NC}"
            echo -e "  ${CYAN}dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart${NC}"
            echo ""
            echo -e "  ${CYAN}# 设置 WSL 2 为默认版本${NC}"
            echo -e "  ${CYAN}wsl --set-default-version 2${NC}"
            echo ""
            echo -e "  ${RED}# 重启计算机${NC}"
            echo ""
            echo -e "${YELLOW}启用后重新运行本脚本选择 WSL2 安装${NC}"
            exit 0
        fi
    fi

    print_step_done "1/7" "WSL2 环境就绪"

    # === 步骤 2: 确保有 Ubuntu 发行版 ===
    print_next_step "2/7" "安装 Ubuntu 发行版" "wsl --install -d Ubuntu-22.04" "安装 Ubuntu 22.04 LTS 作为 WSL2 环境"

    if [ "$wsl_has_distro" = false ]; then
        log_step "安装 Ubuntu 22.04 LTS..."
        echo -e "${YELLOW}正在安装 Ubuntu (这可能需要几分钟)...${NC}"

        wsl.exe --install -d Ubuntu-22.04 2>/dev/null || true

        echo ""
        echo -e "${WHITE}Ubuntu 安装完成后:${NC}"
        echo -e "  ${CYAN}1.${NC} 设置 Ubuntu 用户名和密码"
        echo -e "  ${CYAN}2.${NC} 返回此终端继续安装"
        echo ""

        if ! confirm "Ubuntu 是否已安装并设置完成？" "n"; then
            echo -e "${YELLOW}请打开 Microsoft Store 安装 Ubuntu 22.04 LTS，设置完成后重新运行脚本${NC}"
            exit 0
        fi
    else
        log_info "已有 WSL 发行版可用"
    fi
    print_step_done "2/7" "Ubuntu 发行版就绪"

    # === 步骤 3: 在 WSL2 中更新系统 ===
    print_next_step "3/7" "更新 Ubuntu 系统" "sudo apt update && sudo apt upgrade -y" "确保系统软件包为最新"

    log_step "在 WSL2 中更新系统..."
    wsl.exe bash -c "sudo apt update && sudo apt upgrade -y" 2>/dev/null || true
    print_step_done "3/7" "系统更新完成"

    # === 步骤 4: 安装基础工具 ===
    print_next_step "4/7" "安装基础工具" "sudo apt install -y curl git wget build-essential" "安装编译工具和常用命令行工具"

    log_step "在 WSL2 中安装基础工具..."
    wsl.exe bash -c "sudo apt install -y curl git wget build-essential jq" 2>/dev/null || true
    print_step_done "4/7" "基础工具安装完成"

    # === 步骤 5: 安装 Node.js 22 ===
    print_next_step "5/7" "安装 Node.js 22" "curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -" "OpenClaw 运行需要 Node.js 22 或更高版本"

    log_step "在 WSL2 中安装 Node.js 22..."

    # 检查 WSL 中是否已有 Node.js 22+
    local wsl_node_version
    wsl_node_version=$(wsl.exe bash -c "node -v 2>/dev/null | cut -d'v' -f2 | cut -d'.' -f1" 2>/dev/null | tr -d '\r') || true

    if [ -n "$wsl_node_version" ] && [ "$wsl_node_version" -ge "$MIN_NODE_VERSION" ] 2>/dev/null; then
        log_info "WSL2 中 Node.js 版本满足要求: v${wsl_node_version}"
    else
        wsl.exe bash -c "curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt install -y nodejs" 2>/dev/null || true
        local new_version
        new_version=$(wsl.exe bash -c "node -v" 2>/dev/null | tr -d '\r') || true
        if [ -n "$new_version" ]; then
            log_info "WSL2 中 Node.js 安装完成: $new_version"
        else
            log_error "WSL2 中 Node.js 安装失败"
            echo -e "${YELLOW}请手动在 WSL2 Ubuntu 终端中运行:${NC}"
            echo -e "  ${CYAN}curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -${NC}"
            echo -e "  ${CYAN}sudo apt install -y nodejs${NC}"
            exit 1
        fi
    fi
    print_step_done "5/7" "Node.js 22 安装完成"

    # === 步骤 6: 在 WSL2 中安装 OpenClaw ===
    print_next_step "6/7" "安装 OpenClaw" "npm install -g openclaw@latest" "在 WSL2 中全局安装 OpenClaw"

    log_step "在 WSL2 中安装 OpenClaw..."
    echo -e "${GRAY}(安装过程可能需要几分钟，请耐心等待...)${NC}"

    wsl.exe bash -c "npm install -g openclaw@${OPENCLAW_VERSION} --unsafe-perm" 2>&1 | tail -5

    # 验证安装
    local wsl_openclaw_version
    wsl_openclaw_version=$(wsl.exe bash -c "openclaw --version 2>/dev/null" 2>/dev/null | tr -d '\r') || true
    if [ -n "$wsl_openclaw_version" ]; then
        log_info "WSL2 中 OpenClaw 安装成功: $wsl_openclaw_version"
        print_step_done "6/7" "OpenClaw 安装完成"
    else
        log_error "WSL2 中 OpenClaw 安装失败"
        echo ""
        echo -e "${YELLOW}请手动在 WSL2 Ubuntu 终端中运行:${NC}"
        echo -e "  ${CYAN}npm install -g openclaw@latest${NC}"
        exit 1
    fi

    # === 步骤 7: 初始化配置 ===
    print_next_step "7/7" "运行配置向导" "openclaw onboard --install-daemon" "引导完成 AI 模型、渠道等核心配置"

    echo ""
    echo -e "${WHITE}接下来有两种方式完成配置:${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} 在当前终端中自动完成配置向导"
    echo -e "  ${CYAN}[2]${NC} 进入 WSL2 Ubuntu 终端手动运行向导"
    echo ""
    echo -en "${YELLOW}请选择 [1-2] (默认: 1): ${NC}"; read cfg_choice < "$TTY_INPUT"
    cfg_choice=${cfg_choice:-1}

    if [ "$cfg_choice" = "2" ]; then
        echo ""
        echo -e "${WHITE}请在 WSL2 Ubuntu 终端中运行以下命令:${NC}"
        echo ""
        echo -e "  ${CYAN}openclaw onboard --install-daemon${NC}"
        echo ""
        echo -e "${WHITE}配置完成后，启动 Gateway:${NC}"
        echo ""
        echo -e "  ${CYAN}openclaw gateway --port 18789 --verbose${NC}"
        echo ""
        echo -e "${WHITE}在 Windows 浏览器中访问:${NC}"
        echo -e "  ${PURPLE}http://localhost:18789${NC}"
        echo ""
        echo -e "${YELLOW}提示: 打开 WSL2 Ubuntu 终端的方式:${NC}"
        echo -e "  ${GRAY}在 Windows 搜索栏中搜索 Ubuntu，或运行: wsl -d Ubuntu-22.04${NC}"
        echo ""
    else
        # 在 WSL 中运行 onboard（交互式，需要 TTY）
        echo ""
        log_step "在 WSL2 中运行配置向导..."
        echo -e "${YELLOW}即将进入 WSL2 运行 onboard 向导，请按提示操作${NC}"
        echo ""
        wsl.exe bash -ic "openclaw onboard --install-daemon" 2>/dev/null || true
    fi

    print_step_done "7/7" "WSL2 安装和配置流程完成"

    # 显示 WSL2 后续使用指南
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}           🎉 WSL2 安装完成！${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}📖 Windows 下使用 WSL2 中的 OpenClaw:${NC}"
    echo ""
    echo -e "  ${CYAN}# 进入 WSL2 Ubuntu 终端${NC}"
    echo -e "  ${WHITE}wsl -d Ubuntu-22.04${NC}"
    echo ""
    echo -e "  ${CYAN}# 启动 Gateway 服务${NC}"
    echo -e "  ${WHITE}openclaw gateway --port 18789 --verbose${NC}"
    echo ""
    echo -e "  ${CYAN}# 在 Windows 浏览器访问控制面板${NC}"
    echo -e "  ${WHITE}http://localhost:18789${NC}"
    echo ""
    echo -e "  ${CYAN}# 查看状态 / 诊断问题${NC}"
    echo -e "  ${WHITE}openclaw status${NC}"
    echo -e "  ${WHITE}openclaw doctor${NC}"
    echo ""
    echo -e "${GRAY}提示: 可以创建 Windows 快捷方式来快速启动:${NC}"
    echo -e "${GRAY}  创建 .bat 文件，内容为:${NC}"
    echo -e "${GRAY}  wsl -d Ubuntu-22.04 -u root -- bash -c \"openclaw gateway --port 18789\"${NC}"
    echo ""
}

# ================================ OpenClaw 安装 ================================

create_directories() {
    log_step "创建配置目录..."
    
    mkdir -p "$CONFIG_DIR"
    
    log_info "配置目录: $CONFIG_DIR"
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
    
    # 使用 npm 全局安装（带自动错误修复）
    log_info "正在从 npm 安装 OpenClaw..."
    if safe_npm_install "openclaw@$OPENCLAW_VERSION"; then
        # 验证安装
        if check_command openclaw; then
            log_info "OpenClaw 安装成功: $(openclaw --version 2>/dev/null || echo 'installed')"
            init_openclaw_config
        else
            log_warn "npm 安装成功但 openclaw 命令不可用"
            echo -e "${YELLOW}尝试修复 PATH:${NC}"
            local npm_prefix
            npm_prefix=$(npm config get prefix 2>/dev/null) || true
            if [ -n "$npm_prefix" ]; then
                export PATH="$npm_prefix/bin:$PATH"
                log_info "已添加 $npm_prefix/bin 到 PATH"
            fi
            if check_command openclaw; then
                log_info "OpenClaw 安装成功: $(openclaw --version 2>/dev/null || echo 'installed')"
                init_openclaw_config
            else
                log_error "OpenClaw 安装完成但命令不可用，请检查 PATH"
                echo -e "  ${CYAN}export PATH=\"$(npm config get prefix 2>/dev/null)/bin:\$PATH\"${NC}"
                exit 1
            fi
        fi
    else
        log_error "OpenClaw 安装失败"
        echo -e "${YELLOW}可以手动安装后重新运行脚本:${NC}"
        echo -e "  ${CYAN}npm install -g openclaw@latest${NC}"
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

    # 规范化模型名称（避免用户输入 deepseek/deepseek-chat 这种带前缀写法）
    if [ "$AI_PROVIDER" = "deepseek" ]; then
        AI_MODEL="${AI_MODEL#deepseek/}"
    fi

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
        kimi)
            echo "export MOONSHOT_API_KEY=$AI_KEY" >> "$env_file"
            echo "export MOONSHOT_BASE_URL=${BASE_URL:-https://api.moonshot.cn/v1}" >> "$env_file"
            ;;
        google)
            echo "export GOOGLE_API_KEY=$AI_KEY" >> "$env_file"
            [ -n "$BASE_URL" ] && echo "export GOOGLE_BASE_URL=$BASE_URL" >> "$env_file"
            ;;
        groq)
            echo "export OPENAI_API_KEY=$AI_KEY" >> "$env_file"
            echo "export OPENAI_BASE_URL=${BASE_URL:-https://api.groq.com/openai/v1}" >> "$env_file"
            ;;
        mistral)
            echo "export OPENAI_API_KEY=$AI_KEY" >> "$env_file"
            echo "export OPENAI_BASE_URL=${BASE_URL:-https://api.mistral.ai/v1}" >> "$env_file"
            ;;
        openrouter)
            echo "export OPENAI_API_KEY=$AI_KEY" >> "$env_file"
            echo "export OPENAI_BASE_URL=${BASE_URL:-https://openrouter.ai/api/v1}" >> "$env_file"
            ;;
        ollama)
            echo "export OLLAMA_HOST=${BASE_URL:-http://localhost:11434}" >> "$env_file"
            ;;
        custom)
            # 自定义 API: 根据 API 格式设置环境变量
            case "$AI_API_TYPE" in
                anthropic-messages)
                    echo "export ANTHROPIC_API_KEY=$AI_KEY" >> "$env_file"
                    echo "export ANTHROPIC_BASE_URL=$BASE_URL" >> "$env_file"
                    ;;
                *)
                    echo "export OPENAI_API_KEY=$AI_KEY" >> "$env_file"
                    echo "export OPENAI_BASE_URL=$BASE_URL" >> "$env_file"
                    ;;
            esac
            ;;
    esac
    
    chmod 600 "$env_file"
    log_info "环境变量配置已保存到: $env_file"
    
    # 设置默认模型
    if check_command openclaw; then
        local openclaw_model=""
        local use_custom_provider=false
        
        # 自定义 API 或带自定义 BASE_URL 的 provider
        if [ "$AI_PROVIDER" = "custom" ]; then
            use_custom_provider=true
            configure_custom_provider "${CUSTOM_PROVIDER_NAME:-custom-api}" "$AI_KEY" "$AI_MODEL" "$BASE_URL" "$openclaw_json" "$AI_API_TYPE" "$EXTRA_MODELS"
            openclaw_model="${CUSTOM_PROVIDER_NAME:-custom-api}-custom/$AI_MODEL"
        elif [ -n "$BASE_URL" ] && [ "$AI_PROVIDER" = "anthropic" ]; then
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
                openai|groq|mistral)
                    openclaw_model="openai/$AI_MODEL"
                    ;;
                deepseek)
                    openclaw_model="deepseek/$AI_MODEL"
                    ;;
                kimi)
                    openclaw_model="kimi/$AI_MODEL"
                    ;;
                openrouter)
                    openclaw_model="openrouter/$AI_MODEL"
                    ;;
                google)
                    openclaw_model="google/$AI_MODEL"
                    ;;
                ollama)
                    openclaw_model="ollama/$AI_MODEL"
                    ;;
            esac
        fi
        
        if [ -n "$openclaw_model" ]; then
            # 加载环境变量
            source "$env_file"
            
            # 设置默认模型（显示错误信息以便调试）
            # 添加 || true 防止 set -e 导致脚本退出
            local set_result
            set_result=$(openclaw models set "$openclaw_model" 2>&1) || true
            local set_exit=$?
            
            if [ $set_exit -eq 0 ]; then
                log_info "默认模型已设置为: $openclaw_model"
            else
                log_warn "模型设置可能失败: $openclaw_model"
                echo -e "  ${GRAY}$set_result${NC}" | head -3
                
                # 尝试直接使用 config set
                log_info "尝试使用 config set 设置模型..."
                openclaw config set models.default "$openclaw_model" 2>/dev/null || true
            fi
        fi
    fi
    
    # 添加到 shell 配置文件
    add_env_to_shell "$env_file"
}

# 配置自定义 provider（用于支持自定义 API 地址）
# 参数: provider api_key model base_url config_file [api_type] [extra_models_csv]
configure_custom_provider() {
    local provider="$1"
    local api_key="$2"
    local model="$3"
    local base_url="$4"
    local config_file="$5"
    local custom_api_type="$6"  # 可选参数，用于覆盖默认 API 类型
    local custom_extra_models="$7"  # 可选参数，逗号分隔附加模型
    
    # 参数校验
    if [ -z "$model" ]; then
        log_error "模型名称不能为空"
        return 0  # 返回 0 防止 set -e 退出
    fi
    
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空"
        return 0
    fi
    
    if [ -z "$base_url" ]; then
        log_error "API 地址不能为空"
        return 0
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
    "extra_models": "$custom_extra_models",
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

// 组装模型列表（主模型 + 附加模型）
const models = [
    {
        id: vars.model,
        name: vars.model,
        api: vars.api_type,
        input: ['text','image'],
        contextWindow: 200000,
        maxTokens: 8192
    }
];

if (vars.extra_models) {
    const extra = vars.extra_models
        .split(',')
        .map(s => s.trim())
        .filter(Boolean)
        .filter(m => m !== vars.model);
    for (const m of extra) {
        models.push({
            id: m,
            name: m,
            api: vars.api_type,
            input: ['text','image'],
            contextWindow: 200000,
            maxTokens: 8192
        });
    }
}

// 添加自定义 provider
config.models.providers[vars.provider_id] = {
    baseUrl: vars.base_url,
    apiKey: vars.api_key,
    models: models
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
    "extra_models": "$custom_extra_models",
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

models = [
    {
        'id': vars['model'],
        'name': vars['model'],
        'api': vars['api_type'],
        'input': ['text','image'],
        'contextWindow': 200000,
        'maxTokens': 8192
    }
]

if vars.get('extra_models'):
    for m in [x.strip() for x in vars['extra_models'].split(',') if x.strip()]:
        if m != vars['model']:
            models.append({
                'id': m,
                'name': m,
                'api': vars['api_type'],
                'input': ['text','image'],
                'contextWindow': 200000,
                'maxTokens': 8192
            })

config['models']['providers'][vars['provider_id']] = {
    'baseUrl': vars['base_url'],
    'apiKey': vars['api_key'],
    'models': models
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

# 规范化 DeepSeek API 地址: 允许传入 /v1/chat/completions，自动转为 /v1
normalize_deepseek_base_url() {
    local raw_url="$1"

    if [ -z "$raw_url" ]; then
        echo "https://api.deepseek.com/v1"
        return 0
    fi

    if echo "$raw_url" | grep -q "/chat/completions"; then
        echo "${raw_url%/chat/completions}"
    else
        echo "$raw_url"
    fi
}

# 自动应用 DeepSeek 预置
apply_deepseek_preset() {
    AI_PROVIDER="custom"
    CUSTOM_PROVIDER_NAME="deepseek"
    AI_KEY="$DEEPSEEK_PRESET_API_KEY"
    BASE_URL="$(normalize_deepseek_base_url "$DEEPSEEK_PRESET_BASE_URL")"
    AI_MODEL="$DEEPSEEK_PRESET_DEFAULT_MODEL"
    EXTRA_MODELS="$DEEPSEEK_PRESET_EXTRA_MODELS"
    AI_API_TYPE="openai-completions"

    log_info "已自动应用 DeepSeek 预置配置"
    echo -e "  提供商: ${WHITE}deepseek(custom)${NC}"
    echo -e "  地址: ${WHITE}${BASE_URL}${NC}"
    echo -e "  默认模型: ${WHITE}${AI_MODEL}${NC}"
    echo -e "  附加模型: ${WHITE}${EXTRA_MODELS}${NC}"
}

# ================================ 配置向导 ================================

# create_default_config 已移除 - OpenClaw 使用 openclaw.json 和环境变量

run_onboard_wizard() {
    log_step "运行配置向导..."

    if check_command openclaw; then
        if confirm "是否优先使用官方向导 openclaw onboard --install-daemon？(推荐)" "y"; then
            echo ""
            log_step "启动官方向导..."
            openclaw onboard --install-daemon
            local onboard_exit=$?
            if [ $onboard_exit -eq 0 ]; then
                log_info "官方向导执行完成"
                return 0
            else
                log_warn "官方向导返回异常 (exit: $onboard_exit)，将回退到内置向导"
            fi
        fi
    fi
    
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
                # 获取当前模型
                AI_MODEL=$(openclaw config get models.default 2>/dev/null | sed 's|.*/||')
                if [ -n "$ANTHROPIC_API_KEY" ]; then
                    AI_PROVIDER="anthropic"
                    AI_KEY="$ANTHROPIC_API_KEY"
                    BASE_URL="$ANTHROPIC_BASE_URL"
                elif [ -n "$OPENAI_API_KEY" ]; then
                    AI_PROVIDER="openai"
                    AI_KEY="$OPENAI_API_KEY"
                    BASE_URL="$OPENAI_BASE_URL"
                elif [ -n "$GOOGLE_API_KEY" ]; then
                    AI_PROVIDER="google"
                    AI_KEY="$GOOGLE_API_KEY"
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
        echo "  4. 设置基本身份信息"
        echo ""
    fi
    
    # AI 配置
    if [ "$skip_ai_config" = false ]; then
        if [ "$AUTO_USE_DEEPSEEK_PRESET" = "true" ]; then
            apply_deepseek_preset
        else
            setup_ai_provider
        fi
        # 先配置 OpenClaw（设置环境变量和自定义 provider），然后再测试
        configure_openclaw_model
        test_api_connection
    else
        # 即使跳过配置，也可选择测试连接
        if confirm "是否测试现有 API 连接？" "y"; then
            test_api_connection
        fi
    fi
    
    # 身份配置
    if [ "$skip_identity_config" = false ]; then
        setup_identity
    else
        # 初始化渠道配置变量
        TELEGRAM_ENABLED="false"
        DISCORD_ENABLED="false"
        SHELL_ENABLED="false"
        FILE_ACCESS="false"
    fi
    
    log_info "核心配置完成！"
}

# ================================ AI Provider 配置 ================================

setup_ai_provider() {
    # 重置可选参数，避免上一次流程残留
    AI_API_TYPE=""
    EXTRA_MODELS=""

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  第 1 步: 选择 AI 模型提供商${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  1) 🟣 Anthropic Claude"
    echo "  2) 🟢 OpenAI GPT"
    echo "  3) 🔵 DeepSeek"
    echo "  4) 🌙 Kimi (Moonshot)"
    echo "  5) 🔴 Google Gemini"
    echo "  6) 🔄 OpenRouter (多模型网关)"
    echo "  7) ⚡ Groq (超快推理)"
    echo "  8) 🌬️ Mistral AI"
    echo "  9) 🟠 Ollama (本地模型)"
    echo " 10) 🔧 自定义 API (兼容 OpenAI/Anthropic 格式)"
    echo ""
    echo -e "${GRAY}提示: 选择 10 可接入任意兼容 OpenAI 或 Anthropic 格式的第三方 API 服务${NC}"
    echo ""
    echo -en "${YELLOW}请选择 AI 提供商 [1-10] (默认: 1): ${NC}"; read ai_choice < "$TTY_INPUT"
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
            echo -en "${YELLOW}输入 API Key: ${NC}"; read AI_KEY < "$TTY_INPUT"
            echo ""
            echo "选择模型:"
            echo "  1) claude-sonnet-4-5-20250929 (推荐)"
            echo "  2) claude-opus-4-5-20251101 (最强)"
            echo "  3) claude-haiku-4-5-20251001 (快速)"
            echo "  4) claude-sonnet-4-20250514 (上一代)"
            echo "  5) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-5] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="claude-opus-4-5-20251101" ;;
                3) AI_MODEL="claude-haiku-4-5-20251001" ;;
                4) AI_MODEL="claude-sonnet-4-20250514" ;;
                5) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="claude-sonnet-4-5-20250929" ;;
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
            echo -en "${YELLOW}输入 API Key: ${NC}"; read AI_KEY < "$TTY_INPUT"
            echo ""
            echo "选择模型:"
            echo "  1) gpt-5 (推荐)"
            echo "  2) gpt-5-mini (经济)"
            echo "  3) gpt-4o"
            echo "  4) gpt-4o-mini"
            echo "  5) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-5] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="gpt-5-mini" ;;
                3) AI_MODEL="gpt-4o" ;;
                4) AI_MODEL="gpt-4o-mini" ;;
                5) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="gpt-5" ;;
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
            echo -en "${YELLOW}输入 API Key: ${NC}"; read AI_KEY < "$TTY_INPUT"
            echo ""
            echo "选择模型:"
            echo "  1) deepseek-chat (推荐)"
            echo "  2) deepseek-reasoner (推理增强)"
            echo "  3) deepseek-coder (代码专用)"
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
            AI_PROVIDER="kimi"
            echo ""
            echo -e "${CYAN}配置 Kimi (Moonshot)${NC}"
            echo -e "${GRAY}官方 API: https://platform.moonshot.cn/${NC}"
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方 API): ${NC}"; read BASE_URL < "$TTY_INPUT"
            BASE_URL=${BASE_URL:-"https://api.moonshot.cn/v1"}
            echo ""
            echo -en "${YELLOW}输入 API Key: ${NC}"; read AI_KEY < "$TTY_INPUT"
            echo ""
            echo "选择模型:"
            echo "  1) moonshot-v1-auto (自动, 推荐)"
            echo "  2) moonshot-v1-8k"
            echo "  3) moonshot-v1-32k"
            echo "  4) moonshot-v1-128k"
            echo "  5) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-5] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="moonshot-v1-8k" ;;
                3) AI_MODEL="moonshot-v1-32k" ;;
                4) AI_MODEL="moonshot-v1-128k" ;;
                5) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="moonshot-v1-auto" ;;
            esac
            ;;
        5)
            AI_PROVIDER="google"
            echo ""
            echo -e "${CYAN}配置 Google Gemini${NC}"
            echo -e "${GRAY}获取 API Key: https://aistudio.google.com/apikey${NC}"
            echo ""
            echo -en "${YELLOW}输入 API Key: ${NC}"; read AI_KEY < "$TTY_INPUT"
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方): ${NC}"; read BASE_URL < "$TTY_INPUT"
            echo ""
            echo "选择模型:"
            echo "  1) gemini-2.5-flash (推荐)"
            echo "  2) gemini-2.5-pro"
            echo "  3) gemini-2.0-flash"
            echo "  4) 自定义"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="gemini-2.5-pro" ;;
                3) AI_MODEL="gemini-2.0-flash" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="gemini-2.5-flash" ;;
            esac
            ;;
        6)
            AI_PROVIDER="openrouter"
            echo ""
            echo -e "${CYAN}配置 OpenRouter${NC}"
            echo -e "${GRAY}获取 API Key: https://openrouter.ai/${NC}"
            echo ""
            echo -en "${YELLOW}输入 API Key: ${NC}"; read AI_KEY < "$TTY_INPUT"
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方): ${NC}"; read BASE_URL < "$TTY_INPUT"
            BASE_URL=${BASE_URL:-"https://openrouter.ai/api/v1"}
            echo ""
            echo "选择模型:"
            echo "  1) anthropic/claude-sonnet-4-5 (推荐)"
            echo "  2) openai/gpt-5"
            echo "  3) google/gemini-2.5-flash"
            echo "  4) 自定义"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="openai/gpt-5" ;;
                3) AI_MODEL="google/gemini-2.5-flash" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="anthropic/claude-sonnet-4-5" ;;
            esac
            ;;
        7)
            AI_PROVIDER="groq"
            echo ""
            echo -e "${CYAN}配置 Groq${NC}"
            echo -e "${GRAY}获取 API Key: https://console.groq.com/${NC}"
            echo ""
            echo -en "${YELLOW}输入 API Key: ${NC}"; read AI_KEY < "$TTY_INPUT"
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
            echo -en "${YELLOW}输入 API Key: ${NC}"; read AI_KEY < "$TTY_INPUT"
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
            AI_PROVIDER="custom"
            CUSTOM_PROVIDER_NAME=""
            echo ""
            echo -e "${CYAN}配置自定义 API${NC}"
            echo -e "${GRAY}支持任何兼容 OpenAI 或 Anthropic 格式的 API 服务${NC}"
            echo -e "${GRAY}如: OneAPI, NewAPI, FastGPT, 各类中转服务等${NC}"
            echo ""
            echo -en "${YELLOW}Provider 名称 (用于标识, 如 my-api): ${NC}"; read CUSTOM_PROVIDER_NAME < "$TTY_INPUT"
            CUSTOM_PROVIDER_NAME=${CUSTOM_PROVIDER_NAME:-"custom-api"}
            echo ""
            echo -en "${YELLOW}API 地址 (如 https://api.example.com/v1): ${NC}"; read BASE_URL < "$TTY_INPUT"
            if [ -z "$BASE_URL" ]; then
                log_error "API 地址不能为空"
                echo -e "${YELLOW}请重新运行配置向导${NC}"
                return 1
            fi
            echo ""
            echo -en "${YELLOW}API Key: ${NC}"; read AI_KEY < "$TTY_INPUT"
            echo ""
            echo -en "${YELLOW}模型名称 (如 gpt-4o, claude-3-sonnet, deepseek-chat 等): ${NC}"; read AI_MODEL < "$TTY_INPUT"
            if [ -z "$AI_MODEL" ]; then
                log_error "模型名称不能为空"
                return 1
            fi
            echo ""
            echo -e "${CYAN}选择 API 兼容格式:${NC}"
            echo "  1) openai-completions (兼容 /v1/chat/completions，最通用)"
            echo "  2) openai-responses (OpenAI Responses API)"
            echo "  3) anthropic-messages (Anthropic Messages API)"
            echo -e "${GRAY}提示: 大多数第三方中转服务使用 openai-completions 格式${NC}"
            echo -en "${YELLOW}选择格式 [1-3] (默认: 1): ${NC}"; read api_format_choice < "$TTY_INPUT"
            case $api_format_choice in
                2) AI_API_TYPE="openai-responses" ;;
                3) AI_API_TYPE="anthropic-messages" ;;
                *) AI_API_TYPE="openai-completions" ;;
            esac
            ;;
        *)
            # 默认使用 Anthropic
            AI_PROVIDER="anthropic"
            echo ""
            echo -e "${CYAN}配置 Anthropic Claude${NC}"
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方): ${NC}"; read BASE_URL < "$TTY_INPUT"
            echo -en "${YELLOW}输入 API Key: ${NC}"; read AI_KEY < "$TTY_INPUT"
            AI_MODEL="claude-sonnet-4-20250514"
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
    local max_retries=3
    local retry_count=0
    
    # 确保环境变量已加载
    local env_file="$HOME/.openclaw/env"
    [ -f "$env_file" ] && source "$env_file"
    
    if ! check_command openclaw; then
        echo -e "${YELLOW}OpenClaw 未安装，跳过测试${NC}"
        return 0
    fi
    
    # 显示当前模型配置
    echo -e "${CYAN}当前模型配置:${NC}"
    openclaw models status 2>&1 | grep -E "Default|Auth|effective" | head -5
    echo ""
    
    while [ "$test_passed" = false ] && [ $retry_count -lt $max_retries ]; do
        echo -e "${YELLOW}运行 openclaw agent --local 测试...${NC}"
        echo ""
        
        # 使用 openclaw agent --local 测试（添加超时）
        local result
        local exit_code
        
        # 使用 timeout 命令（如果可用），否则直接运行
        # 注意：添加 || true 防止 set -e 导致脚本退出
        if command -v timeout &> /dev/null; then
            result=$(timeout 30 openclaw agent --local --to "+1234567890" --message "回复 OK" 2>&1) || true
            exit_code=${PIPESTATUS[0]}
            # 如果 exit_code 为空，从 $? 获取（兼容不同 shell）
            [ -z "$exit_code" ] && exit_code=$?
            if [ "$exit_code" = "124" ]; then
                result="测试超时（30秒）"
            fi
        else
            result=$(openclaw agent --local --to "+1234567890" --message "回复 OK" 2>&1) || true
            exit_code=$?
        fi
        
        # 过滤掉 Node.js 警告信息和正常的系统日志
        result=$(echo "$result" | grep -v "ExperimentalWarning" | grep -v "at emitExperimentalWarning" | grep -v "at ModuleLoader" | grep -v "at callTranslator")
        
        # 保存原始结果用于显示
        local display_result="$result"
        
        # 过滤掉正常的插件加载日志和 Doctor warnings 用于错误判断
        local filtered_result=$(echo "$result" | grep -v "\[plugins\]" | grep -v "Doctor warnings" | grep -v "Registered.*tools" | grep -v "State dir migration" | grep -v "^│" | grep -v "^◇" | grep -v "^$")
        
        # 检查结果是否为空
        if [ -z "$filtered_result" ]; then
            # 如果过滤后为空，但原始结果不为空，可能只是系统日志
            if [ -n "$display_result" ]; then
                # 检查是否有实际的 AI 响应内容（不是日志）
                if echo "$display_result" | grep -qE "^[^│◇\[\]]"; then
                    filtered_result="$display_result"
                else
                    filtered_result="(只有系统日志，没有 AI 响应)"
                    exit_code=1
                fi
            else
                filtered_result="(无输出 - 命令可能立即退出)"
                exit_code=1
            fi
        fi
        
        # 判断是否成功：退出码为 0 且没有真正的错误信息
        # 注意：只匹配真正的错误，排除正常日志
        if [ $exit_code -eq 0 ] && ! echo "$filtered_result" | grep -qiE "^error:|api error|401|403|Unknown model|超时|Incorrect API|authentication failed"; then
            test_passed=true
            echo -e "${GREEN}✓ OpenClaw AI 测试成功！${NC}"
            echo ""
            # 显示 AI 响应（过滤掉空行和系统日志）
            local ai_response=$(echo "$display_result" | grep -v "^$" | grep -v "\[plugins\]" | grep -v "Doctor" | grep -v "^│" | grep -v "^◇" | head -5)
            if [ -n "$ai_response" ]; then
                echo -e "  ${CYAN}AI 响应:${NC}"
                echo "$ai_response" | sed 's/^/    /'
            fi
        else
            retry_count=$((retry_count + 1))
            echo -e "${RED}✗ OpenClaw AI 测试失败 (退出码: $exit_code)${NC}"
            echo ""
            
            # 显示过滤后的错误信息（排除正常日志）
            local error_display=$(echo "$filtered_result" | head -5)
            if [ -n "$error_display" ] && [ "$error_display" != "(只有系统日志，没有 AI 响应)" ]; then
                echo -e "  ${RED}错误信息:${NC}"
                echo "$error_display" | sed 's/^/    /'
            else
                echo -e "  ${YELLOW}没有收到 AI 响应，可能是 API 配置问题${NC}"
            fi
            echo ""
            
            # 显示完整原始输出（用于调试）
            if [ -n "$display_result" ]; then
                echo -e "  ${GRAY}完整输出 (前 8 行):${NC}"
                echo "$display_result" | head -8 | sed 's/^/    /'
                echo ""
            fi
            
            if [ $retry_count -lt $max_retries ]; then
                echo -e "${YELLOW}剩余 $((max_retries - retry_count)) 次机会${NC}"
                echo ""
                
                # 提供修复建议
                if echo "$filtered_result" | grep -qi "Unknown model"; then
                    echo -e "${YELLOW}提示: 模型不被识别，建议运行: openclaw configure --section model${NC}"
                elif echo "$filtered_result" | grep -qi "401\|Incorrect API key\|authentication"; then
                    echo -e "${YELLOW}提示: API Key 可能不正确${NC}"
                elif echo "$filtered_result" | grep -qi "只有系统日志"; then
                    echo -e "${YELLOW}提示: API 可能没有正确响应，请检查 API 地址和模型名称${NC}"
                fi
                echo ""
                
                if confirm "是否重新配置 AI Provider？" "y"; then
                    setup_ai_provider
                    configure_openclaw_model
                else
                    echo -e "${YELLOW}继续使用当前配置...${NC}"
                    test_passed=true  # 允许跳过
                fi
            fi
        fi
    done
    
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
ExecStart=$(which openclaw) start --daemon
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
        <string>start</string>
        <string>--daemon</string>
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
    echo -e "${CYAN}常用命令及说明:${NC}"
    echo -e "  ${WHITE}openclaw gateway start${NC}   ${GRAY}# 后台启动 Gateway 服务，开始接收消息${NC}"
    echo -e "  ${WHITE}openclaw gateway stop${NC}    ${GRAY}# 停止 Gateway 服务${NC}"
    echo -e "  ${WHITE}openclaw gateway status${NC}  ${GRAY}# 查看 Gateway 运行状态和端口信息${NC}"
    echo -e "  ${WHITE}openclaw models status${NC}   ${GRAY}# 查看当前 AI 模型配置和连接状态${NC}"
    echo -e "  ${WHITE}openclaw channels list${NC}   ${GRAY}# 查看已配置的消息渠道 (飞书/TG/Discord等)${NC}"
    echo -e "  ${WHITE}openclaw doctor${NC}          ${GRAY}# 全面诊断：检查配置、依赖、网络连接${NC}"
    echo -e "  ${WHITE}openclaw onboard${NC}         ${GRAY}# 重新运行配置向导${NC}"
    echo ""
    echo -e "${PURPLE}📚 官方文档: https://docs.openclaw.ai/${NC}"
    echo -e "${PURPLE}📚 中文社区: https://clawd.org.cn/start/getting-started${NC}"
    echo -e "${PURPLE}💬 Discord 社区: https://discord.gg/clawd${NC}"
    echo -e "${PURPLE}💬 GitHub 讨论: https://github.com/$GITHUB_REPO/discussions${NC}"
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
    existing_pid=$(get_port_pid 18789)
    if [ -n "$existing_pid" ]; then
        log_warn "OpenClaw Gateway 已在运行 (PID: $existing_pid)"
        echo ""
        show_dashboard_access_hint
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
    gateway_pid=$(get_port_pid 18789)
    if [ -n "$gateway_pid" ]; then
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}           ✓ OpenClaw Gateway 已启动！(PID: $gateway_pid)${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${CYAN}查看状态:${NC} openclaw gateway status"
        echo -e "  ${CYAN}查看日志:${NC} tail -f /tmp/openclaw-gateway.log"
        echo -e "  ${CYAN}停止服务:${NC} openclaw gateway stop"
        show_dashboard_access_hint
        echo ""
        log_info "OpenClaw 现在可以接收消息了！"
    else
        log_error "Gateway 启动失败"
        local gw_log
        gw_log=$(cat /tmp/openclaw-gateway.log 2>/dev/null | tail -20) || true
        if [ -n "$gw_log" ]; then
            echo -e "${GRAY}日志摘要:${NC}"
            echo "$gw_log" | tail -5 | sed 's/^/  /'
            echo ""
            if diagnose_and_fix "$gw_log" "gateway start"; then
                log_info "已尝试自动修复，请手动重启服务"
            fi
        fi
        echo ""
        echo -e "${YELLOW}请查看日志: ${CYAN}tail -f /tmp/openclaw-gateway.log${NC}"
        echo -e "${YELLOW}或手动启动: ${CYAN}source ~/.openclaw/env && openclaw gateway${NC}"
    fi
}

# 下载并运行配置菜单
run_config_menu() {
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
            if curl -fsSL "$GITHUB_RAW_URL/config-menu.sh" -o "$config_menu_path.tmp"; then
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
        if curl -fsSL "$GITHUB_RAW_URL/config-menu.sh" -o "$config_menu_path.tmp"; then
            mv "$config_menu_path.tmp" "$config_menu_path"
            chmod +x "$config_menu_path"
            log_info "配置菜单已下载: $config_menu_path"
            menu_script="$config_menu_path"
        else
            rm -f "$config_menu_path.tmp" 2>/dev/null
            log_error "配置菜单下载失败"
            echo -e "${YELLOW}你可以稍后手动下载运行:${NC}"
            echo "  curl -fsSL $GITHUB_RAW_URL/config-menu.sh -o config-menu.sh && bash config-menu.sh"
            return 1
        fi
    fi
    
    # 确保有执行权限
    chmod +x "$menu_script" 2>/dev/null || true
    
    # 启动配置菜单（使用 /dev/tty 确保交互正常）
    echo ""
    if [ -e /dev/tty ]; then
        bash "$menu_script" < /dev/tty
    else
        bash "$menu_script"
    fi
    return $?
}

# ================================ 主函数 ================================

main() {
    print_banner
    
    echo -e "${YELLOW}⚠️  警告: OpenClaw 需要完全的计算机权限${NC}"
    echo -e "${YELLOW}    不建议在主要工作电脑上安装，建议使用专用服务器或虚拟机${NC}"
    echo ""
    
    if ! confirm "是否继续安装？"; then
        echo "安装已取消"
        exit 0
    fi
    
    echo ""

    # ===== 步骤 1: 检测操作系统 =====
    print_next_step "1/6" "检测操作系统" "" "自动识别系统类型和包管理器"
    detect_os
    print_step_done "1/6" "操作系统检测完成 (${OS})"

    # ===== 步骤 2: 检查最新版本 =====
    print_next_step "2/6" "检查 OpenClaw 最新版本" "npm view openclaw version" "确保安装最新稳定版"
    check_latest_version
    print_step_done "2/6" "版本信息获取完成"

    # Windows 系统走专用安装分支
    if [ "$OS" = "windows" ]; then
        case "$WINDOWS_MODE" in
            native)
                install_windows_native
                # Windows native 完成后使用本脚本自带的向导
                run_onboard_wizard
                print_success

                # 启动服务
                local native_running_pid
                native_running_pid=$(get_port_pid 18789)
                if [ -n "$native_running_pid" ]; then
                    log_info "检测到 Gateway 已运行 (PID: $native_running_pid)，跳过重复启动"
                    show_dashboard_access_hint
                elif confirm "是否现在启动 OpenClaw 服务？" "y"; then
                    start_openclaw_service
                else
                    echo ""
                    echo -e "${CYAN}稍后可以通过以下命令启动服务:${NC}"
                    echo "  openclaw gateway --port 18789 --verbose"
                    echo ""
                    echo -e "${CYAN}然后在浏览器访问:${NC}"
                    echo "  http://localhost:18789"
                    echo ""
                fi

                # 显示后续操作提示
                print_windows_next_steps "native"
                ;;
            wsl2)
                install_windows_wsl2
                # WSL2 流程自带完整提示，直接结束
                print_windows_next_steps "wsl2"
                ;;
        esac

        echo ""
        echo -e "${GREEN}🦞 OpenClaw 安装完成！祝你使用愉快！${NC}"
        echo ""
        return 0
    fi

    # ===== Linux/macOS 标准安装流程 =====

    # ===== 步骤 3: 安装依赖 =====
    print_next_step "3/6" "检查并安装依赖" "" "安装 Git、Node.js 等必要运行环境"
    check_root
    install_dependencies
    print_step_done "3/6" "所有依赖已就绪"

    # ===== 步骤 4: 安装 OpenClaw =====
    print_next_step "4/6" "安装 OpenClaw" "npm install -g openclaw@${OPENCLAW_VERSION}" "安装 OpenClaw 核心程序"
    create_directories
    install_openclaw
    print_step_done "4/6" "OpenClaw 安装完成"

    # ===== 步骤 5: 配置向导 =====
    print_next_step "5/6" "运行配置向导" "" "配置 AI 模型、身份信息、API 连接"
    run_onboard_wizard
    print_step_done "5/6" "核心配置完成"

    # ===== 步骤 6: 服务管理 =====
    print_next_step "6/6" "启动服务和配置开机自启" "openclaw gateway start" "启动 OpenClaw Gateway 并设置为守护进程"
    setup_daemon
    print_success
    
    # 询问是否启动服务
    local running_pid
    running_pid=$(get_port_pid 18789)
    if [ -n "$running_pid" ]; then
        log_info "检测到 Gateway 已运行 (PID: $running_pid)，跳过重复启动"
        show_dashboard_access_hint
    elif confirm "是否现在启动 OpenClaw 服务？" "y"; then
        start_openclaw_service
    else
        echo ""
        echo -e "${CYAN}稍后可以通过以下命令启动服务:${NC}"
        echo "  source ~/.openclaw/env && openclaw gateway"
        echo ""
    fi
    print_step_done "6/6" "服务配置完成"
    
    # 推荐仓库入口
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           📦 推荐：OpenClawInstaller 维护仓库${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}获取最新脚本、文档和问题反馈入口：${NC}"
    echo ""
    echo -e "  🔧 ${CYAN}安装脚本${NC} - 一键安装与自动修复"
    echo -e "  🧭 ${CYAN}配置菜单${NC} - AI 模型与渠道管理"
    echo -e "  💻 ${CYAN}跨平台${NC} - 支持 macOS、Windows、Linux"
    echo -e "  🐞 ${CYAN}问题反馈${NC} - GitHub Issues / Discussions"
    echo ""
    echo -e "  👉 ${PURPLE}下载地址: https://github.com/MarcusDog/OpenClawInstaller${NC}"
    echo ""
    
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

    # 显示后续操作指南
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           📖 后续操作指南${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}  1. 查看服务状态:${NC}"
    echo -e "     ${CYAN}openclaw gateway status${NC}"
    echo -e "     ${GRAY}目的: 确认 Gateway 是否运行正常${NC}"
    echo ""
    echo -e "${WHITE}  2. 运行诊断:${NC}"
    echo -e "     ${CYAN}openclaw doctor${NC}"
    echo -e "     ${GRAY}目的: 检查配置、依赖和连接问题${NC}"
    echo ""
    echo -e "${WHITE}  3. 配置消息渠道 (如飞书、Telegram、Discord):${NC}"
    echo -e "     ${CYAN}bash ./config-menu.sh${NC}"
    echo -e "     ${GRAY}目的: 连接聊天平台，让 AI 助手在多个渠道响应消息${NC}"
    echo ""
    echo -e "${WHITE}  4. 更新 OpenClaw 到最新版本:${NC}"
    echo -e "     ${CYAN}npm update -g openclaw@latest${NC}"
    echo -e "     ${GRAY}目的: 获取最新功能和安全补丁${NC}"
    echo ""
    echo -e "${WHITE}  5. 查看官方文档:${NC}"
    echo -e "     ${PURPLE}https://docs.openclaw.ai/${NC}"
    echo -e "     ${GRAY}目的: 了解高级功能如技能系统、多 Agent、远程网关等${NC}"
    echo ""
    
    echo ""
    echo -e "${GREEN}🦞 OpenClaw 安装完成！祝你使用愉快！${NC}"
    echo ""
}

# Windows 后续操作提示
print_windows_next_steps() {
    local mode="$1"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           📖 后续操作指南 (Windows ${mode})${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [ "$mode" = "native" ]; then
        echo -e "${WHITE}  1. 启动 Gateway 服务:${NC}"
        echo -e "     ${CYAN}openclaw gateway --port 18789 --verbose${NC}"
        echo -e "     ${GRAY}目的: 启动 OpenClaw 服务，开始接收消息${NC}"
        echo ""
        echo -e "${WHITE}  2. 打开 Web 控制面板:${NC}"
        echo -e "     ${CYAN}浏览器访问 http://localhost:18789${NC}"
        echo -e "     ${GRAY}目的: 可视化管理和对话界面${NC}"
        echo ""
        echo -e "${WHITE}  3. 运行诊断:${NC}"
        echo -e "     ${CYAN}openclaw doctor${NC}"
        echo -e "     ${GRAY}目的: 检查环境配置和连接问题${NC}"
        echo ""
        echo -e "${WHITE}  4. 配置消息渠道 (飞书/Telegram/Discord):${NC}"
        echo -e "     ${CYAN}openclaw onboard --install-daemon${NC}"
        echo -e "     ${GRAY}目的: 连接聊天平台，实现多渠道消息接入${NC}"
        echo ""
        echo -e "${WHITE}  5. 日常启动 (下次使用时):${NC}"
        echo -e "     ${CYAN}openclaw gateway --port 18789 --verbose${NC}"
        echo -e "     然后浏览器访问 ${CYAN}http://localhost:18789${NC}"
        echo ""
        echo -e "${YELLOW}提示: 如果 openclaw 命令找不到，需要将 npm 全局路径添加到 PATH:${NC}"
        echo -e "  ${GRAY}通常为: C:\\Users\\<你的用户名>\\AppData\\Roaming\\npm${NC}"
        echo ""
    elif [ "$mode" = "wsl2" ]; then
        echo -e "${WHITE}  1. 进入 WSL2 并启动服务:${NC}"
        echo -e "     ${CYAN}wsl -d Ubuntu-22.04${NC}"
        echo -e "     ${CYAN}openclaw gateway --port 18789 --verbose${NC}"
        echo -e "     ${GRAY}目的: 在 WSL2 中启动 OpenClaw Gateway${NC}"
        echo ""
        echo -e "${WHITE}  2. 打开 Web 控制面板:${NC}"
        echo -e "     ${CYAN}在 Windows 浏览器访问 http://localhost:18789${NC}"
        echo -e "     ${GRAY}目的: WSL2 端口自动转发到 Windows，直接浏览器访问${NC}"
        echo ""
        echo -e "${WHITE}  3. 快速启动 (创建 .bat 文件):${NC}"
        echo -e "     ${GRAY}新建 start-openclaw.bat 文件，内容:${NC}"
        echo -e "     ${CYAN}@echo off${NC}"
        echo -e "     ${CYAN}echo Starting OpenClaw Gateway in WSL2...${NC}"
        echo -e "     ${CYAN}wsl -d Ubuntu-22.04 -- bash -c \"openclaw gateway --port 18789 --verbose\"${NC}"
        echo -e "     ${GRAY}目的: 双击即可启动 OpenClaw 服务${NC}"
        echo ""
        echo -e "${WHITE}  4. 更新 OpenClaw:${NC}"
        echo -e "     ${CYAN}wsl -d Ubuntu-22.04 -- bash -c \"npm update -g openclaw@latest\"${NC}"
        echo -e "     ${GRAY}目的: 获取最新版本和安全补丁${NC}"
        echo ""
        echo -e "${WHITE}  5. 查看官方文档:${NC}"
        echo -e "     ${PURPLE}https://docs.openclaw.ai/${NC}"
        echo ""
    fi
}

# 执行主函数
main "$@"
