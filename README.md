# codex-universal

`codex-universal` is a customized Docker image for Codex-style agent environments.

Two image variants are published:

```sh
docker pull docker.io/gptbasesparticle/codex-universal:latest
docker pull docker.io/gptbasesparticle/codex-universal:slim
```

- `latest`: legacy full development image with one stable version per language/runtime.
- `slim`: maintained AI agent toolbox for shell work, headless browser automation, NAS/Synology files, disks, media files, documents, subtitles, encoding conversion, and search. It does not include full language SDKs such as Rust, Swift, PHP, Ruby, Go, Java, or Elixir.

This repository can build both `linux/amd64` and `linux/arm64`, but the published/tested image is `linux/amd64`.

## Full Image

The full image is kept for legacy use. New AI agent tooling updates target the slim image.

Run the full development image:

```sh
docker run --rm -it \
    -e CODEX_ENV_PYTHON_VERSION=3.14.5 \
    -e CODEX_ENV_NODE_VERSION=26.3.0 \
    -e CODEX_ENV_RUST_VERSION=1.96.0 \
    -e CODEX_ENV_GO_VERSION=1.26.4 \
    -e CODEX_ENV_SWIFT_VERSION=6.3.2 \
    -e CODEX_ENV_RUBY_VERSION=4.0.5 \
    -e CODEX_ENV_PHP_VERSION=8.5.7 \
    -e CODEX_ENV_JAVA_VERSION=25 \
    -v "$(pwd):/workspace/$(basename "$(pwd)")" \
    -w "/workspace/$(basename "$(pwd)")" \
    docker.io/gptbasesparticle/codex-universal:latest
```

Supported full-image runtimes:

| Environment variable | Version | Additional packages |
| --- | --- | --- |
| `CODEX_ENV_PYTHON_VERSION` | `3.14.5` | `pyenv`, `poetry`, `uv`, `ruff`, `black`, `mypy`, `pyright`, `isort`, `pytest` |
| `CODEX_ENV_NODE_VERSION` | `26.3.0` | `npm`, `corepack`, `pnpm`, `yarn`, `prettier`, `eslint`, `typescript` |
| `CODEX_ENV_RUST_VERSION` | `1.96.0` | `rustfmt`, `clippy` |
| `CODEX_ENV_GO_VERSION` | `1.26.4` | `golangci-lint` |
| `CODEX_ENV_SWIFT_VERSION` | `6.3.2` | |
| `CODEX_ENV_RUBY_VERSION` | `4.0.5` | |
| `CODEX_ENV_PHP_VERSION` | `8.5.7` | `composer` |
| `CODEX_ENV_JAVA_VERSION` | `25` | `gradle`, `maven` |

## Slim Image

Run the slim AI agent toolbox against a mounted NAS/media/document directory:

```sh
docker run --rm -it \
    -v "/path/to/files:/data" \
    -w /data \
    docker.io/gptbasesparticle/codex-universal:slim
```

For real disk inspection commands such as `smartctl`, `hdparm`, `parted`, `sgdisk`, or `testdisk`, run with explicit device access:

```sh
docker run --rm -it --privileged \
    -v "/dev:/dev" \
    -v "/path/to/files:/data" \
    -w /data \
    docker.io/gptbasesparticle/codex-universal:slim
```

The slim image includes the AI CLIs plus tools for:

- AI agents: `codex`, `claude`, `gemini`, `agy`
- Container and cloud clients: `docker`, `docker compose`, `aws`, `az`, `gcloud`, `kubectl`, and `helm`
- Headless browsers and scraping: `playwright`, `fetch-page`, `chromium`, `firefox`, and `webkit`
- Search and inspection: `rg`, `rga`, `fd`, `fzf`, `plocate`, `tree`, `file`, `bat`, `delta`
- NAS and sync: `rclone`, `rsync`, `smbclient`, `cifs-utils`, `nfs-common`
- Disk and duplicate cleanup: `smartctl`, `hdparm`, `parted`, `sgdisk`, `testdisk`, `ncdu`, `duf`, `czkawka_cli`, `jdupes`, `fdupes`, `rdfind`, `rmlint`, `duperemove`
- Media: `ffmpeg`, `ffprobe`, `mediainfo`, `mkvtoolnix`, `exiftool`, `imagemagick`, `webp`, `avifenc`, `heif-convert`
- Music: `flac`, `metaflac`, `id3v2`, `eyeD3`, `kid3-cli`, `mp3val`, `AtomicParsley`, `sox`
- Subtitles: `ffsubsync`, `subliminal`, `srt-*`, `mkvextract`, `mkvmerge`
- Documents and OCR: `pandoc`, `pdftotext`, `pdfinfo`, `ocrmypdf`, `tesseract` with English, Simplified Chinese, Traditional Chinese, and Japanese language data
- Encoding conversion: `iconv`, `uchardet`, `enca`, `nkf`, `dos2unix`, `convmv`, `detox`, `recode`

LibreOffice is intentionally not installed in `slim`.

Use host Docker and local cloud credentials by mounting the relevant client state.
The image includes Docker clients, not a Docker daemon; mount a usable host socket
or set `DOCKER_HOST` for a remote/rootless Docker endpoint.

```sh
docker run --rm -it \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$HOME/.docker:/root/.docker:ro" \
    -v "$HOME/.aws:/root/.aws:ro" \
    -v "$HOME/.azure:/root/.azure" \
    -v "$HOME/.config/gcloud:/root/.config/gcloud" \
    -v "$HOME/.kube:/root/.kube:ro" \
    docker.io/gptbasesparticle/codex-universal:slim
```

Fetch rendered page content from sites that need a browser-like environment:

```sh
fetch-page "https://metalstorm.net/bands/albums_top.php?album_style=Progressive"
fetch-page --selector 'xpath=//span[contains(@class,"megatitle")]/following-sibling::div[contains(@class,"cbox")][1]//table' \
    "https://metalstorm.net/bands/albums_top.php?album_style=Progressive"
```

## AI CLI Headless Commands

These commands run non-GUI agent CLIs and bypass approval prompts. Use them only inside a container or another sandbox you trust:

```sh
codex exec --dangerously-bypass-approvals-and-sandbox "inspect this directory and summarize it"
claude -p --dangerously-skip-permissions "inspect this directory and summarize it"
gemini -p "inspect this directory and summarize it" -y
agy --print "inspect this directory and summarize it" --dangerously-skip-permissions
```

## Build

```sh
docker build --platform linux/amd64 -t docker.io/gptbasesparticle/codex-universal:latest .
docker build --platform linux/amd64 -f Dockerfile.slim -t docker.io/gptbasesparticle/codex-universal:slim .
```

See [Dockerfile](Dockerfile) and [Dockerfile.slim](Dockerfile.slim) for exact package versions.
