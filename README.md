# auto-install-Openclaw

<p align="center">
  <img src="photo/openclaw-installer-logo.svg" alt="auto-install-Openclaw Logo" width="780" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-1.1.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-green.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Node.js-22%2B-brightgreen.svg" alt="Node">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">
</p>

> 一条命令安装 OpenClaw，自动完成依赖检查、模型配置、渠道接入、升级与诊断。

---

## 目录

- [项目定位](#项目定位)
- [一键安装的来由](#一键安装的来由)
- [核心优势](#核心优势)
- [界面截图](#界面截图)
- [快速开始](#快速开始)
- [操作手册](#操作手册)
- [配置说明](#配置说明)
- [飞书插件说明](#飞书插件说明)
- [升级与维护](#升级与维护)
- [安全建议](#安全建议)
- [常见问题](#常见问题)
- [相关链接](#相关链接)

---

## 项目定位

`auto-install-Openclaw` 是 OpenClaw 的命令行安装与配置中心，解决从“拿到 API Key”到“机器人在线可用”这一整段落地流程。

适用场景：

- 第一次部署 OpenClaw，希望快速上线
- 需要在多模型、多渠道之间快速切换
- 需要稳定的升级流程（含 doctor / plugins update）
- 希望把配置与运维操作标准化

---

## 一键安装的来由

OpenClaw 本身能力很强，但在实际部署中，用户常会遇到四类成本：

1. 环境成本：Node、依赖、权限、目录初始化。
2. 配置成本：模型提供商、API 地址、模型 ID、渠道凭证。
3. 验证成本：配置完不确定是否真正可用。
4. 升级成本：核心版本和插件版本容易不同步，导致“更新后不能用”。

本项目的一键安装，就是把这四类成本压缩到一条可重复执行的流程里：

- 装得上（依赖与目录自动处理）
- 配得起（交互式配置菜单）
- 跑得通（测试与诊断）
- 升得稳（官方升级链路 + 插件更新）

---

## 核心优势

- 一条命令完成主流程，降低上手门槛。
- 支持多模型提供商与多消息渠道，覆盖常见部署形态。
- 升级流程对齐官方建议：`openclaw update --restart` → `openclaw doctor` → `openclaw plugins update --all`。
- 飞书渠道仅使用官方插件 `@openclaw/feishu`，避免社区包冲突导致的升级不稳定。
- 配置菜单提供诊断、重启、快速测试与安全项设置。

---

## 界面截图

### 配置中心主界面

<p align="center">
  <img src="photo/menu.png" alt="配置中心主界面" width="780" />
</p>

### AI 模型配置

<p align="center">
  <img src="photo/llm.png" alt="AI 模型配置" width="780" />
</p>

### 消息渠道配置

<p align="center">
  <img src="photo/social.png" alt="消息渠道配置" width="780" />
</p>

### 快速测试与验证

<p align="center">
  <img src="photo/messages.png" alt="快速测试" width="780" />
</p>

---

## 快速开始

### 系统要求

| 项目 | 要求 |
|---|---|
| 操作系统 | macOS 12+ / Ubuntu 20.04+ / Debian 11+ / CentOS 8+ |
| Node.js | v22.12+ |
| 内存 | 最低 2GB，推荐 4GB+ |
| 磁盘空间 | 最低 1GB |

### 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/leecyno1/auto-install-Openclaw/main/install.sh | bash
```

安装脚本会自动执行：

1. 系统与依赖检查
2. OpenClaw 安装
3. AI 模型向导配置
4. API 连通性验证
5. 可选启动 Gateway
6. 可选进入配置菜单

### 手动安装

```bash
git clone https://github.com/leecyno1/auto-install-Openclaw.git
cd auto-install-Openclaw
chmod +x install.sh config-menu.sh
./install.sh
```

---

## 操作手册

### 1) 首次安装后

```bash
# 前台调试运行
source ~/.openclaw/env && openclaw gateway

# 后台服务运行
openclaw gateway start

# 查看状态
openclaw gateway status
```

### 2) 打开配置菜单

```bash
bash ./config-menu.sh
```

常用菜单路径：

- `[2]` AI 模型配置
- `[3]` 消息渠道配置
- `[7]` 快速测试
- `[8]` 高级设置（升级、备份、恢复）
- `[8]` 高级设置 → `[8]` AI 自动修复 OpenClaw（集成 `auto-fix-openclaw`，支持 Codex/Claude CLI）

AI 自动修复前置要求：

- 已安装并登录 Codex CLI（`codex login`）。
- 启动 AI 修复后，系统会自动读取错误日志摘要并向所选 CLI 发起修复请求。

### 3) 典型配置流程（建议）

1. 先配 AI 模型（并测试 API）。
2. 再配渠道（Telegram / Discord / Slack / 飞书等）。
3. 重启 Gateway 使渠道生效。
4. 执行快速测试与 doctor。

### 4) 飞书配置流程（简版）

1. 飞书开放平台创建应用，启用机器人能力。
2. 配置权限：`im:message`、`im:message:send_as_bot`、`im:chat:readonly`。
3. 在配置菜单中输入 `App ID` 与 `App Secret`。
4. 启动/重启 Gateway。
5. 在飞书后台启用长连接接收事件，添加 `im.message.receive_v1`。

详细说明见：`docs/feishu-setup.md`

---

## 配置说明

auto-install-Openclaw 当前推荐配置模型：

- 环境变量：`~/.openclaw/env`
- OpenClaw 主配置：`~/.openclaw/openclaw.json`

目录示例：

```text
~/.openclaw/
├── openclaw.json
├── env
├── backups/
└── logs/
```

### Docker 配置兼容说明

- 推荐与命令行安装一致：`env + openclaw.json`
- Docker 仍保留 `config.yaml.example` 作为历史兼容模板
- 旧配置迁移建议执行：

```bash
openclaw doctor --fix
openclaw plugins update --all
```

---

## 飞书插件说明

本仓库已统一为 **仅官方插件**：

- `@openclaw/feishu`

这样做的目的：

- 减少升级后插件冲突
- 降低社区包与官方核心版本漂移带来的故障
- 对齐官方渠道生态，便于维护与排障

---

## 升级与维护

推荐升级链路：

```bash
openclaw update --restart
openclaw doctor --fix
openclaw plugins update --all
```

通过配置菜单升级：

```bash
./config-menu.sh
# [8] 高级设置 -> [6] 更新 OpenClaw
```

常用运维命令：

```bash
openclaw gateway start
openclaw gateway stop
openclaw gateway restart
openclaw logs --follow
openclaw doctor
openclaw health
```

---

## 安全建议

- 建议在专用机器/容器部署，不要直接放在主力办公机。
- API Key 统一放环境变量，不提交到仓库。
- 如启用系统命令与文件访问，请配合白名单路径与沙箱策略。
- 定期备份 `~/.openclaw` 目录。

---

## 常见问题

### Q1: 安装完成后命令找不到？

```bash
source ~/.openclaw/env
openclaw --version
```

必要时重开终端或检查 shell 配置是否已加载 env。

### Q2: 升级后某个渠道异常？

优先执行：

```bash
openclaw doctor --fix
openclaw plugins update --all
openclaw gateway restart
```

### Q3: 飞书不回复？

检查：

1. 插件是否安装：`openclaw plugins list | grep feishu`
2. 渠道是否注册：`openclaw channels list`
3. 事件订阅是否添加 `im.message.receive_v1`
4. Gateway 是否在运行：`openclaw gateway status`

---

## 相关链接

- OpenClaw 官网：https://openclaw.ai
- OpenClaw 文档：https://docs.openclaw.ai
- OpenClaw 主仓库：https://github.com/openclaw/openclaw
- Installer 仓库（当前项目）：https://github.com/leecyno1/auto-install-Openclaw

---
