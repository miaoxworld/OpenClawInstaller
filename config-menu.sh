#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   🦞 ClawdBot 交互式配置菜单 v1.0.0                                        ║
# ║   便捷的可视化配置工具                                                      ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#

# ================================ TTY 检测 ================================
# 当通过 curl | bash 或被其他脚本调用时，stdin 可能不是终端
# 需要从 /dev/tty 读取用户输入
if [ -t 0 ]; then
    # stdin 是终端
    TTY_INPUT="/dev/stdin"
else
    # stdin 是管道，使用 /dev/tty
    if [ -e /dev/tty ]; then
        TTY_INPUT="/dev/tty"
    else
        echo "错误: 无法获取终端输入，请直接运行此脚本"
        echo "用法: bash config-menu.sh"
        exit 1
    fi
fi

# 统一的读取函数（支持非 TTY 模式）
read_input() {
    local prompt="$1"
    local var_name="$2"
    echo -en "$prompt"
    read $var_name < "$TTY_INPUT"
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
CONFIG_DIR="$HOME/.clawdbot"

# ClawdBot 环境变量配置
CLAWDBOT_ENV="$CONFIG_DIR/env"
CLAWDBOT_JSON="$CONFIG_DIR/clawdbot.json"
BACKUP_DIR="$CONFIG_DIR/backups"

# ================================ 工具函数 ================================

clear_screen() {
    clear
}

print_header() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║   🦞 ClawdBot 配置中心                                         ║
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
    read < "$TTY_INPUT"
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
    if [ -f "$CLAWDBOT_ENV" ]; then
        cp "$CLAWDBOT_ENV" "$backup_file"
        echo "$backup_file"
    fi
}

# 从环境变量文件读取配置
get_env_value() {
    local key=$1
    if [ -f "$CLAWDBOT_ENV" ]; then
        grep "^export $key=" "$CLAWDBOT_ENV" 2>/dev/null | sed 's/.*=//' | tr -d '"'
    fi
}

# ================================ 测试功能 ================================

# 检查 ClawdBot 是否已安装
check_clawdbot_installed() {
    command -v clawdbot &> /dev/null
}

# 重启 Gateway 使渠道配置生效
restart_gateway_for_channel() {
    echo ""
    log_info "正在重启 Gateway..."
    
    # 先尝试停止（隐藏 doctor 输出）
    clawdbot gateway stop > /dev/null 2>&1 || true
    pkill -f "clawdbot.*gateway" 2>/dev/null || true
    sleep 2
    
    # 先运行 doctor --fix 确保配置有效
    echo -e "${YELLOW}检查配置...${NC}"
    yes | clawdbot doctor --fix > /dev/null 2>&1 || true
    
    # 加载环境变量
    if [ -f "$CLAWDBOT_ENV" ]; then
        source "$CLAWDBOT_ENV"
        log_info "已加载环境变量: $CLAWDBOT_ENV"
    fi
    
    # 后台启动 Gateway（使用 setsid 完全脱离终端）
    echo -e "${YELLOW}正在后台启动 Gateway...${NC}"
    
    # 使用 setsid 创建新会话，确保进程完全独立
    if command -v setsid &> /dev/null; then
        if [ -f "$CLAWDBOT_ENV" ]; then
            setsid bash -c "source $CLAWDBOT_ENV && exec clawdbot gateway --port 18789" > /tmp/clawdbot-gateway.log 2>&1 &
        else
            setsid clawdbot gateway --port 18789 > /tmp/clawdbot-gateway.log 2>&1 &
        fi
    else
        # 备用方案：nohup + disown
        if [ -f "$CLAWDBOT_ENV" ]; then
            nohup bash -c "source $CLAWDBOT_ENV && exec clawdbot gateway --port 18789" > /tmp/clawdbot-gateway.log 2>&1 &
        else
            nohup clawdbot gateway --port 18789 > /tmp/clawdbot-gateway.log 2>&1 &
        fi
        disown 2>/dev/null || true
    fi
    
    sleep 3
    
    # 检查是否启动成功
    if pgrep -f "clawdbot.*gateway" > /dev/null 2>&1; then
        log_info "Gateway 已在后台启动！"
        echo ""
        echo -e "${CYAN}查看日志: ${WHITE}tail -f /tmp/clawdbot-gateway.log${NC}"
        echo -e "${CYAN}停止服务: ${WHITE}clawdbot gateway stop${NC}"
    else
        log_warn "Gateway 可能未正常启动"
        echo -e "${YELLOW}请手动启动: source ~/.clawdbot/env && clawdbot gateway${NC}"
    fi
}

# 检查 ClawdBot Gateway 是否运行
check_gateway_running() {
    if check_clawdbot_installed; then
        clawdbot health &>/dev/null
        return $?
    fi
    return 1
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
    
    if ! check_clawdbot_installed; then
        log_error "ClawdBot 未安装"
        return 1
    fi
    
    # 确保环境变量已加载
    [ -f "$CLAWDBOT_ENV" ] && source "$CLAWDBOT_ENV"
    
    # 显示当前模型配置
    echo -e "${CYAN}当前模型配置:${NC}"
    clawdbot models status 2>&1 | grep -E "Default|Auth|effective" | head -5
    echo ""
    
    # 使用 clawdbot agent --local 测试
    echo -e "${YELLOW}运行 clawdbot agent --local 测试...${NC}"
    echo ""
    
    local result
    # 添加 || true 防止命令失败导致函数退出
    result=$(clawdbot agent --local --to "+1234567890" --message "回复 OK" 2>&1) || true
    local exit_code=$?
    
    # 过滤掉 Node.js 警告信息和 JavaScript 错误
    result=$(echo "$result" | grep -v "ExperimentalWarning" | grep -v "at emitExperimentalWarning" | grep -v "at ModuleLoader" | grep -v "at callTranslator" | grep -v "Cannot read properties of undefined" | grep -v "TypeError:" | grep -v "ReferenceError:")
    
    echo ""
    if [ $exit_code -eq 0 ] && ! echo "$result" | grep -qiE "error|failed|401|403|Unknown model"; then
        log_info "ClawdBot AI 测试成功！"
        echo ""
        # 显示 AI 响应（过滤掉空行和无关内容）
        local ai_response=$(echo "$result" | grep -v "^$" | grep -v "^\[" | grep -v "^{" | head -5)
        if [ -n "$ai_response" ]; then
            echo -e "  ${CYAN}AI 响应:${NC}"
            echo "$ai_response" | sed 's/^/    /'
        else
            echo -e "  ${GREEN}✓ API 连接正常${NC}"
        fi
        return 0
    else
        log_error "ClawdBot AI 测试失败"
        echo ""
        echo -e "  ${RED}错误信息:${NC}"
        echo "$result" | head -5 | sed 's/^/    /'
        echo ""
        
        # 提供修复建议
        if echo "$result" | grep -q "Unknown model"; then
            echo -e "${YELLOW}提示: 模型不被 ClawdBot 识别${NC}"
            echo "  运行: clawdbot configure --section model"
        elif echo "$result" | grep -q "401\|Incorrect API key"; then
            echo -e "${YELLOW}提示: API Key 无效或 Base URL 配置不正确${NC}"
            echo "  ClawdBot 可能不支持自定义 API 地址"
            echo "  运行: clawdbot configure --section model"
        fi
        echo ""
        echo "  其他诊断命令:"
        echo "    clawdbot doctor"
        echo "    clawdbot models status"
        return 1
    fi
}

