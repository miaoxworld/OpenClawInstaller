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

- [系统要求](#-系统要求)
- [快速开始](#-快速开始)
- [功能特性](#-功能特性)
- [详细配置](#-详细配置)
- [常用命令](#-常用命令)
- [配置说明](#-配置说明)
- [安全建议](#-安全建议)
- [常见问题](#-常见问题)
- [更新日志](#-更新日志)

## 💻 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 12+ / Ubuntu 20.04+ / Debian 11+ / CentOS 8+ |
| Node.js | v22 或更高版本 |
| 内存 | 最低 2GB，推荐 4GB+ |
| 磁盘空间 | 最低 1GB |

## 🚀 快速开始

### 🖥️ 桌面版 OpenClaw Manager（推荐）

如果你更喜欢图形界面，推荐使用 **OpenClaw Manager** 桌面应用：

<p align="center">
  <a href="https://github.com/miaoxworld/openclaw-manager">
    <img src="https://img.shields.io/badge/下载桌面版-OpenClaw%20Manager-blue?style=for-the-badge&logo=github" alt="Download">
  </a>
</p>

- 🎨 **现代化 UI** - 基于 Tauri 2.0 + React + TypeScript + Rust 构建
- 📊 **实时监控** - 仪表盘查看服务状态、内存、运行时间
- 🔧 **可视化配置** - AI 模型、消息渠道一键配置
- 💻 **跨平台** - 支持 macOS、Windows、Linux

👉 **下载地址**: [github.com/miaoxworld/openclaw-manager](https://github.com/miaoxworld/openclaw-manager)

---

### 方式一：一键安装（命令行版）

```bash
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

#如果mac有权限问题，可以手动安装clawbot之后再运行install
npm install -g openclaw
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

## ✨ 功能特性

### 🤖 多模型支持

<p align="center">
  <img src="photo/llm.png" alt="AI 模型配置" width="600">
</p>

**主流服务商:**
- **Anthropic Claude** - claude-sonnet-4-5 / claude-opus-4-5 / claude-haiku-4-5 *(支持自定义 API 地址)*
- **OpenAI GPT** - gpt-4o / gpt-4o-mini / gpt-4-turbo *(支持自定义 API 地址，需支持 v1/responses)*
- **Google Gemini** - gemini-2.0-flash / gemini-1.5-pro / gemini-1.5-flash

**多模型网关:**
- **OpenRouter** - 多模型网关，一个 Key 用遍所有模型 (claude-sonnet-4 / gpt-4o / gemini-pro-1.5)

**快速推理:**
- **Groq** - 超快推理，llama-3.3-70b-versatile / llama-3.1-8b-instant / mixtral-8x7b
- **Mistral AI** - mistral-large-latest / mistral-small-latest / codestral-latest

**本地部署:**
- **Ollama** - 本地部署，无需 API Key (llama3 / llama3:70b / mistral)

> 💡 **自定义 API 地址**: Anthropic Claude 和 OpenAI GPT 都支持自定义 API 地址，可接入 OneAPI/NewAPI/API 代理等服务。配置时先输入自定义地址，再输入 API Key。
>
> ⚠️ **OpenAI 中转要求**: 自定义 OpenAI API 地址必须支持 `v1/responses` 路径（OpenAI Responses API），不仅仅是传统的 `v1/chat/completions`。请确认您的中转服务已支持此接口。

### 📱 多渠道接入

<p align="center">
  <img src="photo/social.png" alt="消息渠道配置" width="600">
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
  <img src="photo/messages.png" alt="快速测试" width="600">
</p>

- API 连接测试
- 渠道连接验证
- OpenClaw 诊断工具

### 🧠 核心能力
- **持久记忆** - 跨对话、跨平台的长期记忆
- **主动推送** - 定时提醒、晨报、告警通知
- **技能系统** - 通过 Markdown 文件定义自定义能力
- **远程控制** - 可执行系统命令、读写文件、浏览网络

## ⚙️ 详细配置

### 配置 AI 模型

运行配置菜单后选择 `[2] AI 模型配置`，可选择多种 AI 提供商：

<p align="center">
  <img src="photo/llm.png" alt="AI 模型配置界面" width="600">
</p>

#### Anthropic Claude 配置

1. 在配置菜单中选择 Anthropic Claude
2. **先输入自定义 API 地址**（留空使用官方 API）
3. 输入 API Key（官方 Key 从 [Anthropic Console](https://console.anthropic.com/) 获取）
4. 选择模型（推荐 claude-sonnet-4-5-20250929）

> 💡 支持 OneAPI/NewAPI 等第三方代理服务，只需填入对应的 API 地址和 Key

#### OpenAI GPT 配置

1. 在配置菜单中选择 OpenAI GPT
2. **先输入自定义 API 地址**（留空使用官方 API）
3. 输入 API Key（官方 Key 从 [OpenAI Platform](https://platform.openai.com/) 获取）
4. 选择模型

> ⚠️ **中转服务要求**: 如使用自定义 API 地址，中转服务必须支持 OpenAI 的 **Responses API** (`v1/responses` 路径)，而非仅支持传统的 Chat Completions API (`v1/chat/completions`)。部分老旧或功能不全的中转服务可能不支持此接口，请提前确认。

> 💡 **其他模型**: 配置菜单还支持 Google Gemini、OpenRouter、Groq、Mistral AI、Ollama 等，按菜单提示操作即可。

### 配置 Telegram 机器人

1. 在 Telegram 中搜索 `@BotFather`
2. 发送 `/newbot` 创建新机器人
3. 设置机器人名称和用户名
4. 复制获得的 **Bot Token**
5. 搜索 `@userinfobot` 获取你的 **User ID**
6. 在配置菜单中选择 Telegram，输入以上信息

### 配置 Discord 机器人

**第一步：创建 Discord 应用和机器人**

1. 访问 [Discord Developer Portal](https://discord.com/developers/applications)
2. 点击 "New Application" 创建新应用
3. 进入应用后，点击左侧 "Bot" 菜单
4. 点击 "Reset Token" 生成并复制 **Bot Token**
5. ⚠️ **开启 "Message Content Intent"**（重要！否则无法读取消息内容）

**第二步：邀请机器人到服务器**

1. 点击左侧 "OAuth2" → "URL Generator"
2. Scopes 勾选：`bot`
3. Bot Permissions 至少勾选：
   - View Channels（查看频道）
   - Send Messages（发送消息）
   - Read Message History（读取消息历史）
4. 复制生成的 URL，在浏览器打开并选择服务器
5. 确保机器人在目标频道有权限

**第三步：获取频道 ID**

1. 打开 Discord 客户端，进入 "用户设置" → "高级"
2. 开启 "开发者模式"
3. 右键点击你想让机器人响应的频道
4. 点击 "复制频道 ID"

**第四步：在配置菜单中配置**

在配置菜单中选择 Discord，输入 Bot Token 和 Channel ID

### 配置飞书机器人

> 📖 **详细文档**: 查看 [飞书机器人配置指南](docs/feishu-setup.md) 获取完整的配置说明和常见问题解答。

> 💡 **无需公网服务器**：OpenClaw 使用飞书的 WebSocket 长连接模式接收事件，无需配置 Webhook 地址。

1. 访问 [飞书开放平台](https://open.feishu.cn/)
2. 创建企业自建应用（个人账号即可，无需企业认证）
3. **添加机器人能力**：
   - 进入路径：开发者后台 → 应用详情 → 添加应用能力
   - 确认：确保"机器人"开关是打开状态
4. 获取 **App ID** 和 **App Secret**
5. 在"权限管理"中添加权限：
   - `im:message` (收发消息)
   - `im:message:send_as_bot` (发送消息)
   - `im:chat:readonly` (读取会话信息)
6. 发布应用：版本管理与发布 → 创建版本 → 发布
7. **在配置菜单中配置飞书**：输入 App ID 和 App Secret，启动 OpenClaw 服务
8. 配置"事件订阅"（使用长连接）：
   - 进入：事件与回调 → 选择「**使用长连接接收事件**」
   - 添加事件：`im.message.receive_v1`（接收消息）
   - **无需填写 Webhook 地址**
   - ⚠️ **注意**：需要 OpenClaw 服务已启动，才能保存长连接设置
9. 添加机器人到群组：群设置 → 群机器人 → 添加机器人

### 配置 WhatsApp

> 💡 **无需 Business API**：OpenClaw 通过扫码登录你的 WhatsApp 账号，无需申请 Business API。

1. 在配置菜单中选择 `[3] 消息渠道配置` → `[3] WhatsApp`
2. 系统会自动启用 WhatsApp 插件
3. 扫描终端显示的二维码完成登录
4. 登录成功后重启 Gateway 使配置生效
5. **测试**：用自己的 WhatsApp 给自己发消息即可触发机器人回复

> ⚠️ **注意**：WhatsApp 账号只能在一个设备上登录 Web 版，配置后原有的 WhatsApp Web 会被踢下线。

## 📝 常用命令

### 服务管理

```bash
# 启动服务（后台守护进程）
openclaw gateway start

# 停止服务
openclaw gateway stop

# 重启服务
openclaw gateway restart

# 查看服务状态
openclaw gateway status

# 前台运行（用于调试）
openclaw gateway

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
openclaw onboard

# 诊断配置问题
openclaw doctor

# 健康检查
openclaw health
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

### 权限控制

1. **禁用危险功能**（默认已禁用）
   ```yaml
   security:
     enable_shell_commands: false
     enable_file_access: false
   ```

2. **启用沙箱模式**
   ```yaml
   security:
     sandbox_mode: true
   ```

3. **限制允许的用户**
   ```yaml
   channels:
     telegram:
       allowed_users:
         - "only-your-user-id"
   ```

### API Key 安全

- 定期轮换 API Key
- 不要在公开仓库中提交配置文件
- 使用环境变量存储敏感信息

```bash
# 使用环境变量
export ANTHROPIC_API_KEY="sk-ant-xxx"
export TELEGRAM_BOT_TOKEN="xxx"
```

## ❓ 常见问题

### Q: 安装时提示 Node.js 版本过低？

```bash
# macOS
brew install node@22
brew link --overwrite node@22

# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Q: 启动后无法连接？

1. 检查配置文件是否正确
2. 运行诊断命令：`openclaw doctor`
3. 查看日志：`openclaw logs`

### Q: Telegram 机器人没有响应？

1. 确认 Bot Token 正确
2. 确认 User ID 在 allowed_users 列表中
3. 检查网络连接（可能需要代理）

### Q: 如何更新到最新版本？

```bash
# 使用 npm 更新
npm update -g openclaw

# 或使用配置菜单
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

- [OpenClaw 官网](https://clawd.bot)
- [官方文档](https://clawd.bot/docs)
- [🖥️ OpenClaw Manager 桌面版](https://github.com/miaoxworld/openclaw-manager) - 图形界面管理工具
- [安装工具仓库](https://github.com/miaoxworld/OpenClawInstaller) - 命令行版本
- [OpenClaw 主仓库](https://github.com/openclaw/openclaw)
- [社区讨论](https://github.com/miaoxworld/OpenClawInstaller/discussions)

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/miaoxworld">miaoxworld</a>
</p>
