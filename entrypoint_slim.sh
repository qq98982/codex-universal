#!/bin/bash

echo "============================================"
echo "Welcome to gptbasesparticle/codex-universal:slim"
echo "============================================"

/opt/codex/setup_slim.sh

echo "Environment ready. Dropping you into a bash shell."
exec bash --login "$@"