# HTTP 直接测试 (备用)
test_ai_connection_http() {
    local provider=$1
    local api_key=$2
    local model=$3
    local base_url=$4
    
    echo ""
    echo -e "${CYAN}━━━ HTTP 直接测试 ━━━${NC}"
    echo ""
    
    echo -e "${YELLOW}正在测试 API 连接...${NC}"
    echo ""
    
    local test_url=""
    local response=""
    
    case "$provider" in
        anthropic)
            # 如果配置了自定义 base_url，使用 OpenAI 兼容格式
            if [ -n "$base_url" ]; then
                test_url="${base_url}/v1/chat/completions"
                [[ "$base_url" == */v1 ]] && test_url="${base_url}/chat/completions"
                
                response=$(curl -s -w "\n%{http_code}" -X POST "$test_url" \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $api_key" \
                    -d "{\"model\": \"$model\", \"messages\": [{\"role\": \"user\", \"content\": \"Say OK\"}], \"max_tokens\": 50}" 2>/dev/null)
            else
                test_url="https://api.anthropic.com/v1/messages"
                response=$(curl -s -w "\n%{http_code}" -X POST "$test_url" \
                    -H "Content-Type: application/json" -H "x-api-key: $api_key" -H "anthropic-version: 2023-06-01" \
                    -d "{\"model\": \"$model\", \"max_tokens\": 50, \"messages\": [{\"role\": \"user\", \"content\": \"Say OK\"}]}" 2>/dev/null)
            fi
            ;;
        google)
            test_url="https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$api_key"
            response=$(curl -s -w "\n%{http_code}" -X POST "$test_url" \
                -H "Content-Type: application/json" \
                -d "{\"contents\": [{\"parts\":[{\"text\": \"Say OK\"}]}]}" 2>/dev/null)
            ;;
        ollama)
            test_ollama_connection "$base_url" "$model"
            return $?
            ;;
        *)
            test_url="${base_url:-https://api.openai.com/v1}/chat/completions"
            response=$(curl -s -w "\n%{http_code}" -X POST "$test_url" \
                -H "Content-Type: application/json" -H "Authorization: Bearer $api_key" \
                -d "{\"model\": \"$model\", \"messages\": [{\"role\": \"user\", \"content\": \"Say OK\"}], \"max_tokens\": 50}" 2>/dev/null)
            ;;
    esac
    
    local http_code=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | sed '$d')
    
    echo ""
    if [ "$http_code" = "200" ]; then
        log_info "API 连接测试成功！(HTTP $http_code)"
        
        if command -v python3 &> /dev/null; then
            local ai_response=$(echo "$response_body" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if 'choices' in d: print(d['choices'][0].get('message', {}).get('content', '')[:100])
    elif 'content' in d: print(d['content'][0].get('text', '')[:100])
    elif 'candidates' in d: print(d['candidates'][0]['content']['parts'][0]['text'][:100])
except: print('')
" 2>/dev/null)
            [ -n "$ai_response" ] && echo -e "  AI 响应: ${GREEN}$ai_response${NC}"
        fi
        return 0
    else
        log_error "API 连接测试失败 (HTTP $http_code)"
        
        if command -v python3 &> /dev/null; then
            local error_msg=$(echo "$response_body" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if 'error' in d:
        err = d['error']
        if isinstance(err, dict): print(err.get('message', str(err))[:200])
        else:
            print(str(err)[:200])
except:
    print('无法解析错误')
" 2>/dev/null)
            echo -e "  错误: ${RED}$error_msg${NC}"
        fi
        return 1
    fi
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
    
    local message="🦞 ClawdBot 测试消息

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
    local message="🦞 **ClawdBot 测试消息** - 配置成功！时间: $timestamp"
    
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

message = '''🦞 ClawdBot 测试消息

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

# 测试 WhatsApp (通过 clawdbot status)
test_whatsapp() {
    echo ""
    echo -e "${CYAN}━━━ 测试 WhatsApp 连接 ━━━${NC}"
    echo ""
    
    if check_clawdbot_installed; then
        echo -e "${YELLOW}检查 WhatsApp 渠道状态...${NC}"
        echo ""
        clawdbot status 2>/dev/null | grep -i whatsapp || echo "WhatsApp 渠道未配置"
        echo ""
        echo -e "${CYAN}提示: 使用 'clawdbot channels login' 配置 WhatsApp${NC}"
        return 0
    else
        log_warn "WhatsApp 测试需要 ClawdBot 已安装"
        echo -e "${YELLOW}请先完成 ClawdBot 安装${NC}"
        return 1
    fi
}

# 测试 iMessage (通过 clawdbot status)
test_imessage() {
    echo ""
    echo -e "${CYAN}━━━ 测试 iMessage 连接 ━━━${NC}"
    echo ""
    
    if check_clawdbot_installed; then
        echo -e "${YELLOW}检查 iMessage 渠道状态...${NC}"
        echo ""
        clawdbot status 2>/dev/null | grep -i imessage || echo "iMessage 渠道未配置"
        return 0
    else
        log_warn "iMessage 测试需要 ClawdBot 已安装"
        echo -e "${YELLOW}请先完成 ClawdBot 安装${NC}"
        return 1
    fi
}

# 测试微信 (通过 clawdbot status)
test_wechat() {
    echo ""
    echo -e "${CYAN}━━━ 测试微信连接 ━━━${NC}"
    echo ""
    
    if check_clawdbot_installed; then
        echo -e "${YELLOW}检查微信渠道状态...${NC}"
        echo ""
        clawdbot status 2>/dev/null | grep -i wechat || echo "微信渠道未配置"
        return 0
    else
        log_warn "微信测试需要 ClawdBot 已安装"
        echo -e "${YELLOW}请先完成 ClawdBot 安装${NC}"
        return 1
    fi
}

# 运行 ClawdBot 诊断 (使用 clawdbot doctor)
run_clawdbot_doctor() {
    echo ""
    echo -e "${CYAN}━━━ ClawdBot 诊断 ━━━${NC}"
    echo ""
    
    if check_clawdbot_installed; then
        clawdbot doctor
        return $?
    else
        log_error "ClawdBot 未安装"
        echo -e "${YELLOW}请先运行 install.sh 安装 ClawdBot${NC}"
        return 1
    fi
}

# 运行 ClawdBot 状态检查 (使用 clawdbot status)
run_clawdbot_status() {
    echo ""
    echo -e "${CYAN}━━━ ClawdBot 状态 ━━━${NC}"
    echo ""
    
    if check_clawdbot_installed; then
        clawdbot status
        return $?
    else
        log_error "ClawdBot 未安装"
        return 1
    fi
}

# 运行 ClawdBot 健康检查 (使用 clawdbot health)
run_clawdbot_health() {
    echo ""
    echo -e "${CYAN}━━━ Gateway 健康检查 ━━━${NC}"
    echo ""
    
    if check_clawdbot_installed; then
        clawdbot health
        return $?
    else
        log_error "ClawdBot 未安装"
        return 1
    fi
}

# ================================ 状态显示 ================================

show_status() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📊 系统状态${NC}"
    print_divider
    echo ""
    
    # ClawdBot 服务状态
    if command -v clawdbot &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} ClawdBot 已安装: $(clawdbot --version 2>/dev/null || echo 'unknown')"
        
        # 检查服务运行状态
        if pgrep -f "clawdbot" > /dev/null 2>&1; then
            echo -e "  ${GREEN}●${NC} 服务状态: ${GREEN}运行中${NC}"
        else
            echo -e "  ${RED}●${NC} 服务状态: ${RED}已停止${NC}"
        fi
    else
        echo -e "  ${RED}✗${NC} ClawdBot 未安装"
    fi
    
    echo ""
    
    # 当前配置
    if [ -f "$CLAWDBOT_ENV" ]; then
        echo ""
        echo -e "  ${CYAN}当前配置:${NC}"
        
        # 显示 ClawdBot 模型配置
        if check_clawdbot_installed; then
            local default_model=$(clawdbot config get models.default 2>/dev/null || echo "未配置")
            echo -e "    • 默认模型: ${WHITE}$default_model${NC}"
        fi
        
        # 检查 API Key 配置
        if grep -q "ANTHROPIC_API_KEY" "$CLAWDBOT_ENV" 2>/dev/null; then
            echo -e "    • AI 提供商: ${WHITE}Anthropic${NC}"
        elif grep -q "OPENAI_API_KEY" "$CLAWDBOT_ENV" 2>/dev/null; then
            echo -e "    • AI 提供商: ${WHITE}OpenAI${NC}"
        elif grep -q "GOOGLE_API_KEY" "$CLAWDBOT_ENV" 2>/dev/null; then
            echo -e "    • AI 提供商: ${WHITE}Google${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} 环境变量未配置"
    fi
    
    echo ""
    
    # 目录状态
    echo -e "  ${CYAN}目录结构:${NC}"
    [ -d "$CONFIG_DIR" ] && echo -e "    ${GREEN}✓${NC} 配置目录: $CONFIG_DIR" || echo -e "    ${RED}✗${NC} 配置目录"
    [ -f "$CLAWDBOT_ENV" ] && echo -e "    ${GREEN}✓${NC} 环境变量: $CLAWDBOT_ENV" || echo -e "    ${RED}✗${NC} 环境变量"
    [ -f "$CLAWDBOT_JSON" ] && echo -e "    ${GREEN}✓${NC} ClawdBot 配置: $CLAWDBOT_JSON" || echo -e "    ${YELLOW}⚠${NC} ClawdBot 配置"
    
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
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    echo -en "${YELLOW}请选择 [0-16]: ${NC}"
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
    print_menu_item "1" "Claude Sonnet 4.5 (推荐)" "⭐"
    print_menu_item "2" "Claude Opus 4.5 (最强)" "👑"
    print_menu_item "3" "Claude 4.5 Haiku (快速)" "⚡"
    print_menu_item "4" "Claude 4 Sonnet (上一代)" "📦"
    print_menu_item "5" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="claude-sonnet-4-5-20250929" ;;
        2) model="claude-opus-4-5-20251101" ;;
        3) model="claude-haiku-4-5-20251001" ;;
        4) model="claude-sonnet-4-20250514" ;;
        5) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="claude-sonnet-4-5-20250929" ;;
    esac
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "anthropic" "$api_key" "$model" "$base_url"
    
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
    print_menu_item "1" "GPT-4o (推荐)" "⭐"
    print_menu_item "2" "GPT-4o-mini (经济)" "⚡"
    print_menu_item "3" "GPT-4 Turbo" "🚀"
    print_menu_item "4" "o1-preview (推理)" "🧠"
    print_menu_item "5" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="gpt-4o" ;;
        2) model="gpt-4o-mini" ;;
        3) model="gpt-4-turbo" ;;
        4) model="o1-preview" ;;
        5) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="gpt-4o" ;;
    esac
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "openai" "$api_key" "$model" "$base_url"
    
    echo ""
    log_info "OpenAI GPT 配置完成！"
    log_info "模型: $model"
    [ -n "$base_url" ] && log_info "API 地址: $base_url" || log_info "API 地址: 官方"
    
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
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "deepseek" "$api_key" "$model" "$base_url"
    
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
    local official_url="https://api.moonshot.cn/v1"
    
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
    
    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
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
    print_menu_item "1" "moonshot-v1-auto (自动, 推荐)" "⭐"
    print_menu_item "2" "moonshot-v1-8k" "📄"
    print_menu_item "3" "moonshot-v1-32k" "📑"
    print_menu_item "4" "moonshot-v1-128k (长文本)" "📚"
    print_menu_item "5" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="moonshot-v1-auto" ;;
        2) model="moonshot-v1-8k" ;;
        3) model="moonshot-v1-32k" ;;
        4) model="moonshot-v1-128k" ;;
        5) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="moonshot-v1-auto" ;;
    esac
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "kimi" "$api_key" "$model" "$base_url"
    
    echo ""
    log_info "Kimi (Moonshot) 配置完成！"
    log_info "模型: $model"
    log_info "API 地址: $base_url"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "kimi" "$api_key" "$model" "$base_url"
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
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "ollama" "" "$model" "$ollama_url"
    
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
    
    # 获取当前配置 (OpenRouter 使用 OPENAI 环境变量)
    local current_key=$(get_env_value "OPENAI_API_KEY")
    local current_url=$(get_env_value "OPENAI_BASE_URL")
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
    print_menu_item "1" "anthropic/claude-sonnet-4 (推荐)" "🟣"
    print_menu_item "2" "openai/gpt-4o" "🟢"
    print_menu_item "3" "google/gemini-pro-1.5" "🔴"
    print_menu_item "4" "meta-llama/llama-3-70b" "🦙"
    print_menu_item "5" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-5] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="anthropic/claude-sonnet-4" ;;
        2) model="openai/gpt-4o" ;;
        3) model="google/gemini-pro-1.5" ;;
        4) model="meta-llama/llama-3-70b-instruct" ;;
        5) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="anthropic/claude-sonnet-4" ;;
    esac
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "openrouter" "$api_key" "$model" "$base_url"
    
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
    echo -e "${GRAY}获取 Key: https://makersuite.google.com/app/apikey${NC}"
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
    print_menu_item "1" "gemini-2.0-flash (推荐)" "⭐"
    print_menu_item "2" "gemini-1.5-pro" "🚀"
    print_menu_item "3" "gemini-1.5-flash" "⚡"
    print_menu_item "4" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-4] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="gemini-2.0-flash" ;;
        2) model="gemini-1.5-pro" ;;
        3) model="gemini-1.5-flash" ;;
        4) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="gemini-2.0-flash" ;;
    esac
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "google" "$api_key" "$model" "$base_url"
    
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
    read -p "$(echo -e "${YELLOW}输入 API Key: ${NC}")" api_key
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
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "groq" "$api_key" "$model" "$base_url"
    
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
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "mistral" "$api_key" "$model" "$base_url"
    
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
    print_menu_item "1" "grok-4-fast (推荐，最新)" "⭐"
    print_menu_item "2" "grok-4 (最强)" "👑"
    print_menu_item "3" "grok-3-fast (快速)" "⚡"
    print_menu_item "4" "grok-3-mini-fast (轻量)" "🪶"
    print_menu_item "5" "grok-2-vision (视觉)" "👁️"
    print_menu_item "6" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-6] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="grok-4-fast" ;;
        2) model="grok-4" ;;
        3) model="grok-3-fast-latest" ;;
        4) model="grok-3-mini-fast-latest" ;;
        5) model="grok-2-vision-latest" ;;
        6) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="grok-4-fast" ;;
    esac
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "xai" "$api_key" "$model" ""
    
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
    print_menu_item "1" "glm-4.7 (推荐，最新)" "⭐"
    print_menu_item "2" "glm-4.6 (上一代)" "📦"
    print_menu_item "3" "glm-4.6v (视觉)" "👁️"
    print_menu_item "4" "glm-4.5-flash (快速)" "⚡"
    print_menu_item "5" "glm-4.5-air (轻量)" "🪶"
    print_menu_item "6" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-6] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="glm-4.7" ;;
        2) model="glm-4.6" ;;
        3) model="glm-4.6v" ;;
        4) model="glm-4.5-flash" ;;
        5) model="glm-4.5-air" ;;
        6) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="glm-4.7" ;;
    esac
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "zai" "$api_key" "$model" ""
    
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
    local official_url="https://api.minimax.chat/v1"
    
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
    
    echo -e "${CYAN}官方 API: ${WHITE}$official_url${NC}"
    echo -e "${GRAY}获取 Key: https://platform.minimax.chat/${NC}"
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
    print_menu_item "1" "MiniMax-M2.1 (推荐，最新)" "⭐"
    print_menu_item "2" "MiniMax-M2 (上一代)" "📦"
    print_menu_item "3" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-3] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="MiniMax-M2.1" ;;
        2) model="MiniMax-M2" ;;
        3) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="MiniMax-M2.1" ;;
    esac
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "$provider" "$api_key" "$model" ""
    
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
    local official_url="https://api.opencode.ai/v1"
    
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
    echo -e "${GRAY}获取 Key: https://opencode.ai/${NC}"
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
    print_menu_item "1" "claude-sonnet-4-5 (推荐)" "⭐"
    print_menu_item "2" "claude-opus-4-5 (最强)" "👑"
    print_menu_item "3" "gpt-5 (GPT-5)" "🟢"
    print_menu_item "4" "gemini-3-pro (Gemini 3)" "🔴"
    print_menu_item "5" "glm-4.7-free (免费)" "🆓"
    print_menu_item "6" "gpt-5-codex (代码)" "💻"
    print_menu_item "7" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-7] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="claude-sonnet-4-5" ;;
        2) model="claude-opus-4-5" ;;
        3) model="gpt-5" ;;
        4) model="gemini-3-pro" ;;
        5) model="glm-4.7-free" ;;
        6) model="gpt-5-codex" ;;
        7) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="claude-sonnet-4-5" ;;
    esac
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "opencode" "$api_key" "$model" ""
    
    echo ""
    log_info "OpenCode 配置完成！"
    log_info "模型: $model"
    
    # 询问是否测试
    echo ""
    if confirm "是否测试 API 连接？" "y"; then
        test_ai_connection "opencode" "$api_key" "$model" ""
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
    print_menu_item "1" "gemini-3-pro-preview (推荐)" "⭐"
    print_menu_item "2" "gemini-3-flash-preview (快速)" "⚡"
    print_menu_item "3" "gemini-2.5-pro (稳定)" "📦"
    print_menu_item "4" "gemini-2.5-flash (快速稳定)" "🚀"
    print_menu_item "5" "gemini-2.0-flash" "⚡"
    print_menu_item "6" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-6] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="gemini-3-pro-preview" ;;
        2) model="gemini-3-flash-preview" ;;
        3) model="gemini-2.5-pro" ;;
        4) model="gemini-2.5-flash" ;;
        5) model="gemini-2.0-flash" ;;
        6) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="gemini-3-pro-preview" ;;
    esac
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "google-gemini-cli" "$api_key" "$model" ""
    
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
    print_menu_item "1" "gemini-3-pro-high (推荐)" "⭐"
    print_menu_item "2" "gemini-3-pro-low (快速)" "⚡"
    print_menu_item "3" "gemini-3-flash (闪电)" "🔥"
    print_menu_item "4" "claude-sonnet-4-5 (Claude)" "🟣"
    print_menu_item "5" "claude-opus-4-5-thinking (思考)" "🧠"
    print_menu_item "6" "gpt-oss-120b-medium (GPT)" "🟢"
    print_menu_item "7" "自定义模型名称" "✏️"
    echo ""
    
    read -p "$(echo -e "${YELLOW}请选择 [1-7] (默认: 1): ${NC}")" model_choice < "$TTY_INPUT"
    model_choice=${model_choice:-1}
    
    case $model_choice in
        1) model="gemini-3-pro-high" ;;
        2) model="gemini-3-pro-low" ;;
        3) model="gemini-3-flash" ;;
        4) model="claude-sonnet-4-5" ;;
        5) model="claude-opus-4-5-thinking" ;;
        6) model="gpt-oss-120b-medium" ;;
        7) read -p "$(echo -e "${YELLOW}输入模型名称: ${NC}")" model < "$TTY_INPUT" ;;
        *) model="gemini-3-pro-high" ;;
    esac
    
    # 保存到 ClawdBot 环境变量配置
    save_clawdbot_ai_config "google-antigravity" "$api_key" "$model" ""
    
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
    
    print_menu_item "1" "Telegram 机器人" "📨"
    print_menu_item "2" "Discord 机器人" "🎮"
    print_menu_item "3" "WhatsApp" "💬"
    print_menu_item "4" "Slack" "💼"
    print_menu_item "5" "微信 (WeChat)" "🟢"
    print_menu_item "6" "iMessage" "🍎"
    print_menu_item "7" "飞书 (Feishu)" "🔷"
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    echo -en "${YELLOW}请选择 [0-7]: ${NC}"
    read choice < "$TTY_INPUT"
    
    case $choice in
        1) config_telegram ;;
        2) config_discord ;;
        3) config_whatsapp ;;
        4) config_slack ;;
        5) config_wechat ;;
        6) config_imessage ;;
        7) config_feishu ;;
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
        
        # 使用 clawdbot 命令配置
        if check_clawdbot_installed; then
            echo ""
            log_info "正在配置 ClawdBot Telegram 渠道..."
            
            # 启用 Telegram 插件
            echo -e "${YELLOW}启用 Telegram 插件...${NC}"
            clawdbot plugins enable telegram 2>/dev/null || true
            
            # 添加 Telegram channel
            echo -e "${YELLOW}添加 Telegram 账号...${NC}"
            if clawdbot channels add --channel telegram --token "$bot_token" 2>/dev/null; then
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
            log_error "ClawdBot 未安装，请先安装 ClawdBot"
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
        
        # 使用 clawdbot 命令配置
        if check_clawdbot_installed; then
            echo ""
            log_info "正在配置 ClawdBot Discord 渠道..."
            
            # 启用 Discord 插件
            echo -e "${YELLOW}启用 Discord 插件...${NC}"
            clawdbot plugins enable discord 2>/dev/null || true
            
            # 添加 Discord channel
            echo -e "${YELLOW}添加 Discord 账号...${NC}"
            if clawdbot channels add --channel discord --token "$bot_token" 2>/dev/null; then
                log_info "Discord 渠道配置成功！"
            else
                log_warn "Discord 渠道可能已存在或配置失败"
            fi
            
            # 设置 groupPolicy 为 open（只响应 @ 机器人的消息）
            echo -e "${YELLOW}设置消息响应策略...${NC}"
            clawdbot config set channels.discord.groupPolicy open 2>/dev/null || true
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
            log_error "ClawdBot 未安装，请先安装 ClawdBot"
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
    
    if ! check_clawdbot_installed; then
        log_error "ClawdBot 未安装，请先运行安装脚本"
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
        ensure_clawdbot_init
        
        # 启用 WhatsApp 插件
        echo ""
        log_info "启用 WhatsApp 插件..."
        clawdbot plugins enable whatsapp 2>/dev/null || true
        
        echo ""
        log_info "正在启动 WhatsApp 登录向导..."
        echo -e "${YELLOW}请扫描显示的二维码完成登录${NC}"
        echo ""
        
        # 使用 channels login 命令
        clawdbot channels login --channel whatsapp --verbose
        
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
    
    read -p "$(echo -e "${YELLOW}输入 Bot Token (xoxb-...): ${NC}")" bot_token
    read -p "$(echo -e "${YELLOW}输入 App Token (xapp-...): ${NC}")" app_token
    
    if [ -n "$bot_token" ] && [ -n "$app_token" ]; then
        
        # 使用 clawdbot 命令配置
        if check_clawdbot_installed; then
            echo ""
            log_info "正在配置 ClawdBot Slack 渠道..."
            
            # 启用 Slack 插件
            echo -e "${YELLOW}启用 Slack 插件...${NC}"
            clawdbot plugins enable slack 2>/dev/null || true
            
            # 添加 Slack channel
            echo -e "${YELLOW}添加 Slack 账号...${NC}"
            if clawdbot channels add --channel slack --bot-token "$bot_token" --app-token "$app_token" 2>/dev/null; then
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

config_wechat() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🟢 配置微信${NC}"
    print_divider
    echo ""
    
    echo -e "${YELLOW}⚠️ 注意: 微信接入需要第三方工具支持${NC}"
    echo ""
    
    if ! check_clawdbot_installed; then
        log_error "ClawdBot 未安装"
        press_enter
        return
    fi
    
    echo -e "${CYAN}微信接入方案:${NC}"
    echo "  • ClawdBot 可能通过插件支持微信"
    echo "  • 请查看 ClawdBot 文档了解详情"
    echo ""
    
    # 检查是否有微信相关插件
    echo -e "${YELLOW}检查可用插件...${NC}"
    local plugins=$(clawdbot plugins list 2>/dev/null | grep -i wechat || echo "")
    
    if [ -n "$plugins" ]; then
        echo ""
        echo -e "${CYAN}发现微信相关插件:${NC}"
        echo "$plugins"
        echo ""
        
        if confirm "是否启用微信插件？"; then
            clawdbot plugins enable wechat 2>/dev/null || true
            log_info "微信插件已启用"
            
            if confirm "是否重启 Gateway？" "y"; then
                restart_gateway_for_channel
            fi
        fi
    else
        echo ""
        log_warn "未发现内置微信插件"
        echo -e "${CYAN}你可以尝试第三方方案:${NC}"
        echo "  • wechaty: https://wechaty.js.org/"
        echo "  • itchat: https://github.com/littlecodersh/itchat"
    fi
    
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
    
    if ! check_clawdbot_installed; then
        log_error "ClawdBot 未安装"
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
        ensure_clawdbot_init
        
        # 启用 iMessage 插件
        echo ""
        log_info "启用 iMessage 插件..."
        clawdbot plugins enable imessage 2>/dev/null || true
        
        # 添加 iMessage channel
        echo ""
        log_info "配置 iMessage 渠道..."
        clawdbot channels add --channel imessage 2>/dev/null || true
        
        echo ""
        log_info "iMessage 配置完成！"
        
        if confirm "是否重启 Gateway 使配置生效？" "y"; then
            restart_gateway_for_channel
        fi
    fi
    
    press_enter
}

# 保存飞书配置到 JSON 文件
save_feishu_config() {
    local app_id="$1"
    local app_secret="$2"
    local config_file="$CLAWDBOT_JSON"
    
    # 确保配置目录存在
    mkdir -p "$(dirname "$config_file")" 2>/dev/null || true
    
    local config_success=false
    
    if command -v node &> /dev/null; then
        log_info "使用 node 保存飞书配置..."
        
        # 将变量写入临时文件
        local tmp_vars="/tmp/clawdbot_feishu_vars_$$.json"
        cat > "$tmp_vars" << EOFVARS
{
    "config_file": "$config_file",
    "app_id": "$app_id",
    "app_secret": "$app_secret"
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

// 确保 channels 结构存在
if (!config.channels) config.channels = {};

// 设置飞书配置
config.channels.feishu = {
    appId: vars.app_id,
    appSecret: vars.app_secret,
    enabled: true,
    connectionMode: 'websocket',
    domain: 'feishu',
    requireMention: true
};

fs.writeFileSync(vars.config_file, JSON.stringify(config, null, 2));
console.log('Feishu config saved successfully');
" 2>&1
        local node_exit=$?
        rm -f "$tmp_vars" 2>/dev/null
        
        if [ $node_exit -eq 0 ]; then
            config_success=true
        fi
    fi
    
    # 如果 node 失败，尝试 python3
    if [ "$config_success" = false ] && command -v python3 &> /dev/null; then
        log_info "使用 python3 保存飞书配置..."
        
        local tmp_vars="/tmp/clawdbot_feishu_vars_$$.json"
        cat > "$tmp_vars" << EOFVARS
{
    "config_file": "$config_file",
    "app_id": "$app_id",
    "app_secret": "$app_secret"
}
EOFVARS
        
        python3 -c "
import json
import os

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

if 'channels' not in config:
    config['channels'] = {}

config['channels']['feishu'] = {
    'appId': vars['app_id'],
    'appSecret': vars['app_secret'],
    'enabled': True,
    'connectionMode': 'websocket',
    'domain': 'feishu',
    'requireMention': True
}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
print('Feishu config saved successfully')
" 2>&1
        local py_exit=$?
        rm -f "$tmp_vars" 2>/dev/null
        
        if [ $py_exit -eq 0 ]; then
            config_success=true
        fi
    fi
    
    if [ "$config_success" = true ]; then
        log_info "飞书配置已保存到: $config_file"
        
        # 启用飞书渠道
        echo ""
        echo -e "${YELLOW}启用飞书渠道...${NC}"
        
        # 先启用 feishu 插件
        clawdbot plugins enable feishu > /dev/null 2>&1 || true
        
        # 使用 yes 管道自动确认修复
        yes | clawdbot doctor --fix > /dev/null 2>&1 || true
        
        log_info "飞书渠道已启用"
        
        return 0
    else
        log_error "保存飞书配置失败（需要 node 或 python3）"
        return 1
    fi
}

# 飞书插件安装函数（通用）
install_feishu_plugin() {
    # 飞书支持通过社区 npm 包实现
    # 包名：@m1heng-clawd/feishu
    
    echo -e "${YELLOW}安装飞书插件...${NC}"
    echo ""
    
    # 检查是否已安装飞书插件
    local installed=$(clawdbot plugins list 2>/dev/null | grep -i feishu || echo "")
    
    if [ -n "$installed" ]; then
        log_info "飞书插件已安装: $installed"
        return 0
    fi
    
    # 检查 npm 全局包是否已安装
    if npm list -g @m1heng-clawd/feishu 2>/dev/null | grep -q "@m1heng-clawd/feishu"; then
        log_info "飞书插件已安装 (npm): @m1heng-clawd/feishu"
        return 0
    fi
    
    echo -e "${CYAN}正在安装社区飞书插件 @m1heng-clawd/feishu ...${NC}"
    echo ""
    
    # 使用 clawdbot plugins install 安装
    echo -e "${CYAN}正在安装...${NC}"
    local install_output
    install_output=$(clawdbot plugins install @m1heng-clawd/feishu 2>&1)
    local install_exit=$?
    
    # 只显示关键信息，过滤掉 doctor 输出
    echo "$install_output" | grep -v "Config invalid" | grep -v "Doctor" | grep -v "clawdbot doctor" | grep -v "^│" | grep -v "^├" | grep -v "^◇" | head -10
    
    if [ $install_exit -eq 0 ]; then
        echo ""
        log_info "✅ 飞书插件安装成功！"
        return 0
    else
        echo ""
        log_warn "clawdbot 安装失败，正在尝试 npm 安装..."
        echo ""
        
        # 尝试使用 npm 直接安装
        if npm install -g @m1heng-clawd/feishu 2>/dev/null; then
            log_info "✅ 飞书插件安装成功（npm）！"
            return 0
        else
            log_error "插件安装失败"
            echo ""
            echo -e "${CYAN}请手动安装:${NC}"
            echo "  clawdbot plugins install @m1heng-clawd/feishu"
            echo "  # 或"
            echo "  npm install -g @m1heng-clawd/feishu"
            echo ""
            return 1
        fi
    fi
}

config_feishu() {
    clear_screen
    print_header
    
    echo -e "${WHITE}🔷 配置飞书 (Feishu)${NC}"
    print_divider
    echo ""
    
    echo -e "${YELLOW}⚠️ 注意: 飞书接入通过社区插件支持${NC}"
    echo ""
    
    if ! check_clawdbot_installed; then
        log_error "ClawdBot 未安装"
        press_enter
        return
    fi
    
    echo -e "${CYAN}飞书接入说明:${NC}"
    echo ""
    echo -e "  ${WHITE}使用社区插件 @m1heng-clawd/feishu${NC}"
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
    echo "    • 安装社区插件 @m1heng-clawd/feishu"
    echo ""
    echo "  ${WHITE}第二步: 飞书开放平台创建应用${NC}"
    echo "    1. 访问 https://open.feishu.cn/"
    echo "    2. 创建企业自建应用 → 添加「机器人」能力"
    echo "    3. 获取 App ID 和 App Secret"
    echo ""
    echo "  ${WHITE}第三步: 配置机器人权限${NC}"
    echo "    • 权限管理 → 添加以下权限:"
    echo "      - im:message (收发消息)"
    echo "      - im:message:send_as_bot (发送消息)"
    echo "      - im:chat:readonly (读取群信息)"
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
    
    # ========== 第一步：安装插件 ==========
    echo ""
    echo -e "${WHITE}━━━ 第一步: 安装飞书插件 (自动) ━━━${NC}"
    echo ""
    
    install_feishu_plugin
    
    echo ""
    log_info "✅ 第一步完成！插件已就绪"
    echo ""
    
    # ========== 第二、三步提示 ==========
    echo -e "${WHITE}━━━ 第二、三步: 请在飞书开放平台完成 ━━━${NC}"
    echo ""
    echo -e "${CYAN}请打开飞书开放平台完成以下操作:${NC}"
    echo "  1. 访问 https://open.feishu.cn/"
    echo "  2. 创建企业自建应用 → 添加「机器人」能力"
    echo "  3. 获取 App ID 和 App Secret"
    echo "  4. 权限管理 → 添加权限:"
    echo "     - im:message (收发消息)"
    echo "     - im:message:send_as_bot (发送消息)"
    echo "     - im:chat:readonly (读取群信息)"
    echo ""
    echo -e "${GREEN}💡 提示: 使用长连接模式，无需配置公网 Webhook 地址${NC}"
    echo ""
    
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
    echo -en "${YELLOW}输入 App Secret: ${NC}"
    read feishu_app_secret < "$TTY_INPUT"
    
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
    echo -e "${YELLOW}⚠️ 请确保 ClawdBot Gateway 服务已启动${NC}"
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
        read -p "$(echo -e "${YELLOW}Chat ID (留空跳过测试): ${NC}")" feishu_chat_id
        
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
    
    if ! check_clawdbot_installed; then
        log_error "ClawdBot 未安装"
        press_enter
        return
    fi
    
    # 显示当前配置
    echo -e "${CYAN}当前配置:${NC}"
    clawdbot config get identity 2>/dev/null || echo "  (未配置)"
    echo ""
    print_divider
    echo ""
    
    read -p "$(echo -e "${YELLOW}助手名称: ${NC}")" bot_name
    read -p "$(echo -e "${YELLOW}如何称呼你: ${NC}")" user_name
    read -p "$(echo -e "${YELLOW}时区 (如 Asia/Shanghai): ${NC}")" timezone
    
    # 使用 clawdbot 命令设置
    [ -n "$bot_name" ] && clawdbot config set identity.name "$bot_name" 2>/dev/null
    [ -n "$user_name" ] && clawdbot config set identity.user_name "$user_name" 2>/dev/null
    [ -n "$timezone" ] && clawdbot config set identity.timezone "$timezone" 2>/dev/null
    
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
            if confirm "允许 ClawdBot 执行系统命令？这可能带来安全风险" "n"; then
                log_info "已启用系统命令执行"
            else
                log_info "已禁用系统命令执行"
            fi
            ;;
        2)
            if confirm "允许 ClawdBot 读写文件？" "n"; then
                log_info "已启用文件访问"
            else
                log_info "已禁用文件访问"
            fi
            ;;
        3)
            if confirm "允许 ClawdBot 浏览网络？" "y"; then
                log_info "已启用网络浏览"
            else
                log_info "已禁用网络浏览"
            fi
            ;;
        4)
            if confirm "启用沙箱模式？(推荐)" "y"; then
                log_info "已启用沙箱模式"
            else
                log_warn "已禁用沙箱模式，请注意安全风险"
            fi
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
    
    if ! check_clawdbot_installed; then
        log_error "ClawdBot 未安装"
        press_enter
        return
    fi
    
    echo -e "${CYAN}使用 clawdbot 命令配置白名单:${NC}"
    echo ""
    echo "  clawdbot config set security.allowed_paths '/path/to/dir1,/path/to/dir2'"
    echo ""
    
    read -p "$(echo -e "${YELLOW}输入允许访问的目录 (逗号分隔): ${NC}")" paths
    
    if [ -n "$paths" ]; then
        clawdbot config set security.allowed_paths "$paths" 2>/dev/null
        log_info "白名单配置已保存"
    fi
}

# ================================ 服务管理 ================================

manage_service() {
    clear_screen
    print_header
    
    echo -e "${WHITE}⚡ 服务管理${NC}"
    print_divider
    echo ""
    
    # 检查服务状态
    if pgrep -f "clawdbot.*gateway" > /dev/null 2>&1; then
        echo -e "  当前状态: ${GREEN}● 运行中${NC}"
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
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    echo -en "${YELLOW}请选择 [0-7]: ${NC}"
    read choice < "$TTY_INPUT"
    
    case $choice in
        1)
            echo ""
            if command -v clawdbot &> /dev/null; then
                # 确保基础配置正确
                ensure_clawdbot_init
                
                # 加载环境变量
                if [ -f "$CLAWDBOT_ENV" ]; then
                    source "$CLAWDBOT_ENV"
                    log_info "已加载环境变量"
                fi
                
                # 先验证配置是否有效
                log_info "验证配置..."
                local config_check=$(clawdbot doctor 2>&1 | head -5)
                if echo "$config_check" | grep -qi "Config invalid"; then
                    log_error "配置无效，请先修复配置"
                    echo ""
                    echo -e "${YELLOW}错误详情:${NC}"
                    echo "$config_check" | head -10
                    echo ""
                    echo -e "${CYAN}建议运行: clawdbot doctor --fix${NC}"
                    press_enter
                    manage_service
                    return
                fi
                
                log_info "正在启动服务..."
                
                # 后台启动 Gateway（使用 setsid 完全脱离终端）
                if command -v setsid &> /dev/null; then
                    if [ -f "$CLAWDBOT_ENV" ]; then
                        setsid bash -c "source $CLAWDBOT_ENV && exec clawdbot gateway --port 18789" > /tmp/clawdbot-gateway.log 2>&1 &
                    else
                        setsid clawdbot gateway --port 18789 > /tmp/clawdbot-gateway.log 2>&1 &
                    fi
                else
                    # 备用方案：nohup + disown
                    if [ -f "$CLAWDBOT_ENV" ]; then
                        nohup bash -c "source $CLAWDBOT_ENV && exec clawdbot gateway --port 18789" > /tmp/clawdbot-gateway.log 2>&1 &
                    else
                        nohup clawdbot gateway --port 18789 > /tmp/clawdbot-gateway.log 2>&1 &
                    fi
                    disown 2>/dev/null || true
                fi
                
                sleep 3
                if pgrep -f "clawdbot.*gateway" > /dev/null 2>&1; then
                    log_info "服务已在后台启动"
                    echo -e "${CYAN}日志文件: /tmp/clawdbot-gateway.log${NC}"
                    # 显示最近的日志
                    echo ""
                    echo -e "${GRAY}最近日志:${NC}"
                    tail -5 /tmp/clawdbot-gateway.log 2>/dev/null | sed 's/^/  /'
                else
                    log_error "启动失败"
                    echo ""
                    echo -e "${YELLOW}错误日志:${NC}"
                    tail -10 /tmp/clawdbot-gateway.log 2>/dev/null | sed 's/^/  /'
                    echo ""
                    echo -e "${CYAN}建议运行: clawdbot doctor --fix${NC}"
                fi
            else
                log_error "ClawdBot 未安装"
            fi
            ;;
        2)
            echo ""
            log_info "正在停止服务..."
            if command -v clawdbot &> /dev/null; then
                clawdbot gateway stop 2>/dev/null || true
                # 确保进程被杀死
                pkill -f "clawdbot.*gateway" 2>/dev/null || true
                sleep 1
                if ! pgrep -f "clawdbot.*gateway" > /dev/null 2>&1; then
                    log_info "服务已停止"
                else
                    log_warn "进程可能仍在运行"
                fi
            else
                log_error "ClawdBot 未安装"
            fi
            ;;
        3)
            echo ""
            log_info "正在重启服务..."
            if command -v clawdbot &> /dev/null; then
                clawdbot gateway stop 2>/dev/null || true
                pkill -f "clawdbot.*gateway" 2>/dev/null || true
                sleep 2
                ensure_clawdbot_init
                
                # 加载环境变量
                if [ -f "$CLAWDBOT_ENV" ]; then
                    source "$CLAWDBOT_ENV"
                fi
                
                # 后台启动 Gateway（使用 setsid 完全脱离终端）
                if command -v setsid &> /dev/null; then
                    if [ -f "$CLAWDBOT_ENV" ]; then
                        setsid bash -c "source $CLAWDBOT_ENV && exec clawdbot gateway --port 18789" > /tmp/clawdbot-gateway.log 2>&1 &
                    else
                        setsid clawdbot gateway --port 18789 > /tmp/clawdbot-gateway.log 2>&1 &
                    fi
                else
                    if [ -f "$CLAWDBOT_ENV" ]; then
                        nohup bash -c "source $CLAWDBOT_ENV && exec clawdbot gateway --port 18789" > /tmp/clawdbot-gateway.log 2>&1 &
                    else
                        nohup clawdbot gateway --port 18789 > /tmp/clawdbot-gateway.log 2>&1 &
                    fi
                    disown 2>/dev/null || true
                fi
                
                sleep 3
                if pgrep -f "clawdbot.*gateway" > /dev/null 2>&1; then
                    log_info "服务已重启"
                else
                    log_error "重启失败"
                fi
            else
                log_error "ClawdBot 未安装"
            fi
            ;;
        4)
            echo ""
            if command -v clawdbot &> /dev/null; then
                clawdbot status
            else
                log_error "ClawdBot 未安装"
            fi
            ;;
        5)
            echo ""
            if command -v clawdbot &> /dev/null; then
                echo -e "${CYAN}按 Ctrl+C 退出日志查看${NC}"
                sleep 1
                clawdbot logs --follow
            else
                log_error "ClawdBot 未安装"
            fi
            ;;
        6)
            echo ""
            if command -v clawdbot &> /dev/null; then
                clawdbot doctor --fix
            else
                log_error "ClawdBot 未安装"
            fi
            ;;
        7)
            echo ""
            if command -v clawdbot &> /dev/null; then
                log_info "正在安装系统服务..."
                clawdbot gateway install
                log_info "系统服务已安装"
                echo ""
                echo -e "${CYAN}现在可以使用以下命令管理服务:${NC}"
                echo "  clawdbot gateway start"
                echo "  clawdbot gateway stop"
                echo "  clawdbot gateway restart"
            else
                log_error "ClawdBot 未安装"
            fi
            ;;
        0)
            return
            ;;
    esac
    
    press_enter
    manage_service
}

# 确保 ClawdBot 基础配置正确
ensure_clawdbot_init() {
    local CLAWDBOT_DIR="$HOME/.clawdbot"
    
    # 创建必要的目录
    mkdir -p "$CLAWDBOT_DIR/agents/main/sessions" 2>/dev/null || true
    mkdir -p "$CLAWDBOT_DIR/agents/main/agent" 2>/dev/null || true
    mkdir -p "$CLAWDBOT_DIR/credentials" 2>/dev/null || true
    
    # 修复权限
    chmod 700 "$CLAWDBOT_DIR" 2>/dev/null || true
    
    # 确保 gateway.mode 已设置
    local current_mode=$(clawdbot config get gateway.mode 2>/dev/null)
    if [ -z "$current_mode" ] || [ "$current_mode" = "undefined" ]; then
        clawdbot config set gateway.mode local 2>/dev/null || true
    fi
}

# 保存 AI 配置到 ClawdBot 环境变量
save_clawdbot_ai_config() {
    local provider="$1"
    local api_key="$2"
    local model="$3"
    local base_url="$4"
    
    ensure_clawdbot_init
    
    local env_file="$CLAWDBOT_ENV"
    local config_file="$CLAWDBOT_JSON"
    
    # 创建或更新环境变量文件
    cat > "$env_file" << EOF
# ClawdBot 环境变量配置
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
        kimi)
            echo "export MOONSHOT_API_KEY=$api_key" >> "$env_file"
            echo "export MOONSHOT_BASE_URL=${base_url:-https://api.moonshot.cn/v1}" >> "$env_file"
            ;;
        google|google-gemini-cli|google-antigravity)
            echo "export GOOGLE_API_KEY=$api_key" >> "$env_file"
            [ -n "$base_url" ] && echo "export GOOGLE_BASE_URL=$base_url" >> "$env_file"
            ;;
        groq)
            echo "export OPENAI_API_KEY=$api_key" >> "$env_file"
            echo "export OPENAI_BASE_URL=${base_url:-https://api.groq.com/openai/v1}" >> "$env_file"
            ;;
        mistral)
            echo "export OPENAI_API_KEY=$api_key" >> "$env_file"
            echo "export OPENAI_BASE_URL=${base_url:-https://api.mistral.ai/v1}" >> "$env_file"
            ;;
        openrouter)
            echo "export OPENAI_API_KEY=$api_key" >> "$env_file"
            echo "export OPENAI_BASE_URL=${base_url:-https://openrouter.ai/api/v1}" >> "$env_file"
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
        opencode)
            echo "export OPENCODE_API_KEY=$api_key" >> "$env_file"
            ;;
    esac
    
    chmod 600 "$env_file"
    
    # 设置默认模型
    if check_clawdbot_installed; then
        local clawdbot_model=""
        local use_custom_provider=false
        
        # 如果使用自定义 BASE_URL，需要配置自定义 provider
        if [ -n "$base_url" ] && [ "$provider" = "anthropic" ]; then
            use_custom_provider=true
            configure_custom_provider "$provider" "$api_key" "$model" "$base_url" "$config_file"
            clawdbot_model="anthropic-custom/$model"
        elif [ -n "$base_url" ] && [ "$provider" = "openai" ]; then
            use_custom_provider=true
            configure_custom_provider "$provider" "$api_key" "$model" "$base_url" "$config_file"
            clawdbot_model="openai-custom/$model"
        else
            case "$provider" in
                anthropic)
                    clawdbot_model="anthropic/$model"
                    ;;
                openai|groq|mistral)
                    clawdbot_model="openai/$model"
                    ;;
                deepseek)
                    clawdbot_model="deepseek/$model"
                    ;;
                kimi)
                    clawdbot_model="kimi/$model"
                    ;;
                openrouter)
                    clawdbot_model="openrouter/$model"
                    ;;
                google)
                    clawdbot_model="google/$model"
                    ;;
                ollama)
                    clawdbot_model="ollama/$model"
                    ;;
                xai)
                    clawdbot_model="xai/$model"
                    ;;
                zai)
                    clawdbot_model="zai/$model"
                    ;;
                minimax)
                    clawdbot_model="minimax/$model"
                    ;;
                minimax-cn)
                    clawdbot_model="minimax-cn/$model"
                    ;;
                opencode)
                    clawdbot_model="opencode/$model"
                    ;;
                google-gemini-cli)
                    clawdbot_model="google-gemini-cli/$model"
                    ;;
                google-antigravity)
                    clawdbot_model="google-antigravity/$model"
                    ;;
            esac
        fi
        
        if [ -n "$clawdbot_model" ]; then
            # 加载环境变量并设置模型
            source "$env_file"
            clawdbot models set "$clawdbot_model" 2>/dev/null || true
            log_info "ClawdBot 默认模型已设置为: $clawdbot_model"
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
        if ! grep -q "source.*clawdbot/env" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# ClawdBot 环境变量" >> "$shell_rc"
            echo "[ -f \"$env_file\" ] && source \"$env_file\"" >> "$shell_rc"
        fi
    fi
    
    log_info "环境变量已保存到: $env_file"
}

# 配置自定义 provider（用于支持自定义 API 地址）
configure_custom_provider() {
    local provider="$1"
    local api_key="$2"
    local model="$3"
    local base_url="$4"
    local config_file="$5"
    
    # 参数校验
    if [ -z "$model" ]; then
        log_error "模型名称不能为空"
        return 0
    fi
    
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空"
        return 0
    fi
    
    if [ -z "$base_url" ]; then
        log_error "API 地址不能为空"
        return 0
    fi
    
    log_info "配置自定义 Provider..."
    
    # 确保配置目录存在
    local config_dir=$(dirname "$config_file")
    mkdir -p "$config_dir" 2>/dev/null || true
    
    # 确定 API 类型
    # ClawdBot 支持: anthropic-messages, openai-responses
    local api_type="openai-responses"
    if [ "$provider" = "anthropic" ]; then
        api_type="anthropic-messages"
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
        local tmp_vars="/tmp/clawdbot_provider_vars_$$.json"
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
        local tmp_vars="/tmp/clawdbot_provider_vars_$$.json"
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
    print_menu_item "6" "更新 ClawdBot" "⬆️"
    print_menu_item "7" "卸载 ClawdBot" "🗑️"
    print_menu_item "0" "返回主菜单" "↩️"
    echo ""
    
    echo -en "${YELLOW}请选择 [0-7]: ${NC}"
    read choice < "$TTY_INPUT"
    
    case $choice in
        1)
            echo ""
            log_info "正在打开环境变量配置..."
            if [ -f "$CLAWDBOT_ENV" ]; then
                if [ -n "$EDITOR" ]; then
                    $EDITOR "$CLAWDBOT_ENV"
                elif command -v nano &> /dev/null; then
                    nano "$CLAWDBOT_ENV"
                elif command -v vim &> /dev/null; then
                    vim "$CLAWDBOT_ENV"
                else
                    cat "$CLAWDBOT_ENV"
                fi
            else
                log_error "环境变量文件不存在: $CLAWDBOT_ENV"
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
                rm -f "$CLAWDBOT_ENV"
                rm -rf "$CONFIG_DIR/clawdbot.json" 2>/dev/null
                log_info "配置已重置，请重新运行安装脚本"
            fi
            ;;
        5)
            if confirm "确定要清理日志吗？" "n"; then
                if command -v clawdbot &> /dev/null; then
                    clawdbot logs clear 2>/dev/null || log_warn "ClawdBot 日志清理命令不可用"
                fi
                rm -f /tmp/clawdbot-gateway.log 2>/dev/null
                log_info "日志已清理"
            fi
            ;;
        6)
            echo ""
            log_info "正在更新 ClawdBot..."
            npm update -g clawdbot
            log_info "更新完成"
            ;;
        7)
            if confirm "确定要卸载 ClawdBot 吗？" "n"; then
                npm uninstall -g clawdbot
                if confirm "是否同时删除配置文件？" "n"; then
                    rm -rf "$CONFIG_DIR"
                fi
                log_info "ClawdBot 已卸载"
                exit 0
            fi
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
        cp "$selected_backup" "$CLAWDBOT_ENV"
        source "$CLAWDBOT_ENV"
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
    echo -e "${CYAN}环境变量配置 ($CLAWDBOT_ENV):${NC}"
    echo ""
    if [ -f "$CLAWDBOT_ENV" ]; then
        if command -v bat &> /dev/null; then
            bat --style=numbers --language=bash "$CLAWDBOT_ENV"
        else
            cat -n "$CLAWDBOT_ENV"
        fi
    else
        echo -e "  ${GRAY}(未配置)${NC}"
    fi
    
    echo ""
    print_divider
    echo ""
    
    # 显示 ClawdBot 配置
    if check_clawdbot_installed; then
        echo -e "${CYAN}ClawdBot 配置:${NC}"
        echo ""
        clawdbot config list 2>/dev/null || echo -e "  ${GRAY}(无法获取)${NC}"
        echo ""
        
        echo -e "${CYAN}已配置渠道:${NC}"
        echo ""
        clawdbot channels list 2>/dev/null || echo -e "  ${GRAY}(无渠道)${NC}"
        echo ""
        
        echo -e "${CYAN}当前模型:${NC}"
        echo ""
        clawdbot models status 2>/dev/null || echo -e "  ${GRAY}(未配置)${NC}"
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
    
    # 显示 ClawdBot 状态
    if check_clawdbot_installed; then
        local version=$(clawdbot --version 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}✓${NC} ClawdBot 已安装: $version"
    else
        echo -e "  ${YELLOW}⚠${NC} ClawdBot 未安装"
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
    echo -e "${CYAN}ClawdBot 诊断 (需要已安装):${NC}"
    print_menu_item "7" "clawdbot doctor (诊断)" "🔍"
    print_menu_item "8" "clawdbot status (渠道状态)" "📊"
    print_menu_item "9" "clawdbot health (Gateway 健康)" "💚"
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
    
    # 从环境变量文件读取配置
    if [ ! -f "$CLAWDBOT_ENV" ]; then
        log_error "AI 模型尚未配置，请先完成配置"
        press_enter
        quick_test_menu
        return
    fi
    
    source "$CLAWDBOT_ENV"
    
    local provider=""
    local api_key=""
    local base_url=""
    local model=""
    
    # 确定 provider
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        provider="anthropic"
        api_key="$ANTHROPIC_API_KEY"
        base_url="$ANTHROPIC_BASE_URL"
    elif [ -n "$OPENAI_API_KEY" ]; then
        provider="openai"
        api_key="$OPENAI_API_KEY"
        base_url="$OPENAI_BASE_URL"
    elif [ -n "$GOOGLE_API_KEY" ]; then
        provider="google"
        api_key="$GOOGLE_API_KEY"
        base_url="$GOOGLE_BASE_URL"
    elif [ -n "$GROQ_API_KEY" ]; then
        provider="groq"
        api_key="$GROQ_API_KEY"
        base_url="$GROQ_BASE_URL"
    elif [ -n "$MISTRAL_API_KEY" ]; then
        provider="mistral"
        api_key="$MISTRAL_API_KEY"
        base_url="$MISTRAL_BASE_URL"
    elif [ -n "$OPENROUTER_API_KEY" ]; then
        provider="openrouter"
        api_key="$OPENROUTER_API_KEY"
        base_url="$OPENROUTER_BASE_URL"
    fi
    
    if [ -z "$provider" ] || [ -z "$api_key" ]; then
        log_error "AI 模型尚未配置，请先完成配置"
        press_enter
        quick_test_menu
        return
    fi
    
    # 获取当前模型
    if check_clawdbot_installed; then
        model=$(clawdbot config get models.default 2>/dev/null | sed 's|.*/||')
    fi
    
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
    
    read -p "$(echo -e "${YELLOW}Bot Token (xoxb-...): ${NC}")" bot_token
    
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
    if [ -f "$CLAWDBOT_JSON" ]; then
        if command -v node &> /dev/null; then
            app_id=$(node -e "
try {
    const config = JSON.parse(require('fs').readFileSync('$CLAWDBOT_JSON', 'utf8'));
    console.log(config.channels?.feishu?.appId || '');
} catch (e) { console.log(''); }
" 2>/dev/null)
            app_secret=$(node -e "
try {
    const config = JSON.parse(require('fs').readFileSync('$CLAWDBOT_JSON', 'utf8'));
    console.log(config.channels?.feishu?.appSecret || '');
} catch (e) { console.log(''); }
" 2>/dev/null)
        elif command -v python3 &> /dev/null; then
            app_id=$(python3 -c "
import json
try:
    with open('$CLAWDBOT_JSON', 'r') as f:
        config = json.load(f)
    print(config.get('channels', {}).get('feishu', {}).get('appId', ''))
except: print('')
" 2>/dev/null)
            app_secret=$(python3 -c "
import json
try:
    with open('$CLAWDBOT_JSON', 'r') as f:
        config = json.load(f)
    print(config.get('channels', {}).get('feishu', {}).get('appSecret', ''))
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
        echo -en "${YELLOW}App Secret: ${NC}"
        read app_secret < "$TTY_INPUT"
        
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
    
    echo -e "${WHITE}🔍 ClawdBot 诊断${NC}"
    print_divider
    
    run_clawdbot_doctor
    
    press_enter
    quick_test_menu
}

quick_test_status() {
    clear_screen
    print_header
    
    echo -e "${WHITE}📊 ClawdBot 渠道状态${NC}"
    print_divider
    
    run_clawdbot_status
    
    press_enter
    quick_test_menu
}

quick_test_health() {
    clear_screen
    print_header
    
    echo -e "${WHITE}💚 Gateway 健康检查${NC}"
    print_divider
    
    run_clawdbot_health
    
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
    [ -f "$CLAWDBOT_ENV" ] && source "$CLAWDBOT_ENV"
    
    local provider=""
    local api_key=""
    local base_url=""
    local model=""
    
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        provider="anthropic"
        api_key="$ANTHROPIC_API_KEY"
        base_url="$ANTHROPIC_BASE_URL"
    elif [ -n "$OPENAI_API_KEY" ]; then
        provider="openai"
        api_key="$OPENAI_API_KEY"
        base_url="$OPENAI_BASE_URL"
    elif [ -n "$GOOGLE_API_KEY" ]; then
        provider="google"
        api_key="$GOOGLE_API_KEY"
    fi
    
    # 获取当前模型
    if check_clawdbot_installed; then
        model=$(clawdbot config get models.default 2>/dev/null | sed 's|.*/||')
    fi
    
    if [ -n "$provider" ] && [ -n "$api_key" ] && [ "$api_key" != "your-api-key-here" ]; then
        total_tests=$((total_tests + 1))
        echo -e "${CYAN}[测试 $total_tests] AI API ($provider)${NC}"
        
        local test_url=""
        local http_code=""
        
        case "$provider" in
            anthropic)
                http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://api.anthropic.com/v1/messages" \
                    -H "x-api-key: $api_key" -H "anthropic-version: 2023-06-01" -H "Content-Type: application/json" \
                    -d '{"model":"'$model'","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}' 2>/dev/null)
                ;;
            google)
                http_code=$(curl -s -o /dev/null -w "%{http_code}" \
                    "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$api_key" \
                    -H "Content-Type: application/json" -d '{"contents":[{"parts":[{"text":"hi"}]}]}' 2>/dev/null)
                ;;
            *)
                test_url="${base_url:-https://api.openai.com/v1}/chat/completions"
                http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$test_url" \
                    -H "Authorization: Bearer $api_key" -H "Content-Type: application/json" \
                    -d '{"model":"'$model'","messages":[{"role":"user","content":"hi"}],"max_tokens":10}' 2>/dev/null)
                ;;
        esac
        
        if [ "$http_code" = "200" ]; then
            log_info "AI API 测试通过"
            passed_tests=$((passed_tests + 1))
        else
            log_error "AI API 测试失败 (HTTP $http_code)"
        fi
        echo ""
    fi
    
    # 渠道测试提示
    echo ""
    echo -e "${CYAN}渠道测试:${NC}"
    echo -e "  使用 ${WHITE}快速测试${NC} 菜单手动测试各个渠道"
    echo -e "  或运行 ${WHITE}clawdbot channels list${NC} 查看已配置渠道"
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
    
    # 如果 ClawdBot 已安装，提示可用的诊断命令
    if check_clawdbot_installed; then
        echo ""
        echo -e "${CYAN}提示: 可使用以下命令进行更详细的诊断:${NC}"
        echo "  • clawdbot doctor  - 健康检查 + 修复建议"
        echo "  • clawdbot status  - 渠道状态"
        echo "  • clawdbot health  - Gateway 健康状态"
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
    
    # 主循环
    while true; do
        show_main_menu
        echo -en "${YELLOW}请选择 [0-9]: ${NC}"
        read choice < "$TTY_INPUT"
        
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
