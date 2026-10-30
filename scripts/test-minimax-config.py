#!/usr/bin/env python3
"""Offline installer regression tests; run with python3 scripts/test-minimax-config.py."""
import copy
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
CURRENT = ["MiniMax-M3.1-Flash", "MiniMax-M3"]


def function(source, name):
    """Load a shell function without executing the interactive script entrypoint."""
    text = (ROOT / source).read_text()
    start = text.index(name + "() {")
    following = re.search(r"^\w+\(\) \{", text[start + len(name) + 5:], re.M)
    end = start + len(name) + 5 + following.start() if following else len(text)
    return text[start:text.rfind("\n}", start, end) + 2]


class MiniMaxConfigTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix=".minimax-test-", dir=ROOT)
        self.addCleanup(self.directory.cleanup)
        self.work = Path(self.directory.name)
        self.config = self.work / "config's.json"
        self.env = {"PATH": os.environ["PATH"], "HOME": str(self.work), "LANG": "C.UTF-8"}

    def shell(self, script, *args, inputs=""):
        result = subprocess.run(["bash", "-c", script, "test", *args], input=inputs,
                                text=True, capture_output=True, env=self.env, cwd=ROOT)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def generate(self, source, runtime, provider, selected, original):
        self.config.write_text(json.dumps(original))
        hide_node = 'command() { if [[ "$*" == "-v node" ]]; then return 1; fi; builtin command "$@"; }\n'
        self.shell((hide_node if runtime == "python" else "") + function(source, "ensure_minimax_provider_config") +
                   '\nensure_minimax_provider_config "$1" "$2" "$3"', provider, selected, str(self.config))
        return json.loads(self.config.read_text())

    def test_fresh_catalog_and_region_runtime_parity(self):
        for source in ("install.sh", "config-menu.sh"):
            for provider, host in (("minimax", "api.minimax.io"), ("minimax-cn", "api.minimaxi.com")):
                results = []
                for runtime in ("node", "python"):
                    with self.subTest(source=source, provider=provider, runtime=runtime):
                        result = self.generate(source, runtime, provider, CURRENT[0], {})
                        p = result["models"]["providers"][provider]
                        self.assertEqual(p["baseUrl"], f"https://{host}/anthropic")
                        self.assertEqual(p["api"], "anthropic-messages")
                        self.assertEqual([m["id"] for m in p["models"]], CURRENT)
                        flash = p["models"][0]
                        self.assertEqual(flash["contextWindow"], 1000000)
                        self.assertEqual(flash["maxTokens"], 524288)
                        self.assertEqual(flash["input"], ["text", "image", "video"])
                        self.assertTrue(flash["reasoning"])
                        self.assertEqual(flash["cost"], {"input": .15, "output": .6, "cacheRead": .015})
                        self.assertEqual(result["agents"]["defaults"]["models"], {provider + "/" + CURRENT[0]: {"alias": "Minimax"}})
                        results.append(result)
                self.assertEqual(*results)

    def test_saved_custom_legacy_and_history_survive_refresh(self):
        for source in ("install.sh", "config-menu.sh"):
            for runtime in ("node", "python"):
                for provider in ("minimax", "minimax-cn"):
                    for selected in (CURRENT[0], CURRENT[1], "MiniMax-M2.7", "custom'\"\\model"):
                        with self.subTest(source=source, runtime=runtime, provider=provider, selected=selected):
                            ref = provider + "/" + selected
                            legacy = {"id": "MiniMax-M2.7", "name": "Saved legacy", "input": ["text"], "maxTokens": 1234}
                            custom = {"id": "custom'\"\\model", "name": "Saved custom", "input": ["text", "image"]}
                            original = {
                                "models": {"mode": "merge", "providers": {
                                    provider: {"api": "openai-completions", "baseUrl": "https://custom.invalid/v1", "authHeader": False,
                                               "headers": {"x-custom": "retained"}, "models": [legacy, custom, {"id": CURRENT[1], "customFlag": True}]},
                                    "unrelated": {"models": [{"id": "existing-model"}]}}},
                                "agents": {"defaults": {"model": {"primary": ref}, "models": {ref: {"alias": "Saved alias", "params": {"temperature": .5}}}}},
                                "messages": [{"role": "assistant", "content": [{"type": "thinking", "thinking": "saved", "signature": "signature"}, {"type": "tool_use", "id": "call", "name": "lookup", "input": {}}]},
                                             {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "call", "content": "result"}, {"type": "image", "source": {"url": "https://example.invalid/image.png"}}, {"type": "video", "source": {"url": "https://example.invalid/video.mp4"}}]}],
                            }
                            result = self.generate(source, runtime, provider, selected, copy.deepcopy(original))
                            p = result["models"]["providers"][provider]
                            for key in ("api", "baseUrl", "authHeader", "headers"):
                                self.assertEqual(p[key], original["models"]["providers"][provider][key])
                            self.assertEqual([m["id"] for m in p["models"][:2]], CURRENT)
                            self.assertEqual(p["models"][2:], [legacy, custom])
                            self.assertTrue(p["models"][1]["customFlag"])
                            self.assertEqual(result["agents"], original["agents"])
                            self.assertEqual(result["messages"], original["messages"])
                            self.assertEqual(result["models"]["providers"]["unrelated"], original["models"]["providers"]["unrelated"])
                            self.assertEqual(self.generate(source, runtime, provider, selected, result), result)

    def test_real_menus_save_config_and_pass_exact_model_to_cli(self):
        stubs = '''
clear_screen() { :; }; print_header() { :; }; print_divider() { :; }
print_menu_item() { printf '%s %s\\n' "$1" "$2"; }
log_info() { :; }; log_warn() { :; }; log_step() { :; }; press_enter() { :; }
confirm() { return 1; }; get_env_value() { printf fixture; }
read_secret_input() { printf -v "$2" fixture; }
check_command() { return 0; }; check_openclaw_installed() { return 0; }
ensure_openclaw_init() { :; }; add_env_to_shell() { :; }
openclaw() { printf '%s\\n' "$@" >> "$HOME/cli-args"; }
TTY_INPUT=/dev/stdin
OPENCLAW_ENV="$HOME/.openclaw/env"
OPENCLAW_JSON="$HOME/.openclaw/openclaw.json"
mkdir -p "$HOME/.openclaw"
'''
        for source in ("install.sh", "config-menu.sh"):
            for region, provider in (("1", "minimax"), ("2", "minimax-cn")):
                for choice, selected in (("", CURRENT[0]), ("2", CURRENT[1]), ("3", "MiniMax-M2.7"), ("3", "custom'\"\\model")):
                    with self.subTest(source=source, provider=provider, selected=selected):
                        (self.work / "cli-args").write_text("")
                        config = self.work / ".openclaw/openclaw.json"
                        config.parent.mkdir(exist_ok=True)
                        config.write_text("{}")
                        code = stubs + function(source, "ensure_minimax_provider_config") + "\n"
                        if source == "install.sh":
                            code += function(source, "setup_ai_provider") + "\n" + function(source, "configure_openclaw_model")
                            code += "\nsetup_ai_provider\nconfigure_openclaw_model\n"
                            inputs = f"12\n{region}\n{choice}\n"
                        else:
                            code += function(source, "config_minimax") + "\n" + function(source, "save_openclaw_ai_config") + "\nconfig_minimax\n"
                            inputs = f"{region}\n1\n{choice}\n"
                        if choice == "3":
                            inputs += selected + "\n"
                        output = self.shell(code, inputs=inputs)
                        self.assertIn("MiniMax-M3.1-Flash", output)
                        self.assertNotRegex(output, r"(?m)^\s*[12]\)? MiniMax-M2")
                        self.assertEqual((self.work / "cli-args").read_text().splitlines(), ["models", "set", provider + "/" + selected])
                        result = json.loads(config.read_text())
                        self.assertIn(provider + "/" + selected, result["agents"]["defaults"]["models"])
                        self.assertEqual([m["id"] for m in result["models"]["providers"][provider]["models"]], CURRENT)

    def test_gateway_menu_keeps_custom_ids_and_non_minimax_default(self):
        code = function("config-menu.sh", "config_opencode") + '''
clear_screen() { :; }; print_header() { :; }; print_divider() { :; }
print_menu_item() { printf '%s %s\\n' "$1" "$2"; }
get_env_value() { printf fixture; }; log_info() { :; }; press_enter() { :; }
confirm() { return 1; }
save_openclaw_ai_config() { printf '%s\\n' "$1" "$3" > "$HOME/selection"; }
TTY_INPUT=/dev/stdin
config_opencode
'''
        for choice, selected in (("", "kimi-k2.5"), ("3", "minimax-m3.1-flash-free"), ("4", "minimax-m3"), ("5", "minimax-m2.5")):
            with self.subTest(choice=choice):
                inputs = f"1\n2\n{choice}\n" + (selected + "\n" if choice == "5" else "")
                output = self.shell(code, inputs=inputs)
                self.assertNotIn("minimax-m2.5", output)
                self.assertEqual((self.work / "selection").read_text().splitlines(), ["opencode-go", selected])


if __name__ == "__main__":
    unittest.main(verbosity=2)
