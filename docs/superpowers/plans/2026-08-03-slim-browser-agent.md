# Slim Browser Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish and deploy an updated slim AI-agent image with current stable tools, on-demand local Chromium for Browser Use, and startup refresh of only Browser Use's official skills.

**Architecture:** Keep stable system and browser layers ahead of volatile AI CLI installs. A small shell wrapper starts the existing Playwright Chromium on loopback CDP only for browser tasks, while a separate startup helper refreshes exact Codex, Claude, and Gemini Browser Use skill targets without package installation.

**Tech Stack:** Docker BuildKit, Ubuntu 24.04, Bash, Node.js 24 LTS, Playwright, Python 3.12, uv, Browser Use CLI, Docker Hub, Synology Docker.

---

## File Map

- Create `browser-use-local`: owns local Chromium CDP startup and dispatch to the real Browser Use CLI.
- Create `refresh-browser-use-skills`: owns exact-target runtime skill refresh and no other setup behavior.
- Create `test_slim_browser_use.sh`: tests wrapper dispatch, local CDP startup, and skill isolation with fake executables and a temporary home.
- Modify `entrypoint_slim.sh`: invokes setup and the non-fatal skill refresh before the selected command or shell.
- Modify `Dockerfile.slim`: updates stable pins, installs Browser Use without a duplicate browser, orders stable layers before AI CLIs, and installs the new scripts.
- Modify `verify_slim.sh`: verifies Browser Use installation, local CDP reuse, and exact skill installation.
- Modify `README.md`: documents Browser Use, local/cloud behavior, skill refresh, and persistent home requirements.
- Modify Synology launcher files under `/volume3/homes/henry/ai-agent`: pull the published image and retain mounted home/data directories without storing secrets in this repository.

### Task 1: Browser Use Runtime Scripts

**Files:**
- Create: `test_slim_browser_use.sh`
- Create: `browser-use-local`
- Create: `refresh-browser-use-skills`

- [ ] **Step 1: Write failing wrapper tests**

Create tests that inject `BROWSER_USE_REAL_BIN` and `BROWSER_USE_CHROMIUM_BIN`. Assert that `--version`, `skill`, and `auth` dispatch without launching Chromium; explicit `BU_CDP_URL` dispatches unchanged; ordinary execution starts Chromium once, waits for `/json/version`, and passes `BU_CDP_URL=http://127.0.0.1:<test-port>` to the real CLI.

```bash
env BROWSER_USE_REAL_BIN="$fake_real" \
    BROWSER_USE_CHROMIUM_BIN="$fake_chromium" \
    BROWSER_USE_CDP_PORT="$port" \
    HOME="$test_home" \
    "$repo_dir/browser-use-local" --version

test ! -e "$chromium_calls"
grep -F 'BU_CDP_URL=http://127.0.0.1:' "$real_calls"
grep -F -- '--remote-debugging-address=127.0.0.1' "$chromium_calls"
```

- [ ] **Step 2: Run wrapper tests and verify RED**

Run: `bash test_slim_browser_use.sh`

Expected: FAIL because `browser-use-local` and `refresh-browser-use-skills` do not exist.

- [ ] **Step 3: Implement the local CDP wrapper**

Implement strict Bash behavior with these defaults and boundaries:

```bash
real_bin="${BROWSER_USE_REAL_BIN:-/opt/browser-use/bin/browser-use}"
chromium_bin="${BROWSER_USE_CHROMIUM_BIN:-chromium}"
cdp_host="127.0.0.1"
cdp_port="${BROWSER_USE_CDP_PORT:-9222}"
profile_dir="${BROWSER_USE_PROFILE_DIR:-${HOME}/.browser-use/chromium-profile}"
cdp_url="http://${cdp_host}:${cdp_port}"
```

Dispatch management commands directly. Honor `BU_CDP_URL` or `BU_CDP_WS`.
For browser execution, create the profile, reuse a healthy endpoint, otherwise
launch Chromium with `--headless=new`, `--no-sandbox`,
`--disable-dev-shm-usage`, loopback CDP, and the profile directory. Poll
`/json/version` for up to 15 seconds, fail with the Chromium log path if it does
not become ready, then execute the real CLI with `BU_CDP_URL` exported.

- [ ] **Step 4: Implement exact-target skill refresh**

Use only fixed targets and disable installation:

```bash
for target in codex claude gemini; do
  "$browser_use_bin" skill install \
    --target "$target" \
    --no-install \
    --force
done
```

