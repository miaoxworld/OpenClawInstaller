#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }

# 1) Shell 语法检查
bash -n install.sh || fail "install.sh syntax"
bash -n config-menu.sh || fail "config-menu.sh syntax"
bash -n docker-entrypoint.sh || fail "docker-entrypoint.sh syntax"
pass "shell syntax"

# 2) 官方升级链路关键字检查
grep -q "openclaw update --restart" config-menu.sh || fail "missing openclaw update --restart in config-menu.sh"
grep -q "openclaw plugins update --all" config-menu.sh || fail "missing plugins update --all in config-menu.sh"
pass "upgrade pipeline markers"

# 3) 飞书官方插件默认检查
grep -q 'FEISHU_PLUGIN_OFFICIAL="@openclaw/feishu"' config-menu.sh || fail "missing official feishu plugin default"
grep -q "channels.feishu.accounts.main.appId" config-menu.sh || fail "missing feishu accounts.main.appId config path"
grep -q 'openclaw plugins install "$preferred_spec" --pin' config-menu.sh || fail "missing pinned official feishu install"
pass "feishu plugin default marker"

# 4) 安装器官方兼容关键点
grep -q -- "--install-method, --method" install.sh || fail "install.sh missing official install-method flag"
grep -q "OFFICIAL_INSTALL_URL=\"https://openclaw.ai/install.sh\"" install.sh || fail "install.sh missing official installer url"
grep -q "MIN_NODE_MINOR=12" install.sh || fail "install.sh missing Node 22.12+ floor"
grep -q "INSTALLER_MIRROR_RAW_URL=" install.sh || fail "install.sh missing installer mirror support"
pass "installer compatibility markers"

# 5) 文档命令一致性检查
grep -q "openclaw update --restart" README.md || fail "README missing official upgrade command"
grep -q "openclaw plugins update --all" README.md || fail "README missing plugin update command"
grep -q "raw.githubusercontent.com/miaoxworld/OpenClawInstaller/main/install.sh" README.md || fail "README missing public one-click url"
grep -q 'INSTALLER_MIRROR_RAW_URL="${OPENCLAW_INSTALLER_MIRROR_RAW_URL:-https://mirror.ghproxy.com/${GITHUB_RAW_URL}}"' install.sh || fail "install.sh missing configurable mirror fallback"
pass "README command markers"

# 6) Public installer entrypoint and upstream asset source are intentionally distinct.
grep -q 'GITHUB_REPO="${GITHUB_REPO:-leecyno1/auto-install-Openclaw}"' install.sh || fail "missing configured upstream asset source"
pass "public repository and upstream source markers"

# 7) Non-interactive runs must not enter the interactive onboarding/channel menu.
grep -q 'NO_PROMPT 模式下跳过交互式配置向导和渠道菜单' install.sh || fail "--no-prompt does not skip interactive onboarding"
pass "non-interactive onboarding marker"

# 8) 1:1 清单文档存在性检查
[ -f docs/official-compatibility-checklist.md ] || fail "missing official compatibility checklist doc"
pass "compatibility checklist doc"

# 9) auto-fix-openclaw + Claude/Codex 修复入口检查
grep -q 'AUTO_FIX_OPENCLAW_REPO_URL=' config-menu.sh || fail "missing auto-fix-openclaw repo variable"
grep -q 'AI 自动修复 OpenClaw' config-menu.sh || fail "missing AI auto-fix menu entry"
grep -q '执行 AI 修复（选择 Claude/Codex）' config-menu.sh || fail "missing unified AI repair entry"
grep -q 'choose_auto_fix_repair_provider' config-menu.sh || fail "missing provider chooser function"
grep -q 'check_codex_ready' config-menu.sh || fail "missing codex readiness guard"
grep -q 'codex login status' config-menu.sh || fail "missing codex login status check"
grep -q '自动读取错误日志摘要' config-menu.sh || fail "missing log-driven repair hint"
grep -q 'run_auto_fix_provider_repair codex' config-menu.sh || fail "missing codex repair entry"
grep -q 'run_auto_fix_provider_repair claudecode' config-menu.sh || fail "missing claudecode repair entry"
pass "auto-fix menu markers"

echo "All preflight checks passed."
