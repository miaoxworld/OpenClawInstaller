# 🦞 OpenClaw 一键部署工具

<p align="center">
  <img src="https://img.shields.io/badge/Version-1.0.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-green.svg" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">
</p>

> 🚀 一键部署你的私人 AI 助手 OpenClaw，支持多平台多模型配置

<p align="center">
  <img src="photo/menu.png" alt="OpenClaw 配置中心" width="600">
</p>

## 📖 目录

- [功能特性](#-功能特性)
- [系统要求](#-系统要求)
- [快速开始](#-快速开始)
- [详细配置](#-详细配置)
- [常用命令](#-常用命令)
- [配置说明](#-配置说明)
- [安全建议](#-安全建议)
- [常见问题](#-常见问题)
- [更新日志](#-更新日志)

## ✨ 功能特性

### 🤖 多模型支持

<p align="center">
  <img src="photo/llm.png" alt="OpenClaw AI 模型配置" width="600">
</p>

**主流服务商:**
- **Anthropic Claude** - Claude Opus 4 / Sonnet 4 / Haiku *(支持自定义 API 地址)*
- **OpenAI GPT** - GPT-4o / GPT-4 Turbo / o1 *(支持自定义 API 地址)*
- **Google Gemini** - Gemini 2.0 Flash / 1.5 Pro
- **xAI Grok** - Grok 4 / Grok 3 / Grok 2 Vision *(Elon Musk 的 AI)*

**多模型网关:**
- **OpenRouter** - 多模型网关，一个 Key 用遍所有模型
- **OpenCode** - 免费多模型 API，支持 Claude/GPT/Gemini/GLM

**快速推理:**
- **Groq** - 超快推理，Llama 3.3 / Mixtral
- **Mistral AI** - Mistral Large / Codestral

**本地/企业:**
- **Ollama** - 本地部署，无需 API Key
- **Azure OpenAI** - 企业级 Azure 部署

**国产模型:**
- **智谱 GLM (Zai)** - GLM-4.7 / GLM-4.6 *(中国领先 AI)*
- **MiniMax** - MiniMax-M2 系列 *(支持国内/国际版)*

**实验性:**
- **Google Gemini CLI** - Gemini 3 预览版
- **Google Antigravity** - Google 实验性多模型 API

> 💡 **自定义 API 地址**: Anthropic Claude 和 OpenAI GPT 都支持自定义 API 地址，可接入 OneAPI/NewAPI/API 代理等服务。配置时先输入自定义地址，再输入 API Key。

> ⚠️ **重要更新**: 从 v2026.1.9 版本开始，命令已从 `clawdbot` 更改为 `openclaw`，`message` 命令改为子命令格式。

### 📱 多渠道接入

<p align="center">
  <img src="photo/social.png" alt="OpenClaw 消息渠道配置" width="600">
</p>

- Telegram Bot
- Discord Bot
- WhatsApp
- Slack
- 微信 (WeChat)
- iMessage (仅 macOS)
- 飞书 (Feishu)

### 🧪 快速测试

<p align="center">
  <img src="photo/messages.png" alt="OpenClaw 快速测试" width="600">
</p>

- API 连接测试
- 渠道连接验证
- OpenClaw 诊断工具

### 🧠 核心能力
- **持久记忆** - 跨对话、跨平台的长期记忆
- **主动推送** - 定时提醒、晨报、告警通知
- **技能系统** - 通过 Markdown 文件定义自定义能力
- **远程控制** - 可执行系统命令、读写文件、浏览网络

## 💻 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 12+ / Ubuntu 20.04+ / Debian 11+ / CentOS 8+ |
| Node.js | v22 或更高版本 |
| 内存 | 最低 2GB，推荐 4GB+ |
| 磁盘空间 | 最低 1GB |

## 🚀 快速开始

### 方式一：一键安装（推荐）

```bash
# 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/miaoxworld/OpenClawInstaller/main/install.sh | bash
```

安装脚本会自动：
1. 检测系统环境并安装依赖
2. 安装 OpenClaw
3. 引导完成核心配置（AI模型、身份信息）
4. 测试 API 连接
5. **自动启动 OpenClaw 服务**
6. 可选打开配置菜单进行详细配置（渠道等）

### 方式二：手动安装

```bash
# 1. 克隆仓库
git clone https://github.com/miaoxworld/OpenClawInstaller.git
cd OpenClawInstaller

# 2. 添加执行权限
chmod +x install.sh config-menu.sh

# 3. 运行安装脚本
./install.sh
```

### 安装完成后

安装完成后脚本会：
1. **自动询问是否启动服务**（推荐选择 Y）
2. 后台启动 OpenClaw Gateway
3. 可选打开配置菜单进行渠道配置

如果需要后续管理：

```bash
# 手动启动服务
source ~/.openclaw/env && openclaw gateway

# 后台启动服务
openclaw gateway start

# 运行配置菜单进行详细配置
bash ~/.openclaw/config-menu.sh

# 或从 GitHub 下载运行
curl -fsSL https://raw.githubusercontent.com/miaoxworld/OpenClawInstaller/main/config-menu.sh | bash
```

## ⚙️ 详细配置

### 配置 AI 模型

运行配置菜单后选择 `[2] AI 模型配置`，可选择多种 AI 提供商：

<p align="center">
  <img src="photo/llm.png" alt="OpenClaw AI 模型配置界面" width="600">
</p>

#### Anthropic Claude 配置

1. 在配置菜单中选择 Anthropic Claude
2. **先输入自定义 API 地址**（留空使用官方 API）
3. 输入 API Key（官方 Key 从 [Anthropic Console](https://console.anthropic.com/) 获取）
4. 选择模型（推荐 Sonnet 4.5）

> 💡 支持 OneAPI/NewAPI 等第三方代理服务，只需填入对应的 API 地址和 Key

#### OpenAI GPT 配置

1. 在配置菜单中选择 OpenAI GPT
2. **先输入自定义 API 地址**（留空使用官方 API）
3. 输入 API Key（官方 Key 从 [OpenAI Platform](https://platform.openai.com/) 获取）
4. 选择模型（推荐 GPT-4o）

#### Ollama 本地模型

```bash
# 1. 安装 Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# 2. 下载模型
ollama pull llama3.3

# 3. 在配置菜单中选择 Ollama
# 输入服务地址：http://localhost:11434
```

#### Groq (超快推理)

1. 访问 [Groq Console](https://console.groq.com/) 获取 API Key
2. 在配置菜单中选择 Groq
3. 输入 API Key
4. 选择模型（推荐 llama-3.3-70b-versatile 或 llama-4）

#### Google Gemini

1. 访问 [Google AI Studio](https://aistudio.google.com/app/apikey) 获取 API Key
2. 在配置菜单中选择 Google Gemini
3. 输入 API Key
4. 选择模型（推荐 gemini-2.0-flash 或 gemini-2.5-pro）

### 配置 Telegram 机器人

1. 在 Telegram 中搜索 `@BotFather`
2. 发送 `/newbot` 创建新机器人
3. 设置机器人名称和用户名
4. 复制获得的 **Bot Token**
5. 搜索 `@userinfobot` 获取你的 **User ID**
6. 在配置菜单中选择 Telegram，输入以上信息

### 配置 Discord 机器人

1. 访问 [Discord Developer Portal](https://discord.com/developers/applications)
2. 点击 "New Application" 创建应用
3. 进入 "Bot" 页面，点击 "Add Bot"
4. 复制 **Bot Token**
5. 在 "OAuth2" → "URL Generator" 中生成邀请链接
6. 邀请机器人到你的服务器
7. 获取目标频道的 **Channel ID**（右键频道 → 复制 ID）
8. 在配置菜单中输入以上信息

### 配置飞书机器人

1. 访问 [飞书开放平台](https://open.feishu.cn/)
2. 创建企业自建应用，选择"机器人"能力
3. 获取 **App ID** 和 **App Secret**
4. 在"权限管理"中添加权限：
   - `im:message.receive_v1` (接收消息)
   - `im:message:send_as_bot` (发送消息)
   - `im:chat:readonly` (读取会话信息)
5. 配置"事件订阅"：
   - 请求地址：`https://你的服务器:18789/channels/feishu/webhook`
   - 添加事件：`im.message.receive_v1`
6. 发布应用并添加到群组
7. 在配置菜单中选择飞书，输入以上信息

## 📝 常用命令

### 服务管理

```bash
# 启动服务（后台守护进程）
openclaw gateway start

# 停止服务
openclaw gateway stop

# 查看服务状态（表格格式，包含 OS/update/gateway/daemon/agents/sessions）
openclaw status

# 查看完整状态报告
openclaw status --all

# 前台运行（用于调试）
openclaw gateway --port 18789 --verbose

# 查看日志
openclaw logs

# 实时日志
openclaw logs --follow
```

### 配置管理

```bash
# 打开配置文件
openclaw config

# 运行配置向导
openclaw onboard --install-daemon

# 诊断配置问题
openclaw doctor

# 健康检查
openclaw health
```

### 消息发送（v2026.1.9+ 新格式）

```bash
# 发送消息（必须指定 provider，除非只配置了一个）
openclaw message send --to +1234567890 --message "Hello" --provider <provider>

# 轮询消息
openclaw message poll --provider <provider>
```

### Agent 交互

```bash
# 与助手对话
openclaw agent --message "Ship checklist" --thinking high

# 本地测试
openclaw agent --local --to "+1234567890" --message "Test message"
```

### 更新命令（v2026.1.10+ 新增）

```bash
# 更新到最新版本
openclaw update

# 或简写形式
openclaw --update
```

### 数据管理

```bash
# 导出对话历史
openclaw export --format json

# 清理记忆
openclaw memory clear

# 备份数据
openclaw backup
```

## 📋 配置说明

OpenClaw 使用以下配置方式：

- **环境变量**: `~/.openclaw/env` - 存储 API Key 和 Base URL
- **OpenClaw 配置**: `~/.openclaw/openclaw.json` - OpenClaw 内部配置（自动管理）
- **命令行工具**: `openclaw config set` / `openclaw models set` 等

> 💡 **注意**：配置主要通过安装向导或 `config-menu.sh` 完成，无需手动编辑配置文件

### 环境变量配置示例

`~/.openclaw/env` 文件内容：

```bash
# OpenClaw 环境变量配置
export ANTHROPIC_API_KEY=sk-ant-xxxxx
export ANTHROPIC_BASE_URL=https://your-api-proxy.com  # 可选，自定义 API 地址

# 或者 OpenAI
export OPENAI_API_KEY=sk-xxxxx
export OPENAI_BASE_URL=https://your-api-proxy.com/v1  # 可选
```

### 自定义 Provider 配置

当使用自定义 API 地址时，安装脚本会自动在 `~/.openclaw/openclaw.json` 中配置自定义 Provider：

```json
{
  "models": {
    "providers": {
      "anthropic-custom": {
        "baseUrl": "https://your-api-proxy.com",
        "apiKey": "your-api-key",
        "models": [
          {
            "id": "claude-sonnet-4-5-20250929",
            "name": "claude-sonnet-4-5-20250929",
            "api": "anthropic-messages",
            "input": ["text"],
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      }
    }
  }
}
```

### 目录结构

```
~/.openclaw/
├── openclaw.json        # OpenClaw 核心配置
├── env                  # 环境变量 (API Key 等)
├── backups/             # 配置备份
└── logs/                # 日志文件 (由 OpenClaw 管理)
```

## 🛡️ 安全建议

> ⚠️ **重要警告**：OpenClaw 需要完全的计算机权限，请务必注意安全！

### 部署建议

1. **不要在主工作电脑上部署** - 建议使用专用服务器或虚拟机
2. **使用 AWS/GCP/Azure 免费实例** - 隔离环境更安全
3. **Docker 部署** - 提供额外的隔离层
4. **沙箱模式** - 设置 `agents.defaults.sandbox.mode: "non-main"` 运行非主会话在 Docker 沙箱中

### 权限控制

1. **禁用危险功能**（默认已禁用）
   ```json
   {
     "security": {
       "enable_shell_commands": false,
       "enable_file_access": false
     }
   }
   ```

2. **启用沙箱模式**（推荐用于非主会话）
   ```json
   {
     "agents": {
       "defaults": {
         "sandbox": {
           "mode": "non-main"
         }
       }
     }
   }
   ```

3. **DM 配对策略**（防止未知用户访问）
   ```json
   {
     "channels": {
       "telegram": {
         "dmPolicy": "pairing",
         "allowFrom": ["your-user-id"]
       }
     }
   }
   ```

### API Key 安全

- 定期轮换 API Key
- 不要在公开仓库中提交配置文件
- 使用环境变量存储敏感信息
- 使用 `openclaw doctor` 检查配置安全性

```bash
# 使用环境变量
export ANTHROPIC_API_KEY="sk-ant-xxx"
export TELEGRAM_BOT_TOKEN="xxx"
```

## ❓ 常见问题

### Q: 安装时提示 Node.js 版本过低？

OpenClaw 需要 Node.js v22 或更高版本。

```bash
# macOS
brew install node@22
brew link --overwrite node@22

# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Q: 启动后无法连接？

1. 检查配置文件是否正确 (`~/.openclaw/openclaw.json`)
2. 运行诊断命令：`openclaw doctor`
3. 查看日志：`openclaw logs`
4. 检查健康状态：`openclaw health`

### Q: Telegram 机器人没有响应？

1. 确认 Bot Token 正确
2. 确认 User ID 在 `allowFrom` 列表中
3. 检查 DM 配对策略设置
4. 检查网络连接（可能需要代理）
5. 运行 `openclaw channels list` 查看渠道状态

### Q: 如何更新到最新版本？

```bash
# 方法 1: 使用 openclaw update 命令 (v2026.1.10+)
openclaw update

# 或简写
openclaw --update

# 方法 2: 使用 npm 更新
npm update -g openclaw

# 方法 3: 使用配置菜单
./config-menu.sh
# 选择 [7] 高级设置 → [7] 更新 OpenClaw
```

### Q: 如何备份数据？

```bash
# 手动备份
cp -r ~/.openclaw ~/openclaw_backup_$(date +%Y%m%d)

# 使用命令备份
openclaw backup
```

### Q: 如何完全卸载？

```bash
# 停止服务
openclaw gateway stop

# 卸载程序
npm uninstall -g openclaw

# 删除配置（可选）
rm -rf ~/.openclaw
```

## 📜 更新日志

### v1.1.0 (2026-01-30)
- 🔄 同步 OpenClaw v2026.1.24 命令变更
- 📝 命令从 `clawdbot` 更改为 `openclaw`
- ⚠️ `message` 命令改为子命令格式 `message send|poll|...`
- ✨ 新增 `openclaw update` 更新命令
- ✨ 新增 `openclaw status --all` 完整状态报告
- 🔒 更新安全配置说明（DM 配对策略）
- 📚 完善文档和常见问题

### v1.0.0 (2026-01-29)
- 🎉 首次发布
- ✨ 支持一键安装部署
- ✨ 交互式配置菜单
- ✨ 多模型支持 (Claude/GPT/Ollama)
- ✨ 多渠道支持 (Telegram/Discord/WhatsApp)
- ✨ 技能系统
- ✨ 安全配置

## 📄 许可证

本项目基于 MIT 许可证开源。

## 🔗 相关链接

- [OpenClaw 官网](https://openclaw.ai)
- [官方文档](https://docs.openclaw.ai)
- [安装工具仓库](https://github.com/miaoxworld/OpenClawInstaller)
- [OpenClaw 主仓库](https://github.com/openclaw/openclaw)
- [社区 Discord](https://discord.gg/clawd)
- [社区讨论](https://github.com/miaoxworld/OpenClawInstaller/discussions)

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/miaoxworld">miaoxworld</a>
</p>
