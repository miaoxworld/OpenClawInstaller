# auto-install-Openclaw 官方 1:1 兼容性对照清单（2026-03-12）

基线来源（同日核验）：

- OpenClaw npm 最新版本：`2026.3.8`（`latest`）
- 官方安装器：`https://openclaw.ai/install.sh`
- 官方安装文档：`https://docs.openclaw.ai/install/installer`
- 官方插件文档：`https://docs.openclaw.ai/reference/cli/plugins`
- 官方飞书文档：`https://docs.openclaw.ai/channel/feishu`

## 17 项对照结果

| # | 官方基线 | 改造前状态 | 本次改造动作 | 验证点 |
|---|---|---|---|---|
| 1 | 安装器支持 `--install-method/--no-onboard/--no-prompt/--dry-run/--verbose` | 本项目安装器参数不完整 | `install.sh` 新增官方同名参数解析和帮助信息 | `install.sh --help` 可见同名参数 |
| 2 | 支持 `OPENCLAW_*` 环境变量，并兼容历史变量 | 仅部分变量，缺少历史映射 | 新增 `CLAWDBOT_* -> OPENCLAW_*` 映射 | `install.sh` 顶部变量映射函数 |
| 3 | Node 最低门槛为 22.12+ | 仅检查主版本 22+ | 升级为 `major/minor` 双维度检查（22.12+） | 版本检查逻辑中存在 `MIN_NODE_MAJOR/MIN_NODE_MINOR` |
| 4 | 核心安装行为以官方安装器为准 | 仅本地 `npm install -g` | 改为优先委托官方 `openclaw.ai/install.sh`，失败时 npm 回退（仅 npm 模式） | `install_openclaw_via_official` 函数 |
| 5 | 非交互自动化需可无提示执行 | `confirm` 始终依赖 TTY | `NO_PROMPT` 模式下默认按预设值执行 | `confirm()` 分支判断 `NO_PROMPT` |
| 6 | 升级链路：`update -> doctor -> plugins update --all` | 已部分对齐 | 继续保留并作为核心文档与脚本标准链路 | `config-menu.sh` 升级函数与 README 一致 |
| 7 | 插件更新应执行 `openclaw plugins update --all` | 已有但未作为强校验基线 | 预检脚本保留并强化该关键字检查 | `scripts/preflight-check.sh` |
| 8 | Feishu 仅官方插件 `@openclaw/feishu` | 历史环境可能残留同名冲突插件 | 飞书配置前强制清理同名插件并仅安装官方包（`--pin`） | `install_feishu_plugin()` |
| 9 | Feishu 配置推荐 `channels.feishu.accounts.main.*` | 旧写法 `channels.feishu.appId/appSecret` | 写入键切换到 `accounts.main`（并兼容读取旧路径） | `save_feishu_config()` + `quick_test_feishu()` |
|10 | 安装链接应清晰指向当前项目 | 仍有上游仓库链接残留 | 统一替换为 `leecyno1/auto-install-Openclaw` 一键安装地址 | README/install/config-menu/doc 链接 |
|11 | 发布前需可重复预检 | 仅基础检查 | preflight 持续校验语法、升级链路、飞书官方插件标记、README 指令 | `./scripts/preflight-check.sh` |
|12 | Moonshot(Kimi) 官方 provider 为 `moonshot` | 历史脚本写为 `kimi`，导致模型探针/状态异常 | 统一改为 `moonshot`，并兼容旧值读取 | `save_openclaw_ai_config` + `setup_ai_provider` + `config_kimi` |
|13 | OpenRouter/Mistral/Groq 使用各自官方环境变量 | 历史脚本错误复用 `OPENAI_API_KEY` | 改为 `OPENROUTER_API_KEY` / `MISTRAL_API_KEY` / `GROQ_API_KEY` | `install.sh` 与 `config-menu.sh` 环境变量写入逻辑 |
|14 | 官方默认模型已更新（Claude 4.6 / GPT-5.1-codex / Kimi K2.5 / Gemini 3.1） | 菜单仍含旧模型（4.5 时间戳、moonshot-v1 等） | 全量替换为官方当前默认与兼容选项 | `setup_ai_provider` 与 `config_*` 模型菜单 |
|15 | OpenCode 官方区分 Zen 与 Go 目录 | 仅单目录，且安装向导曾出现重复前缀 `opencode/opencode/*` | 增加 Zen/Go 目录选择并修复模型前缀拼接 | `config_opencode` + `save_openclaw_ai_config` |
|16 | 官方安装产物在不同平台可能仅暴露 `claw` 可执行名 | 配置脚本仅检测 `openclaw`，导致“已安装却判定未安装” | 增加 `openclaw/claw` 双通道解析与动态兼容别名 | `config-menu.sh` 的 `resolve_openclaw_bin` / `ensure_openclaw_alias` |
|17 | 安装完成后需保证 `openclaw` 命令在新会话可用 | 仅在当前会话临时补 PATH，可能下次终端失效 | 若仅有 `claw`，优先在同目录生成 `openclaw` shim，回退 `~/.local/bin` | `install.sh` 的 shim 生成逻辑（`install_openclaw`） |

## 结论

- 该仓库已切换为以“官方安装器行为”为基线的增强层（安装后配置/运维增强）。
- 飞书冲突路径已收敛到“先清理、再安装官方插件、再按官方键位写配置”。
- 模型链路已修复“配置成功但状态显示未配置”的主因（provider ID 与环境变量漂移）。
- 项目链接与一键安装入口已指向独立仓库 `auto-install-Openclaw`，后续可独立演进。
