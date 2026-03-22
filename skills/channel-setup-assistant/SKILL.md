# 渠道配置助手 Skill（OpenClaw）

## 目标
当用户提供消息渠道相关信息时，使用结构化对话补齐缺失字段，并执行命令行完成渠道配置、验证和重启。

## 触发条件
- 用户说“配置消息渠道”“接入飞书/企业微信/QQ/微信/Telegram/Discord/Slack”
- 用户提供了部分渠道凭据，要求你代为完成命令行配置

## 执行流程
1. 确认渠道类型。
2. 按该渠道必填项逐条收集（一次最多问 2 项）。
3. 回显将执行的命令，确认后执行。
4. 执行后立即做健康检查与连通验证。
5. 输出可复制的结果摘要（成功/失败、下一步）。

## 通用命令模板
```bash
openclaw channels list
openclaw doctor --fix
openclaw gateway restart
```

## 渠道必填项清单

### 飞书（官方）
- `appId`
- `appSecret`

### 企业微信 WeCom（社区）
- 模式 `bot/app/both`
- Bot：`token` `encodingAESKey` `receiveId` `webhookPath`
- App：`corpId` `corpSecret` `agentId` `callbackToken` `callbackAesKey` `webhookPath`

### 微信 WeChatPad（社区）
- `proxyUrl`
- `apiKey`
- `webhookHost`
- `webhookPort`
- `webhookPath`

### QQ（社区）
- `appId`
- `appSecret`
- `allowFrom`（建议白名单）

### Telegram
- `botToken`
- `userId`

### Discord
- `botToken`
- `channelId`

### Slack
- `botToken(xoxb-)`
- `appToken(xapp-)`

## 结果输出格式
1. 执行的关键命令
2. `doctor` 结果摘要
3. `channels list` 中对应渠道状态
4. 下一步建议（若失败，给 1-3 条可执行排障命令）
