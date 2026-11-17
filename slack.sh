#!/usr/bin/env bash
# Slack for pi via Pinet (@pinet/slack-bridge, https://github.com/gugu91/pinet).
# A pi extension: the pi session itself connects to Slack over Socket Mode
# (outbound only, no public URL / tunnel needed) and uses pi's own logins.
#
# Before running: create the Slack app from Pinet's manifest
#   ~/.pi/agent/npm/node_modules/@pinet/slack-bridge/manifest.yaml
# and fill SLACK_* in .env (see .env.sample).
# Re-run after changing SLACK_MEMBER_ID.
set -euo pipefail

ENV_FILE="$(dirname "$0")/.env"
[[ -f "$ENV_FILE" ]] && { set -a; . "$ENV_FILE"; set +a; }

AGENT="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
command -v pi >/dev/null || { echo "Run ./install.sh first"; exit 1; }

pi list 2>/dev/null | grep -q '@pinet/slack-bridge' || pi install npm:@pinet/slack-bridge

uid="${SLACK_MEMBER_ID:-}"
[[ "$uid" =~ ^[UW][A-Z0-9]+$ ]] || { echo "Set SLACK_MEMBER_ID (U...) in .env; got: '$uid'"; exit 1; }

[[ "${SLACK_BOT_TOKEN:-}" == xoxb-?* ]] || { echo "Set SLACK_BOT_TOKEN (xoxb-...) in .env"; exit 1; }
[[ "${SLACK_APP_TOKEN:-}" == xapp-?* ]] || { echo "Set SLACK_APP_TOKEN (xapp-...) in .env"; exit 1; }

# Copy into settings.json (mode 600) so pi and Dock-launched pi-gui both see
# them without shell env. .env stays the source; re-run after changing it.
UID_="$uid" python3 - "$AGENT/settings.json" <<'PY'
import json, os, sys
path = sys.argv[1]
data = json.load(open(path)) if os.path.exists(path) else {}
data["slack-bridge"] = {
    **data.get("slack-bridge", {}),
    "botToken": os.environ["SLACK_BOT_TOKEN"],
    "appToken": os.environ["SLACK_APP_TOKEN"],
    "runtimeMode": "single",
    "allowedUsers": [os.environ["UID_"]],
}
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as f:
    json.dump(data, f, indent=2)
PY

cat <<'EOF'
Configured. Start pi; Pinet connects to Slack while that session runs:
  pi                      # then DM the bot. /pinet status to check.
Always-on: run it inside tmux, e.g.  tmux new -d -s pinet pi
EOF
