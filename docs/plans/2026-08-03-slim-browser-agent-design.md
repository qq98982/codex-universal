# Slim Browser Agent Image Design

Date: 2026-08-03
Status: Approved

## Scope

Update and publish only `gptbasesparticle/codex-universal:slim`. The legacy
`Dockerfile` and `latest` image remain unchanged.

The slim image remains a general AI-agent environment for NAS, storage, media,
subtitle, document, search, database, cloud, and browser work. Directly pinned
tools are updated to their current stable releases. Codex follows its newest
release because it does not have a stable release channel.

## Browser Use Integration

Install the stable Browser Use CLI without installing its bundled browser.
Reuse the Chromium already managed by Playwright.

Expose `browser-use` through a wrapper. For browser task execution, the wrapper:

1. Honors an existing `BU_CDP_URL` or `BU_CDP_WS` without starting a browser.
2. Otherwise starts Playwright Chromium headlessly on loopback port 9222.
3. Uses a persistent profile under the user's home directory.
4. Waits for the CDP endpoint to become ready.
5. Exports `BU_CDP_URL` and executes the real Browser Use CLI.

Management commands such as help, version, authentication, skill installation,
and telemetry must not start Chromium. Browser Use Cloud remains optional via
its normal credentials and explicit commands; local Chromium is the default.

`fetch-page` remains available for fast deterministic page extraction. Browser
Use is intended for multi-step interaction such as clicking, forms, login, and
pagination.

## Skill Refresh

Every slim container startup refreshes the official Browser Use skill for these
exact targets:

- Codex
- Claude Code
- Gemini CLI

The refresh uses the installed Browser Use package, disables package or browser
installation, and forces replacement of Browser Use's own skill. It must not
discover, remove, rewrite, or otherwise modify unrelated skills.

Refresh failure produces a warning and does not prevent the selected AI CLI or
shell from starting. This keeps the container usable when a mounted home is
temporarily read-only or has unexpected permissions.

## Image Layers

Order layers from stable to volatile:

1. Ubuntu packages for system, NAS, storage, media, subtitles, documents,
   encoding, search, and database work.
2. Stable Python helpers and Node.js.
3. Playwright and its browsers.
4. Released file and database binaries.
5. Browser Use, container clients, cloud clients, and Kubernetes clients.
6. Runtime configuration, wrappers, setup, entrypoint, and verification files.
7. Codex, Agy, Gemini CLI, and Claude Code in one late layer.

Changing an AI CLI version should preserve cache for the larger stable layers.

## Security And Runtime Boundaries

- Chromium CDP listens only on `127.0.0.1` by default.
- Browser state is stored below the mounted user home; PID and log files are
  ephemeral.
- No API key or token is embedded in the image or committed to the repository.
- Explicit external CDP endpoints and Browser Use Cloud credentials are passed
  through at runtime.
- Skill refresh operations target only Browser Use paths.

## Verification

Before publication:

- Run shell syntax, formatting, and repository tests.
- Test the browser wrapper with fake dependencies for lifecycle and argument
  behavior.
- Test skill refresh in a temporary home containing sentinel unrelated skills;
  their content and metadata must remain unchanged.
- Build the slim image and run its full verification script.
- Exercise Browser Use against the local Chromium CDP endpoint.
- Confirm current AI CLI, browser, media, subtitle, document, database, cloud,
  container, and Kubernetes client versions.
- Push the slim image tags to Docker Hub.
- Pull the published image on Synology and verify startup, mounted directories,
  AI CLI availability, skill refresh isolation, and local CDP operation.

