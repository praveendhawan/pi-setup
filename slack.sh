#!/usr/bin/env bash
# Slack for pi via Pinet (@pinet/slack-bridge, https://github.com/gugu91/pinet).
# A pi extension: the pi session itself connects to Slack over Socket Mode
# (outbound only, no public URL / tunnel needed) and uses pi's own logins.
#
# Before running: create the Slack app from Pinet's manifest
#   ~/.pi/agent/npm/node_modules/@pinet/slack-bridge/manifest.yaml
# then have ready: Bot token (xoxb-...), App-level token (xapp-..., connections:write),
# and your Slack member ID (profile -> ... -> Copy member ID).
# Re-run to change tokens or the allowed user.
set -euo pipefail

AGENT="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
command -v pi >/dev/null || { echo "Run ./install.sh first"; exit 1; }

pi list 2>/dev/null | grep -q '@pinet/slack-bridge' || pi install npm:@pinet/slack-bridge

read -rp "Your Slack member ID (U...): " uid
[[ "$uid" =~ ^[UW][A-Z0-9]+$ ]] || { echo "Not a Slack member ID: $uid"; exit 1; }
read -rsp "SLACK_BOT_TOKEN (xoxb-...): " bot; echo
read -rsp "SLACK_APP_TOKEN (xapp-...): " app; echo

# Tokens live in settings.json (same dir/trust level as auth.json), so pi and
# pi-gui both pick them up without shell env. File is locked to 600.
BOT="$bot" APP="$app" UID_="$uid" python3 - "$AGENT/settings.json" <<'PY'
import json, os, sys
path = sys.argv[1]
data = json.load(open(path)) if os.path.exists(path) else {}
data["slack-bridge"] = {
    **data.get("slack-bridge", {}),
    "botToken": os.environ["BOT"],
    "appToken": os.environ["APP"],
    "runtimeMode": "single",
    "allowedUsers": [os.environ["UID_"]],
}
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as f:
    json.dump(data, f, indent=2)
PY
chmod 600 "$AGENT/settings.json"

cat <<'EOF'
Configured. Start pi; Pinet connects to Slack while that session runs:
  pi                      # then DM the bot. /pinet status to check.
Always-on: run it inside tmux, e.g.  tmux new -d -s pinet pi
EOF
