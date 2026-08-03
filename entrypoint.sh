#!/bin/bash

echo "=================================="
echo "Welcome to openai/codex-universal!"
echo "=================================="

setup_script="${CODEX_SETUP_SCRIPT:-/opt/codex/setup_universal.sh}"
"$setup_script"

if [[ $# -gt 0 ]]; then
  echo "Environment ready. Running command."
  exec bash --login "$@"
fi

echo "Environment ready. Dropping you into a bash shell."
trap 'exit 0' HUP INT TERM
bash --login
exit 0
