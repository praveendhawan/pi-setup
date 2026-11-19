#!/usr/bin/env bash
# Install pi (CLI, official pinned installer) and pi-gui (desktop app).
set -euo pipefail

# pi needs Node >= 22.19
if ! node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>22||(a==22&&b>=19)?0:1)' 2>/dev/null; then
  command -v mise >/dev/null || { echo "Install Node >= 22.19 first"; exit 1; }
  mise install node && eval "$(mise env -s bash)"
fi

if ! command -v pi >/dev/null; then
  curl -fsSL https://pi.dev/install.sh | sh
fi
pi --version

# Grok via SuperGrok quota. Built-in `xai` provider hits api.x.ai (billed API
# credits -> 402); pi-grok routes through Grok CLI's subscription proxy.
# Unofficial: mimics Grok CLI client headers.
pi list | grep -q stnly/pi-grok || pi install git:github.com/stnly/pi-grok@v0.13.1

# Claude via subscription: official `claude -p` as backend (pi team's extension).
# Built-in `anthropic` OAuth gets billed as "extra usage". Needs `claude auth login`.
pi list | grep -q earendil-works/pi-claude-code || pi install https://github.com/earendil-works/pi-claude-code
# pi-gui launches with PATH=/usr/local/bin:/usr/bin:/bin..., so ~/.local/bin/claude
# is invisible there (provider shows "Login" that only errors). Link it in.
if [[ "$(uname)" == "Darwin" ]] && ! [[ -x /usr/local/bin/claude ]] && command -v claude >/dev/null; then
  sudo ln -sf "$(command -v claude)" /usr/local/bin/claude
fi

# Tool-call permissions: allow/ask/deny policy per tool, bash command and path
# (https://github.com/gotgenes/pi-packages). With no config every call asks, and
# with no UI (pi -p, Slack) an ask is denied, so seed our policy.
# Pinned: releases often. An existing config is kept; edit it in place.
pi list | grep -q '@gotgenes/pi-permission-system' || pi install npm:@gotgenes/pi-permission-system@42.2.0
AGENT="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
mkdir -p "$AGENT/extensions/pi-permission-system"
cp -n "$(dirname "$0")/permissions/pi-permission-system.json" "$AGENT/extensions/pi-permission-system/config.json" || true

# OS sandbox for bash (macOS sandbox-exec): writes only in the working folder,
# /tmp and tool caches; network only to allowlisted domains; secrets redacted
# from output. Shipped default allows writing anywhere in ~, so our sandbox.json
# (shipped default with allowWrite narrowed) replaces it. `pi --yolo` disables it.
pi list | grep -q 'auto-permission-system' || pi install npm:auto-permission-system@6.1.1
cp -n "$(dirname "$0")/permissions/sandbox.json" "$AGENT/extensions/sandbox.json" || true

if [[ "$(uname)" == "Darwin" ]] && ! brew list --cask pi-gui >/dev/null 2>&1; then
  brew install --cask minghinmatthewlam/tap/pi-gui
fi

cat <<'EOF'

Next:
  1. cp .env.sample .env       # fill GLM / MiniMax / BlazeInfer keys + Slack values
     ./keys.sh                 # .env -> Keychain, wired into auth.json
  2. claude auth login       # Claude Pro/Max -> "Claude Code Subscription" provider
     pi, then inside it:
       /login                 # "Use a subscription" -> xAI (SuperGrok Subscription)
  3. ./slack.sh                # Slack (Pinet extension)
pi-gui shares ~/.pi/agent with the CLI, so logins carry over.
EOF
