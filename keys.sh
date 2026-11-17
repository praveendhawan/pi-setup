#!/usr/bin/env bash
# Take GLM (Z.ai coding plan) and MiniMax keys from .env (or the environment),
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
for pair in zai:ZAI_API_KEY minimax:MINIMAX_API_KEY; do
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
