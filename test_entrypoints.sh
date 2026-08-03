#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
setup_stub="$(mktemp)"
refresh_stub="$(mktemp)"
refresh_calls="$(mktemp)"
output_file="$(mktemp)"

cleanup() {
  rm -f "$setup_stub" "$refresh_stub" "$refresh_calls" "$output_file"
}
trap cleanup EXIT

cat > "$setup_stub" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$setup_stub"

cat > "$refresh_stub" <<'STUB'
#!/usr/bin/env bash
printf 'refresh\n' >>"${REFRESH_CALLS:?}"
exit "${REFRESH_STATUS:-0}"
STUB
chmod +x "$refresh_stub"

expect_status() {
  local expected="$1"
  shift

  set +e
  "$@" >"$output_file" 2>&1
  local status=$?
  set -e

  if [[ "$status" -ne "$expected" ]]; then
    echo "Expected status $expected, got $status for: $*" >&2
    cat "$output_file" >&2
    return 1
  fi
}

expect_piped_status() {
  local expected="$1"
  local input="$2"
  shift 2

  set +e
  printf '%s' "$input" | "$@" >"$output_file" 2>&1
  local status=$?
  set -e

  if [[ "$status" -ne "$expected" ]]; then
    echo "Expected status $expected, got $status for piped command: $*" >&2
    cat "$output_file" >&2
    return 1
  fi
}

for entrypoint in "$repo_dir/entrypoint.sh" "$repo_dir/entrypoint_slim.sh"; do
  expect_piped_status 0 $'false\nexit\n' env CODEX_SETUP_SCRIPT="$setup_stub" bash "$entrypoint"
  expect_status 7 env CODEX_SETUP_SCRIPT="$setup_stub" bash "$entrypoint" -c 'exit 7'
done

: >"$refresh_calls"
expect_status 0 env \
  CODEX_SETUP_SCRIPT="$setup_stub" \
  BROWSER_USE_SKILL_REFRESH_SCRIPT="$refresh_stub" \
  REFRESH_CALLS="$refresh_calls" \
  bash "$repo_dir/entrypoint_slim.sh" -c 'exit 0'
[[ "$(wc -l <"$refresh_calls")" -eq 1 ]]

: >"$refresh_calls"
expect_status 0 env \
  CODEX_SETUP_SCRIPT="$setup_stub" \
  BROWSER_USE_SKILL_REFRESH_SCRIPT="$refresh_stub" \
  REFRESH_CALLS="$refresh_calls" \
  REFRESH_STATUS=1 \
  bash "$repo_dir/entrypoint_slim.sh" -c 'printf command-still-ran'
grep -F 'warning: Browser Use skill refresh failed; continuing' "$output_file" >/dev/null
grep -F 'command-still-ran' "$output_file" >/dev/null

echo "entrypoint lifecycle tests passed"
