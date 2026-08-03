#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test_root="$(mktemp -d)"
test_home="$test_root/home"
bin_dir="$test_root/bin"
real_calls="$test_root/real.calls"
chromium_calls="$test_root/chromium.calls"
chromium_pid="$test_root/chromium.pid"

cleanup() {
  if [[ -s "$chromium_pid" ]]; then
    kill "$(cat "$chromium_pid")" 2>/dev/null || true
  fi
  rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$test_home" "$bin_dir"
: >"$real_calls"
: >"$chromium_calls"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_empty() {
  [[ ! -s "$1" ]] || fail "expected $1 to be empty"
}

assert_contains() {
  grep -F -- "$2" "$1" >/dev/null || fail "expected $1 to contain: $2"
}

cat >"$bin_dir/browser-use-real" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'BU_CDP_URL=%s BU_CDP_WS=%s ARGS=%s\n' \
  "${BU_CDP_URL:-}" "${BU_CDP_WS:-}" "$*" >>"$FAKE_REAL_CALLS"

if [[ "${1:-}" == "skill" && "${2:-}" == "install" ]]; then
  target=""
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--target" ]]; then
      target="$2"
      shift 2
      continue
    fi
    shift
  done

  case "$target" in
    codex) skill_dir="$HOME/.codex/skills/browser-use" ;;
    claude) skill_dir="$HOME/.claude/skills/browser-use" ;;
    gemini) skill_dir="$HOME/.gemini/skills/browser-use" ;;
    *) exit 64 ;;
  esac
  mkdir -p "$skill_dir"
  printf 'official browser-use skill for %s\n' "$target" >"$skill_dir/SKILL.md"
fi
EOF

cat >"$bin_dir/chromium" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

port=""
printf '%s\n' "$*" >>"$FAKE_CHROMIUM_CALLS"
printf '%s\n' "$$" >"$FAKE_CHROMIUM_PID"

for arg in "$@"; do
  case "$arg" in
    --remote-debugging-port=*) port="${arg#*=}" ;;
  esac
done

[[ -n "$port" ]]
exec python3 - "$port" <<'PY'
import http.server
import json
import sys


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({"Browser": "fake-chromium"}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass


http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
PY
EOF

chmod +x "$bin_dir/browser-use-real" "$bin_dir/chromium"

port="$(python3 - <<'PY'
import socket

with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"

run_wrapper() {
  env \
    BROWSER_USE_REAL_BIN="$bin_dir/browser-use-real" \
    BROWSER_USE_CHROMIUM_BIN="$bin_dir/chromium" \
    BROWSER_USE_CDP_PORT="$port" \
    BROWSER_USE_RUNTIME_DIR="$test_root/run" \
    BROWSER_USE_PROFILE_DIR="$test_home/.browser-use/chromium-profile" \
    FAKE_REAL_CALLS="$real_calls" \
    FAKE_CHROMIUM_CALLS="$chromium_calls" \
    FAKE_CHROMIUM_PID="$chromium_pid" \
    HOME="$test_home" \
    "$repo_dir/browser-use-local" "$@"
}

for command in "--help" "--version" "auth status" "skill install --target codex" "telemetry status"; do
  : >"$chromium_calls"
  read -r -a args <<<"$command"
  run_wrapper "${args[@]}"
  assert_empty "$chromium_calls"
done

: >"$chromium_calls"
BU_CDP_URL="http://browser.example:9333" run_wrapper run "external browser task"
assert_empty "$chromium_calls"
assert_contains "$real_calls" "BU_CDP_URL=http://browser.example:9333"

: >"$chromium_calls"
run_wrapper run "local browser task"
run_wrapper run "second local browser task"
[[ "$(wc -l <"$chromium_calls")" -eq 1 ]] || fail "expected Chromium to start once"
assert_contains "$chromium_calls" "--remote-debugging-address=127.0.0.1"
assert_contains "$chromium_calls" "--remote-debugging-port=$port"
assert_contains "$chromium_calls" "--user-data-dir=$test_home/.browser-use/chromium-profile"
assert_contains "$real_calls" "BU_CDP_URL=http://127.0.0.1:$port"

for agent in codex claude gemini; do
  mkdir -p "$test_home/.$agent/skills/unrelated" "$test_home/.$agent/skills/browser-use"
  printf 'keep-%s\n' "$agent" >"$test_home/.$agent/skills/unrelated/SKILL.md"
  printf 'locally modified browser-use skill\n' >"$test_home/.$agent/skills/browser-use/SKILL.md"
done

snapshot_file="$test_root/sentinel.before"
for agent in codex claude gemini; do
  sentinel="$test_home/.$agent/skills/unrelated/SKILL.md"
  printf '%s %s %s\n' \
    "$agent" "$(sha256sum "$sentinel" | cut -d' ' -f1)" "$(stat -c '%y' "$sentinel")" \
    >>"$snapshot_file"
done

: >"$real_calls"
env \
  BROWSER_USE_BIN="$bin_dir/browser-use-real" \
  FAKE_REAL_CALLS="$real_calls" \
  HOME="$test_home" \
  "$repo_dir/refresh-browser-use-skills"

for agent in codex claude gemini; do
  sentinel="$test_home/.$agent/skills/unrelated/SKILL.md"
  actual="$(printf '%s %s %s\n' \
    "$agent" "$(sha256sum "$sentinel" | cut -d' ' -f1)" "$(stat -c '%y' "$sentinel")")"
  expected="$(grep -F "$agent " "$snapshot_file")"
  [[ "$actual" == "$expected" ]] || fail "$agent unrelated skill changed"
  assert_contains "$test_home/.$agent/skills/browser-use/SKILL.md" "official browser-use skill for $agent"
  assert_contains "$real_calls" "ARGS=skill install --target $agent --no-install --force"
done

[[ "$(wc -l <"$real_calls")" -eq 3 ]] || fail "expected exactly three skill installs"

echo "browser-use runtime tests passed"