Do not enumerate skill directories and do not delete any path. A failed target
sets a nonzero final status so the caller can warn without aborting startup.

- [ ] **Step 5: Complete isolation tests and verify GREEN**

The fake skill installer writes only its Browser Use target. Seed unrelated
sentinel files under `.codex/skills`, `.claude/skills`, and `.gemini/skills`,
record SHA-256 plus nanosecond mtime, run refresh, and assert all records are
identical afterward.

Run: `bash test_slim_browser_use.sh`

Expected: `browser-use runtime tests passed`.

- [ ] **Step 6: Commit runtime scripts and tests**

```bash
git add browser-use-local refresh-browser-use-skills test_slim_browser_use.sh
git commit -m "Add local Browser Use runtime"
```

### Task 2: Runtime Entrypoint Integration

**Files:**
- Modify: `test_entrypoints.sh`
- Modify: `entrypoint_slim.sh`

- [ ] **Step 1: Write failing entrypoint refresh tests**

Add a refresh stub and assert the slim entrypoint invokes it once before the
requested command. Add a failing refresh stub and assert the requested command
still runs while stderr includes a warning. Keep the legacy entrypoint test
unchanged.

```bash
env CODEX_SETUP_SCRIPT="$setup_stub" \
    BROWSER_USE_SKILL_REFRESH_SCRIPT="$refresh_stub" \
    bash "$repo_dir/entrypoint_slim.sh" -c 'exit 0'
test "$(wc -l < "$refresh_calls")" -eq 1
```

- [ ] **Step 2: Run entrypoint tests and verify RED**

Run: `bash test_entrypoints.sh`

Expected: FAIL because the slim entrypoint does not call the refresh script.

- [ ] **Step 3: Add non-fatal refresh to the slim entrypoint**

Immediately after setup, invoke
`${BROWSER_USE_SKILL_REFRESH_SCRIPT:-/opt/codex/refresh-browser-use-skills}`.
If it fails, print `warning: Browser Use skill refresh failed; continuing` to
stderr and continue to the command or interactive shell.

- [ ] **Step 4: Run entrypoint tests and verify GREEN**

Run: `bash test_entrypoints.sh`

Expected: `entrypoint lifecycle tests passed`.

- [ ] **Step 5: Commit entrypoint behavior**

```bash
git add entrypoint_slim.sh test_entrypoints.sh
git commit -m "Refresh Browser Use skills at startup"
```

### Task 3: Stable Versions And Docker Layering

**Files:**
- Modify: `Dockerfile.slim`

- [ ] **Step 1: Resolve current stable versions from official channels**

Use npm `latest`, PyPI release metadata, GitHub `releases/latest`, Node LTS,
Kubernetes `stable.txt`, and vendor apt candidate versions. Exclude prereleases
and record binary hashes from downloaded official assets.

```bash
npm view @anthropic-ai/claude-code version
npm view @google/gemini-cli version
curl -fsSL https://pypi.org/pypi/browser-use/json | jq -r .info.version
curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version'
curl -fsSL https://api.github.com/repos/openai/codex/releases/latest | jq -r .tag_name
curl -fsSL https://dl.k8s.io/release/stable.txt
```

Expected baseline on 2026-08-03 includes Node `v24.18.1` LTS, Browser Use
`0.13.7`, Codex `rust-v0.146.0`, Claude Code `2.1.220`, and Gemini CLI `0.53.1`.

- [ ] **Step 2: Update stable tool pins and checksums**

Update every direct version argument in `Dockerfile.slim` when the official
stable channel has advanced. Keep Ubuntu package wildcards tied to Ubuntu 24.04
and do not alter `Dockerfile`.

- [ ] **Step 3: Install Browser Use without another browser**

Install the pinned CLI to `/opt/browser-use` with uv, expose the real binary at
`/opt/browser-use/bin/browser-use`, and install `browser-use-local` as
`/usr/local/bin/browser-use`. Do not execute `browser-use install`.

```dockerfile
ARG BROWSER_USE_VERSION=0.13.7
RUN uv tool install --tool-dir /opt/browser-use-tools \
      --bin-dir /opt/browser-use/bin \
      "browser-use==${BROWSER_USE_VERSION}" \
    && /opt/browser-use/bin/browser-use --version
```

- [ ] **Step 4: Reorder stable clients ahead of volatile AI CLIs**

