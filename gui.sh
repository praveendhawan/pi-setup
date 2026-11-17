#!/usr/bin/env bash
# Launch pi-gui with .env loaded. Apps opened from the Dock don't get shell
# env, so GLM/MiniMax keys (and Slack tokens) would be missing there.
set -euo pipefail
set -a; . "$(dirname "$0")/.env"; set +a
nohup /Applications/pi-gui.app/Contents/MacOS/pi-gui >/dev/null 2>&1 &
