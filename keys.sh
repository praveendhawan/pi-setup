#!/usr/bin/env bash
# Take GLM (Z.ai coding plan), MiniMax and BlazeInfer keys from .env (or the environment),
# store them in macOS Keychain and point pi's auth.json at them. Works for
# pi-gui launched from the Dock too, with no shell env needed.
# Re-run after changing a key in .env; an empty variable is skipped.
set -euo pipefail

ENV_FILE="$(dirname "$0")/.env"
[[ -f "$ENV_FILE" ]] && { set -a; . "$ENV_FILE"; set +a; }

AUTH="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/auth.json"
mkdir -p "$(dirname "$AUTH")"

# pi provider id -> env var; keychain service = pi-<id>
# (China plans: use zai-coding-cn / minimax-cn style ids)
for pair in zai:ZAI_API_KEY minimax:MINIMAX_API_KEY blaze:BLAZE_API_KEY; do
  p="${pair%%:*}"; var="${pair#*:}"; key="${!var:-}"
  [[ -z "$key" ]] && { echo "  $p: $var empty, skipped"; continue; }
  security add-generic-password -U -a "$USER" -s "pi-$p" -w "$key"
  python3 - "$AUTH" "$p" <<'PY'
import json, os, sys
path, prov = sys.argv[1], sys.argv[2]
data = json.load(open(path)) if os.path.exists(path) else {}
data[prov] = {"type": "api_key", "key": f"!security find-generic-password -ws pi-{prov}"}
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as f:
    json.dump(data, f, indent=2)
PY
  echo "  $p: $var -> Keychain (pi-$p), wired in $AUTH"
done
chmod 600 "$AUTH" 2>/dev/null || true

# BlazeInfer is not built in: register it as a custom provider in models.json
# (https://blazeinfer.ai/docs/integrations/pi). Its key comes from auth.json above.
if [[ -n "${BLAZE_API_KEY:-}" ]]; then
  python3 - "$(dirname "$AUTH")/models.json" <<'PY'
import json, os, sys
path = sys.argv[1]
data = json.load(open(path)) if os.path.exists(path) else {}
data.setdefault("$schema", "https://pi.dev/schemas/models.schema.json")
data.setdefault("providers", {})["blaze"] = {
    "name": "BlazeInfer",
    "baseUrl": "https://blaze.e2enetworks.net/v1",
    "api": "openai-completions",
    "models": [
        {"id": "deepseek-ai/deepseek-v4.1-flash", "name": "DeepSeek V4.1 Flash (BlazeInfer)",
         "reasoning": True, "input": ["text", "image"], "contextWindow": 1048576,
         "maxTokens": 16384, "compat": {"supportsReasoningEffort": False}},
        # docs: GLM 5.3 Flash does not accept images (console lists Vision; docs win)
        {"id": "zai-org/glm-5.3-flash", "name": "GLM 5.3 Flash (BlazeInfer)",
         "reasoning": True, "input": ["text"], "contextWindow": 1310720, "maxTokens": 16384},
        {"id": "qwen/qwen3.8-27b", "name": "Qwen3.8 27B (BlazeInfer)",
         "reasoning": True, "input": ["text", "image"], "contextWindow": 128000, "maxTokens": 16384},
        {"id": "moonshotai/kimi-k3", "name": "Kimi K3 (BlazeInfer)",
         "reasoning": True, "input": ["text", "image"], "contextWindow": 256000, "maxTokens": 16384},
        {"id": "google/gemma-4-31b-it", "name": "Gemma 4 31B (BlazeInfer)",
         "reasoning": True, "input": ["text", "image"], "contextWindow": 100000, "maxTokens": 16384},
    ],
}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY
  echo "  blaze: provider registered in $(dirname "$AUTH")/models.json"
fi