Move the container/cloud client layer before the AI CLI layer. Copy runtime and
verification scripts before the AI CLI install. Keep Codex, Agy, Gemini, and
Claude in one late `RUN` layer so changes to those versions preserve browser,
media, database, and cloud caches.

- [ ] **Step 5: Validate Dockerfile structure**

Run:

```bash
git diff --check
docker buildx build --check -f Dockerfile.slim .
```

Expected: no whitespace or Dockerfile validation errors.

- [ ] **Step 6: Commit version and layer changes**

```bash
git add Dockerfile.slim browser-use-local refresh-browser-use-skills
git commit -m "Install Browser Use in slim image"
```

### Task 4: Image Verification And Documentation

**Files:**
- Modify: `verify_slim.sh`
- Modify: `README.md`

- [ ] **Step 1: Extend image verification**

Verify `browser-use --version` without launching Chromium, install all three
skills under a temporary HOME, preserve unrelated sentinel files, and run a
Browser Use local-CDP smoke task. Continue to verify all existing browser,
media, subtitle, document, database, cloud, and AI commands.

- [ ] **Step 2: Document runtime behavior**

Add `browser-use` to the browser tool list. Document the on-demand local CDP
default, `BU_CDP_URL`/`BU_CDP_WS` overrides, optional `BROWSER_USE_API_KEY`,
startup skill refresh, and the requirement to mount `/root` persistently for
sessions, credentials, skills, and browser profile continuity.

- [ ] **Step 3: Run repository verification**

```bash
bash -n entrypoint_slim.sh browser-use-local refresh-browser-use-skills \
  test_entrypoints.sh test_slim_browser_use.sh verify_slim.sh
shellcheck entrypoint_slim.sh browser-use-local refresh-browser-use-skills \
  test_entrypoints.sh test_slim_browser_use.sh verify_slim.sh
bash test_slim_browser_use.sh
bash test_entrypoints.sh
git diff --check
```

Expected: all commands exit zero and both test scripts print their pass lines.

- [ ] **Step 4: Commit verification and documentation**

```bash
git add verify_slim.sh README.md
git commit -m "Document and verify Browser Use tooling"
```

### Task 5: Build And Publish Slim Image

**Files:**
- No source changes expected.

- [ ] **Step 1: Build the amd64 image with full verification**

```bash
docker buildx build --load --platform linux/amd64 \
  -f Dockerfile.slim \
  -t docker.io/gptbasesparticle/codex-universal:slim .
```

Expected: Docker build exits zero and `/opt/verify_slim.sh` reports
`Slim toolbox detected successfully.`

- [ ] **Step 2: Run fresh runtime smoke tests**

Run the image with a temporary persistent home and verify CLI versions, startup
skill refresh, unrelated skill preservation, and a local Browser Use CDP task.
Inspect the resulting image architecture and size.

- [ ] **Step 3: Push source commits**

```bash
git push origin main
```

Expected: `main` advances to the verified implementation commit.

- [ ] **Step 4: Push the slim image**

```bash
docker push docker.io/gptbasesparticle/codex-universal:slim
```

Expected: Docker Hub returns the pushed manifest digest.

### Task 6: Synology Deployment Verification

**Files:**
- Modify only as needed: `/volume3/homes/henry/ai-agent/agent-docker.sh`
- Preserve: `/volume3/homes/henry/ai-agent/secrets.env`

- [ ] **Step 1: Inspect the existing launcher over SSH**

```bash
ssh -p 22022 henry@zhy4001.synology.me \
  'ls -la /volume3/homes/henry/ai-agent && sed -n "1,260p" /volume3/homes/henry/ai-agent/agent-docker.sh'
```

Do not print `secrets.env` or agent authentication files.

- [ ] **Step 2: Preserve mounts and update only image/runtime behavior**

Ensure the launcher pulls `gptbasesparticle/codex-universal:slim`, mounts its
persistent agent home to `/root`, retains configured data directories, and lets
the user select Codex, Claude Code, Gemini, Agy, or a shell. Preserve no-approval
aliases and existing secret-file loading.

- [ ] **Step 3: Pull and verify the published image on Synology**

Use the launcher or Synology Docker CLI to pull the new digest. Verify all four
AI CLIs, Browser Use version, exact startup skill refresh, preservation of an
unrelated sentinel skill, mounted data visibility, and local loopback CDP.

- [ ] **Step 4: Audit completion evidence**

Compare the running Synology image digest with the Docker Hub push digest,
inspect `git status --short`, inspect the pushed Git commit, and map every design
requirement to a source file or runtime check before marking the goal complete.

