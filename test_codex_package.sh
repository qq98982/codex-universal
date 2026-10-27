#!/usr/bin/env bash
set -euo pipefail

codex_test_home="$(mktemp -d /var/tmp/codex-package-test.XXXXXXXX)"

cleanup() {
  if timeout 15 env CODEX_HOME="$codex_test_home" codex app-server daemon stop >/dev/null 2>&1; then
    rm -rf "$codex_test_home"
  else
    echo "Codex test daemon cleanup failed; state retained at $codex_test_home" >&2
    return 1
  fi
}
trap cleanup EXIT
codex_test_version="$(codex --version | awk '{print $2}')"

# Keep the smoke test offline and independent of user config and daemon state.
mkdir -p "$codex_test_home/app-server-daemon"
cat > "$codex_test_home/app-server-daemon/settings.json" <<'JSON'
{"updater":{"autoUpdateEnabled":false},"shutdownGraceSeconds":5}
JSON

timeout 30 env CODEX_HOME="$codex_test_home" codex app-server daemon start |
  jq -e --arg version "$codex_test_version" \
    '.status == "started" and .cliVersion == $version and .appServerVersion == $version'
timeout 15 env CODEX_HOME="$codex_test_home" codex app-server daemon version |
  jq -e --arg version "$codex_test_version" \
    '.status == "running" and .managedCodexVersion == $version and .cliVersion == $version and .appServerVersion == $version'
timeout 15 env CODEX_HOME="$codex_test_home" codex app-server daemon stop |
  jq -e '.status == "stopped"'

trap - EXIT
rm -rf "$codex_test_home"
echo "Codex packaged daemon lifecycle passed"
