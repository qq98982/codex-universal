#!/bin/bash

echo "============================================"
echo "Welcome to gptbasesparticle/codex-universal:slim"
echo "============================================"

setup_script="${CODEX_SETUP_SCRIPT:-/opt/codex/setup_slim.sh}"
"$setup_script"

refresh_script="${BROWSER_USE_SKILL_REFRESH_SCRIPT:-/opt/codex/refresh-browser-use-skills}"
if ! "$refresh_script"; then
  echo "warning: Browser Use skill refresh failed; continuing" >&2
fi

if [[ $# -gt 0 ]]; then
  echo "Environment ready. Running command."
  exec bash --login "$@"
fi

echo "Environment ready. Dropping you into a bash shell."
trap 'exit 0' HUP INT TERM
bash --login
exit 0
