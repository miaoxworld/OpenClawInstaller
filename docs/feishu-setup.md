# 🔷 飞书机器人配置指南

本文档详细介绍如何配置 OpenClaw 的飞书消息渠道。

## 📋 前置要求

- 已安装 OpenClaw（运行 `install.sh` 完成安装）
- 飞书账号（个人账号即可，无需企业认证）
- Installer 已更新为仅使用官方飞书插件：`@openclaw/feishu`

## ✨ 特性说明

OpenClaw 飞书渠道具有以下特性：

- ✅ **无需公网服务器** - 使用 WebSocket 长连接模式
- ✅ **无需企业认证** - 个人账号即可创建"企业自建应用"
- ✅ **支持私聊和群聊** - 群聊中 @机器人 触发回复
- ✅ **支持多媒体消息** - 图片、文件等

## 🚀 配置步骤

### 第一步：创建飞书应用

1. 访问 [飞书开放平台](https://open.feishu.cn/)
2. 登录后点击右上角「创建应用」
3. 选择「企业自建应用」（个人账号也可以创建）
4. 填写应用名称（如 "OpenClaw"）和描述

### 第二步：添加机器人能力

1. 进入应用详情页
2. 点击左侧菜单「添加应用能力」
3. 找到「机器人」能力，点击添加
4. 确认「机器人」开关已开启

> 💡 **路径**: 开发者后台 → 应用详情 → 添加应用能力 → 机器人

### 第三步：获取应用凭证

在应用详情页的「凭证与基础信息」中，复制以下信息：

- **App ID** - 应用唯一标识
- **App Secret** - 应用密钥（点击显示后复制）

⚠️ 请妥善保管 App Secret，不要泄露给他人。

### 第四步：配置权限

1. 点击左侧菜单「权限管理」
2. 搜索并添加以下权限：

| 权限名称 | 权限标识 | 说明 |
|---------|---------|------|
| 获取与发送单聊、群组消息 | `im:message` | 收发消息（必须） |
| 以应用的身份发消息 | `im:message:send_as_bot` | 发送消息（必须） |
| 获取群组信息 | `im:chat:readonly` | 读取群信息（推荐） |

#### ✅ 权限授权清单（推荐批量导入）

上表是“最小可用”的权限集，但在实际使用（尤其是多媒体、群成员信息、配对/私聊路由等）时，权限不全会导致：

- 网关能连上，但收不到消息
- 能收消息但无法发图/文件
- 部分 API 调用 403/权限不足

推荐使用飞书后台 **权限管理 → 批量导入**，粘贴官方推荐的 scopes JSON：

<details>
<summary>点击展开：官方推荐 scopes（批量导入 JSON）</summary>

```json
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
```

</details>

### 第五步：发布应用

1. 点击左侧菜单「版本管理与发布」
2. 点击「创建版本」
3. 填写版本号和更新说明
4. 设置可用范围（选择可使用此应用的人/部门）
5. 点击「保存」然后「申请发布」

> 💡 内部应用通常会自动审核通过，无需等待。

### 第六步：在 OpenClaw 中配置飞书

运行配置菜单：

```bash
# 在本仓库目录运行
bash ./config-menu.sh

# 或者多源下载运行（内置超时与自动回退）
bash -c 'set -e; tmp="$(mktemp)"; for u in \
"https://raw.githubusercontent.com/leecyno1/auto-install-Openclaw/main/config-menu.sh" \
"https://mirror.ghproxy.com/https://raw.githubusercontent.com/leecyno1/auto-install-Openclaw/main/config-menu.sh" \
"https://cdn.jsdelivr.net/gh/leecyno1/auto-install-Openclaw@main/config-menu.sh"; do \
  echo "Try: $u"; \
  if curl -fsSL --proto "=https" --tlsv1.2 --connect-timeout 8 --max-time 25 "$u" -o "$tmp"; then \
    bash "$tmp"; rm -f "$tmp"; exit 0; \
  fi; \
done; rm -f "$tmp"; echo "All sources failed. 请稍后重试或更换网络。"; exit 1'
```

1. 选择 `[3] 消息渠道配置`
2. 选择 `[7] 飞书 (Feishu)`
3. 按提示输入 **App ID** 和 **App Secret**
4. 配置完成后选择「是」重启 Gateway

配置菜单会按官方结构写入：

```bash
openclaw config set channels.feishu.accounts.main.appId "<APP_ID>"
openclaw config set channels.feishu.accounts.main.appSecret "<APP_SECRET>"
```

### 第七步：配置事件订阅（长连接）

> ⚠️ **重要**: 此步骤需要 OpenClaw 服务已启动，否则无法保存长连接设置。

先确认网关已启动（否则“长连接接收事件”很可能保存失败）：

```bash
openclaw gateway status
openclaw logs --follow
```

1. 回到飞书开放平台，进入应用详情
2. 点击左侧菜单「事件与回调」
3. 选择「**使用长连接接收事件**」（不是 Webhook）
4. 点击「添加事件」，添加以下事件：

| 事件名称 | 事件标识 | 说明 |
|---------|---------|------|
| 接收消息 | `im.message.receive_v1` | 必须 |
| 消息已读 | `im.message.message_read_v1` | 可选 |
| 机器人进群 | `im.chat.member.bot.added_v1` | 可选 |

5. 点击「保存」

> 💡 使用长连接模式**无需填写 Webhook 地址**，无需公网服务器。

### 第八步：添加机器人到群组

**方法一：在飞书客户端添加**

1. 打开飞书，进入目标群组
2. 点击右上角群设置（⚙️ 图标）
3. 点击「群机器人」→「添加机器人」
4. 搜索你的机器人名称并添加

**方法二：创建新群并添加**

1. 创建一个新的群组
2. 在创建时直接添加机器人
3. 或创建后在群设置中添加

## 🧪 测试配置

### 方法一：使用配置菜单测试

```bash
bash ~/.openclaw/config-menu.sh
```

1. 选择 `[7] 快速测试`
2. 选择 `[5] 测试飞书机器人`
3. 系统会自动读取已配置的凭据
4. 可选输入群组 Chat ID 发送测试消息

### 方法二：直接在群里测试

1. 在已添加机器人的群组中
2. @机器人 发送消息
3. 等待机器人回复

### 私聊需要配对（pairing）

默认私聊策略通常是 `dmPolicy: pairing`。如果机器人在私聊里回复了配对码，需要在服务器侧批准：

```bash
openclaw pairing list feishu
openclaw pairing approve feishu <CODE>
```

### 获取群组 Chat ID

如需获取群组 Chat ID 用于测试：

1. 打开群组设置
2. 查看「群信息」
3. 复制群号（以 `oc_` 开头的字符串）

## ❓ 常见问题

### Q: 长连接保存失败？

**A**: 确保 OpenClaw 服务已启动。飞书后台需要检测到客户端连接才能保存长连接设置。

```bash
# 启动服务
openclaw gateway start

# 查看状态
openclaw gateway status
```

### Q: 机器人不回复消息？

检查以下几点：

1. **服务是否运行**: `openclaw gateway status`
2. **事件订阅是否配置**: 确保添加了 `im.message.receive_v1` 事件
3. **权限是否完整**: 推荐使用“批量导入 scopes JSON”（见上方权限清单）
4. **应用是否发布**: 未发布的应用无法正常使用
5. **机器人是否在群里**: 确保机器人已添加到群组
6. **私聊是否需要配对**: `openclaw pairing list feishu`

### Q: 群聊中如何触发机器人？

默认情况下，群聊中需要 **@机器人** 才会触发回复，这样可以避免机器人响应所有消息。

### Q: 私聊机器人不回复？

1. 确保你在应用的「可用范围」内
2. 尝试在飞书中搜索机器人名称，点击进入私聊
3. 发送消息测试

### Q: 如何查看日志排查问题？

```bash
# 查看实时日志
openclaw logs --follow

# 运行诊断
openclaw doctor
```

## 🔧 高级配置

### 修改群组响应策略

默认群聊需要 @机器人 才响应。如需修改：

```bash
# 设置不需要 @机器人 也响应（谨慎使用）
openclaw config set channels.feishu.requireMention false
```

### 切换到国际版 Lark

如使用国际版 Lark 而非飞书：

```bash
openclaw config set channels.feishu.domain "lark"
```

## 📚 相关链接

- [飞书开放平台](https://open.feishu.cn/)
- [飞书开放平台文档](https://open.feishu.cn/document/)
- [OpenClaw 主仓库](https://github.com/openclaw/openclaw)
- [安装工具仓库](https://github.com/leecyno1/auto-install-Openclaw)

---

如有问题，请在 [GitHub Issues](https://github.com/leecyno1/auto-install-Openclaw/issues) 中反馈。
