#!/bin/bash
set -e

CONFIG_DIR="/root/.openclaw"
OPENCLAW_JSON="$CONFIG_DIR/openclaw.json"
OPENCLAW_ENV="$CONFIG_DIR/env"

# 确保目录存在
mkdir -p "$CONFIG_DIR/logs"
mkdir -p "$CONFIG_DIR/data"
mkdir -p "$CONFIG_DIR/skills"
mkdir -p "$CONFIG_DIR/backups"

# 初始化官方推荐配置文件结构（env + openclaw.json）
if [ ! -f "$OPENCLAW_JSON" ]; then
    echo "📝 首次运行，创建默认 openclaw.json ..."
    cat > "$OPENCLAW_JSON" <<'EOF'
{
  "channels": {},
  "plugins": {
    "allow": [],
    "entries": {}
  }
}
EOF
fi

if [ ! -f "$OPENCLAW_ENV" ]; then
    echo "📝 首次运行，创建默认 env 模板..."
    cat > "$OPENCLAW_ENV" <<'EOF'
# export ANTHROPIC_API_KEY=your_api_key
# export OPENAI_API_KEY=your_api_key
# export OPENAI_BASE_URL=https://api.openai.com/v1
EOF
    chmod 600 "$OPENCLAW_ENV"
fi

# 打印启动信息
echo ""
echo "🦞 OpenClaw Docker Container"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "配置目录: $CONFIG_DIR"
echo "环境变量: $OPENCLAW_ENV"
echo "主配置: $OPENCLAW_JSON"
echo "日志目录: $CONFIG_DIR/logs"
echo "技能目录: $CONFIG_DIR/skills"
echo "网关端口: 18789"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 执行传入的命令
exec "$@"
