#!/usr/bin/env bash
# Store GLM (Z.ai coding plan) and MiniMax keys in macOS Keychain and point
# pi's auth.json at them, so no plaintext key lands on disk.
# Re-run any time to rotate a key; leave a prompt blank to skip it.
set -euo pipefail

AUTH="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/auth.json"
mkdir -p "$(dirname "$AUTH")"

# pi provider ids; keychain service = pi-<id>
providers=(zai minimax)   # use zai-coding-cn / minimax-cn style ids for China plans

for p in "${providers[@]}"; do
  read -rsp "API key for $p (blank = skip): " key; echo
  [[ -z "$key" ]] && continue
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
  echo "  $p -> Keychain (pi-$p), wired in $AUTH"
done
chmod 600 "$AUTH" 2>/dev/null || true
