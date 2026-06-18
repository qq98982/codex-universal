# syntax=docker/dockerfile:1.7
FROM ubuntu:24.04

ARG TARGETOS
ARG TARGETARCH

ENV LANG="C.UTF-8"
ENV HOME=/root
ENV DEBIAN_FRONTEND=noninteractive

### BASE ###

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        binutils=2.42-* \
        sudo=1.9.* \
        build-essential=12.10* \
        bzr=2.7.* \
        curl=8.5.* \
        default-libmysqlclient-dev=1.1.* \
        dnsutils=1:9.18.* \
        fd-find=9.0.* \
        gettext=0.21-* \
        git=1:2.43.* \
        git-lfs=3.4.* \
        gnupg=2.4.* \
        inotify-tools=3.22.* \
        iputils-ping=3:20240117-* \
        jq=1.7.* \
        libbz2-dev=1.0.* \
        libc6=2.39-* \
        libc6-dev=2.39-* \
        libcurl4-openssl-dev=8.5.* \
        libdb-dev=1:5.3.* \
        libedit2=3.1-* \
        libffi-dev=3.4.* \
        libgcc-13-dev=13.3.* \
        libgdbm-compat-dev=1.23-* \
        libgdbm-dev=1.23-* \
        libgdiplus=6.1+dfsg-* \
        libgssapi-krb5-2=1.20.* \
        liblzma-dev=5.6.* \
        libncurses-dev=6.4+20240113-* \
        libnss3-dev=2:3.98-* \
        libpq-dev=16.* \
        libpsl-dev=0.21.* \
        libpython3-dev=3.12.* \
        libreadline-dev=8.2-* \
        libsqlite3-dev=3.45.* \
        libssl-dev=3.0.* \
        libstdc++-13-dev=13.3.* \
        libunwind8=1.6.* \
        libuuid1=2.39.* \
        libxml2-dev=2.9.* \
        libz3-dev=4.8.* \
        make=4.3-* \
        moreutils=0.69-* \
        netcat-openbsd=1.226-* \
        openssh-client=1:9.6p1-* \
        pkg-config=1.8.* \
        protobuf-compiler=3.21.* \
        ripgrep=14.1.* \
        rsync=3.2.* \
        software-properties-common=0.99.* \
        sqlite3=3.45.* \
        swig3.0=3.0.* \
        tk-dev=8.6.* \
        tzdata=2026a-* \
        universal-ctags=5.9.* \
        unixodbc-dev=2.3.* \
        unzip=6.0-* \
        uuid-dev=2.39.* \
        wget=1.21.* \
        xz-utils=5.6.* \
        zip=3.0-* \
        zlib1g=1:1.3.* \
        zlib1g-dev=1:1.3.* \
        fd-find=9.0.* \
        universal-ctags=5.9.* \
    && rm -rf /var/lib/apt/lists/*

### MISE ###

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    install -dm 0755 /etc/apt/keyrings \
    && curl -fsSL https://mise.jdx.dev/gpg-key.pub | gpg --batch --yes --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg \
    && chmod 0644 /etc/apt/keyrings/mise-archive-keyring.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg] https://mise.jdx.dev/deb stable main" > /etc/apt/sources.list.d/mise.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends mise/stable \
    && rm -rf /var/lib/apt/lists/* \
    && echo 'eval "$(mise activate bash)"' >> /etc/profile \
    && mise settings set experimental true \
    && mise settings set override_tool_versions_filenames none \
    && mise settings add idiomatic_version_file_enable_tools "[]" \
    && mise settings add disable_backends asdf \
    && mise settings add disable_backends vfox

ENV PATH=$HOME/.local/share/mise/shims:$PATH

### LLVM ###

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        cmake=3.28.* \
        ccache=4.9.* \
        ninja-build=1.11.* \
        nasm=2.16.* \
        yasm=1.3.* \
        gawk=1:5.2.* \
        lsb-release=12.0-* \
    && rm -rf /var/lib/apt/lists/* \
    && bash -c "$(curl -fsSL https://apt.llvm.org/llvm.sh)"

### PYTHON ###

ARG PYTHON_VERSIONS="3.14.5"

# Install pyenv
ENV PYENV_ROOT=/root/.pyenv
ENV PATH=$PYENV_ROOT/bin:$PATH
RUN git -c advice.detachedHead=0 clone --depth 1 https://github.com/pyenv/pyenv.git "$PYENV_ROOT" \
    && echo 'export PYENV_ROOT="$HOME/.pyenv"' >> /etc/profile \
    && echo 'export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"' >> /etc/profile \
    && echo 'eval "$(pyenv init - bash)"' >> /etc/profile \
    && cd "$PYENV_ROOT" \
    && src/configure \
    && make -C src \
    && pyenv install $PYTHON_VERSIONS \
    && rm -rf "$PYENV_ROOT/cache"

# Install pipx for common global package managers (e.g. poetry)
ENV PIPX_BIN_DIR=/root/.local/bin
ENV PATH=$PIPX_BIN_DIR:$PATH
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/pipx \
    apt-get update \
    && apt-get install -y --no-install-recommends pipx=1.4.* \
    && rm -rf /var/lib/apt/lists/* \
    && pipx install --pip-args="--no-cache-dir --no-compile --root-user-action=ignore" poetry==2.1.* uv==0.7.* \
    && for pyv in "${PYENV_ROOT}/versions/"*; do \
         "$pyv/bin/python" -m pip install --no-cache-dir --no-compile --root-user-action=ignore --upgrade pip && \
         "$pyv/bin/pip" install --no-cache-dir --no-compile --root-user-action=ignore ruff black mypy pyright isort pytest; \
       done

# Reduce the verbosity of uv - impacts performance of stdout buffering
ENV UV_NO_PROGRESS=1

### NODE ###

ARG NVM_VERSION=v0.40.5
ARG NODE_VERSION=26.3.0
ARG NPM_VERSION=11.16.0
ARG COREPACK_VERSION=0.35.0
ARG PNPM_VERSION=11.5.2
ARG YARN_VERSION=1.22.22

ENV NVM_DIR=/root/.nvm
# Corepack tries to do too much - disable some of its features:
# https://github.com/nodejs/corepack/blob/main/README.md
ENV COREPACK_DEFAULT_TO_LATEST=0
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
ENV COREPACK_ENABLE_AUTO_PIN=0
ENV COREPACK_ENABLE_STRICT=0

RUN --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/root/.cache/yarn \
    --mount=type=cache,target=/root/.local/share/pnpm/store \
    git -c advice.detachedHead=0 clone --branch "$NVM_VERSION" --depth 1 https://github.com/nvm-sh/nvm.git "$NVM_DIR" \
    && echo 'source $NVM_DIR/nvm.sh' >> /etc/profile \
    && echo "prettier\neslint\ntypescript" > $NVM_DIR/default-packages \
    && . $NVM_DIR/nvm.sh \
    && nvm install "$NODE_VERSION" \
    && nvm use "$NODE_VERSION" \
    && npm install -g "npm@${NPM_VERSION}" \
    && npm install -g "corepack@${COREPACK_VERSION}" \
    && corepack enable \
    && corepack prepare "pnpm@${PNPM_VERSION}" --activate \
    && corepack prepare "yarn@${YARN_VERSION}" --activate \
    && nvm alias default "$NODE_VERSION" \
    && nvm cache clear \
    && npm cache clean --force || true \
    && pnpm store prune || true \
    && yarn cache clean || true

### BUN ###

ARG BUN_VERSION=1.3.14
RUN --mount=type=cache,target=/root/.cache/mise \
    mise use --global "bun@${BUN_VERSION}" \
    && mise cache clear || true

### JAVA ###

ARG JAVA_VERSION=25
ARG GRADLE_VERSION=9.5.1
ARG MAVEN_VERSION=3.9.16

RUN --mount=type=cache,target=/root/.cache/mise \
    mise install "java@${JAVA_VERSION}" \
    && mise use --global "java@${JAVA_VERSION}" \
    && mise use --global "gradle@${GRADLE_VERSION}" \
    && mise use --global "maven@${MAVEN_VERSION}" \
    && mise cache clear || true

### SWIFT ###

ARG SWIFT_VERSIONS="6.3.2"
ENV SWIFTLY_BIN_DIR=/root/.swiftly/bin
ENV PATH=$SWIFTLY_BIN_DIR:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg2=2.4.* \
    && curl -O https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz \
    && tar zxf swiftly-$(uname -m).tar.gz \
    && ./swiftly init --quiet-shell-followup \
    && swiftly install "${SWIFT_VERSIONS%% *}" \
    && swiftly use "${SWIFT_VERSIONS%% *}"

### RUST ###

ARG RUST_VERSIONS="1.96.0"
RUN --mount=type=cache,target=/root/.cargo/registry \
    --mount=type=cache,target=/root/.cargo/git \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain none \
    && . "$HOME/.cargo/env" \
    && echo 'source $HOME/.cargo/env' >> /etc/profile \
    && rustup toolchain install $RUST_VERSIONS --profile minimal --component rustfmt --component clippy \
    && rustup default ${RUST_VERSIONS%% *}

### RUBY ###

ARG RUBY_VERSIONS="4.0.5"
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/root/.cache/mise \
    apt-get update && apt-get install -y --no-install-recommends \
    libyaml-dev=0.2.* \
    libgmp-dev=2:6.3.* \
    && rm -rf /var/lib/apt/lists/* \
    && for v in $RUBY_VERSIONS; do mise install "ruby@${v}"; done \
    && mise use --global "ruby@${RUBY_VERSIONS%% *}" \
    && mise cache clear || true;

### C++ ###
# gcc is already installed via apt-get above, so these are just additional linters, etc.
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/pipx \
    pipx install --pip-args="--no-cache-dir --no-compile --root-user-action=ignore" cpplint==2.0.* clang-tidy==20.1.* clang-format==20.1.* cmakelang==0.6.*

### BAZEL ###

ARG BAZELISK_VERSION=v1.29.0

RUN curl -L --fail https://github.com/bazelbuild/bazelisk/releases/download/${BAZELISK_VERSION}/bazelisk-${TARGETOS}-${TARGETARCH} -o /usr/local/bin/bazelisk \
    && chmod +x /usr/local/bin/bazelisk \
    && ln -s /usr/local/bin/bazelisk /usr/local/bin/bazel

### GO ###

ARG GO_VERSIONS="1.26.4"
ARG GOLANG_CI_LINT_VERSION=2.12.2

# Go defaults GOROOT to /usr/local/go - we just need to update PATH
ENV PATH=/usr/local/go/bin:$HOME/go/bin:$PATH
RUN --mount=type=cache,target=/root/.cache/mise \
    for v in $GO_VERSIONS; do mise install "go@${v}"; done \
    && mise use --global "go@${GO_VERSIONS%% *}" \
    && mise use --global "golangci-lint@${GOLANG_CI_LINT_VERSION}" \
    && mise cache clear || true

### PHP ###

ARG PHP_VERSIONS="8.5.7"
ENV PHPENV_ROOT=/root/.phpenv
ENV PATH=/root/.phpenv/bin:/root/.phpenv/shims:$PATH

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential pkg-config ccache \
        autoconf=2.71-* bison=2:3.8.* re2c=3.1-* \
        libgd-dev=2.3.* libedit-dev=3.1-* libicu-dev=74.2-* libjpeg-dev=8c-* \
        libonig-dev=6.9.* libpng-dev=1.6.* libzip-dev=1.7.* \
        libssl-dev zlib1g-dev libcurl4-openssl-dev libreadline-dev libtidy-dev libxslt1-dev \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/phpenv/phpenv.git /root/.phpenv \
    && git clone https://github.com/php-build/php-build.git /root/.phpenv/plugins/php-build \
    && echo 'eval "$(phpenv init - bash)"' >> /etc/profile \
    && bash -lc '\
        eval "$(phpenv init -)" && \
        phpenv install -s "${PHP_VERSIONS%% *}" && \
        phpenv rehash && \
        phpenv global "${PHP_VERSIONS%% *}" \
    ' \
    && rm -rf /root/.phpenv/cache

# Composer
RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer

### ELIXIR ###

ARG ERLANG_VERSION=28.5.0.1
ARG ELIXIR_VERSION=1.20.0
RUN --mount=type=cache,target=/root/.cache/mise \
    mise install "erlang@${ERLANG_VERSION}" "elixir@${ELIXIR_VERSION}-otp-28" \
    && mise use --global "erlang@${ERLANG_VERSION}" "elixir@${ELIXIR_VERSION}-otp-28" \
    && mise cache clear || true

### DATABASE, AUDIO, VIDEO, AND SUBTITLE CLIS ###

ARG MONGOSH_VERSION=2.8.3

ARG DUCKDB_VERSION=1.5.4
ARG DUCKDB_SHA256_AMD64=c1d6db2294895c97849bee574b21eb462528857ccf8a23617dd3e0a05dd4b770
ARG DUCKDB_SHA256_ARM64=32fea57520b1ae6caa291717d5f5d4d478fb6f8ed2d2c7054096a038fc6be833

ARG USQL_VERSION=0.21.4
ARG USQL_SHA256_AMD64=93537a7239737b3d0cd2f42b7a13766a455a40176be7c0896a3586cd698cf751
ARG USQL_SHA256_ARM64=69cce9f81d95a855260437567453376e08539ca412305818d08cc4e17b9a42cb

ARG CLICKHOUSE_VERSION=26.4.4.38
ARG CLICKHOUSE_COMMON_SHA512_AMD64=d430fdb0e7e7b5ca50ff38f7b5402488fe5179bff4817f2170c3cbad5eaf172b03bf2121d0c38b800ed6615106aea422503438a294e66aeab4d3d31fea16992b
ARG CLICKHOUSE_COMMON_SHA512_ARM64=7f8ee539dca74418fa30784c1e454f11304b7b25e1b7d0ad33d2fec7b2baa3f9f646521b20f2b79485dbc5d0fb1f6f5919597cf52494168350eae050927cfbf5
ARG CLICKHOUSE_CLIENT_SHA512_AMD64=3cc877dd2e31c61560805f08ab29bfe2d2749ef38d351ec4dd7ef61f01eab97c22e98598d57f79651ecde1f83bc1fbe4c524a24ca055467abc9cebe1930f21f4
ARG CLICKHOUSE_CLIENT_SHA512_ARM64=dcbf481cac4380bd9d9a367251eae5b570e206f013cba84444ce8893461c3d94ba0555d045b73a9757c95aab536939afe457a126f5b46e410a06c7412af83308

ARG SACD_RIPPER_COMMIT=a3d981c935c3224217e2842cd492f9351106c81e
ARG SACD_RIPPER_SHA256=db903b03d28a03282020a76bc7b6e146bb51969ddcac2bc855096b5363379677
ARG FFSUBSYNC_VERSION=0.4.32

RUN --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/root/.cache/pipx \
    set -e; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        abcde=2.9.* \
        atomicparsley=20210715.151551.e7ad03a-1 \
        bchunk=1.2.* \
        bzip2=1.0.* \
        ccextractor=0.94* \
        cdparanoia=3.10.* \
        cuetools=1.4.* \
        default-mysql-client=1.1.* \
        dvdbackup=0.4.* \
        faad=2.11.* \
        ffmpeg=7:6.1.* \
        flac=1.4.* \
        gpac=2.2.* \
        id3v2=0.1.* \
        lame=3.100-* \
        libsox-fmt-all=14.4.* \
        libxml2=2.9.* \
        lsdvd=0.17-* \
        mediainfo=24.01.* \
        mkvtoolnix=82.0-* \
        mp3gain=1.6.* \
        mp3splt=2.6.* \
        mp3val=0.1.* \
        musepack-tools=2:0.1* \
        normalize-audio=0.7.* \
        opus-tools=0.2-* \
        postgresql-client=16+257build1* \
        python3-srt=3.5.* \
        redis-tools=5:7.0.* \
        rsgain=3.4-* \
        shntool=3.0.* \
        sox=14.4.* \
        subliminal=2.1.* \
        twolame=0.4.* \
        vobcopy=1.2.* \
        vorbis-tools=1.4.* \
        vorbisgain=0.37-* \
        wavpack=5.6.*; \
    . "$NVM_DIR/nvm.sh"; \
    nvm use "$NODE_VERSION"; \
    npm install -g "mongosh@${MONGOSH_VERSION}"; \
    npm cache clean --force || true; \
    pipx install --pip-args="--no-cache-dir --no-compile --root-user-action=ignore" "ffsubsync==${FFSUBSYNC_VERSION}"; \
    curl -fsSL "https://github.com/sacd-ripper/sacd-ripper/archive/${SACD_RIPPER_COMMIT}.tar.gz" -o /tmp/sacd-ripper.tar.gz; \
    echo "${SACD_RIPPER_SHA256}  /tmp/sacd-ripper.tar.gz" | sha256sum -c -; \
    mkdir -p /tmp/sacd-ripper; \
    tar -xzf /tmp/sacd-ripper.tar.gz -C /tmp/sacd-ripper --strip-components=1; \
    cmake -S /tmp/sacd-ripper/tools/sacd_extract -B /tmp/sacd-build -DCMAKE_BUILD_TYPE=Release; \
    cmake --build /tmp/sacd-build -j"$(nproc)"; \
    install -m 0755 /tmp/sacd-build/sacd_extract /usr/local/bin/sacd_extract; \
    rm -rf /tmp/sacd-ripper /tmp/sacd-build /tmp/sacd-ripper.tar.gz /var/lib/apt/lists/*; \
    case "$TARGETARCH" in \
      amd64) duckdb_arch="amd64"; duckdb_sha256="$DUCKDB_SHA256_AMD64"; usql_arch="amd64"; usql_sha256="$USQL_SHA256_AMD64"; clickhouse_arch="amd64"; clickhouse_common_sha512="$CLICKHOUSE_COMMON_SHA512_AMD64"; clickhouse_client_sha512="$CLICKHOUSE_CLIENT_SHA512_AMD64" ;; \
      arm64) duckdb_arch="arm64"; duckdb_sha256="$DUCKDB_SHA256_ARM64"; usql_arch="arm64"; usql_sha256="$USQL_SHA256_ARM64"; clickhouse_arch="arm64"; clickhouse_common_sha512="$CLICKHOUSE_COMMON_SHA512_ARM64"; clickhouse_client_sha512="$CLICKHOUSE_CLIENT_SHA512_ARM64" ;; \
      *) echo "Unsupported database/media CLI architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/duckdb/duckdb/releases/download/v${DUCKDB_VERSION}/duckdb_cli-linux-${duckdb_arch}.gz" -o /tmp/duckdb.gz; \
    echo "${duckdb_sha256}  /tmp/duckdb.gz" | sha256sum -c -; \
    gunzip -c /tmp/duckdb.gz > /usr/local/bin/duckdb; \
    chmod 0755 /usr/local/bin/duckdb; \
    rm -f /tmp/duckdb.gz; \
    curl -fsSL "https://github.com/xo/usql/releases/download/v${USQL_VERSION}/usql_static-${USQL_VERSION}-linux-${usql_arch}.tar.bz2" -o /tmp/usql.tar.bz2; \
    echo "${usql_sha256}  /tmp/usql.tar.bz2" | sha256sum -c -; \
    tar -xjf /tmp/usql.tar.bz2 -C /tmp usql_static; \
    install -m 0755 /tmp/usql_static /usr/local/bin/usql; \
    rm -f /tmp/usql.tar.bz2 /tmp/usql_static; \
    clickhouse_base_url="https://github.com/ClickHouse/ClickHouse/releases/download/v${CLICKHOUSE_VERSION}-stable"; \
    curl -fsSL "${clickhouse_base_url}/clickhouse-common-static-${CLICKHOUSE_VERSION}-${clickhouse_arch}.tgz" -o /tmp/clickhouse-common-static.tgz; \
    curl -fsSL "${clickhouse_base_url}/clickhouse-client-${CLICKHOUSE_VERSION}-${clickhouse_arch}.tgz" -o /tmp/clickhouse-client.tgz; \
    echo "${clickhouse_common_sha512}  /tmp/clickhouse-common-static.tgz" | sha512sum -c -; \
    echo "${clickhouse_client_sha512}  /tmp/clickhouse-client.tgz" | sha512sum -c -; \
    mkdir -p /tmp/clickhouse /etc/clickhouse-client; \
    tar -xzf /tmp/clickhouse-common-static.tgz -C /tmp/clickhouse; \
    tar -xzf /tmp/clickhouse-client.tgz -C /tmp/clickhouse; \
    install -m 0755 "/tmp/clickhouse/clickhouse-common-static-${CLICKHOUSE_VERSION}/usr/bin/clickhouse" /usr/local/bin/clickhouse; \
    install -m 0644 "/tmp/clickhouse/clickhouse-client-${CLICKHOUSE_VERSION}/etc/clickhouse-client/config.xml" /etc/clickhouse-client/config.xml; \
    for name in ch chc chdig chl clickhouse-benchmark clickhouse-chdig clickhouse-client clickhouse-compressor clickhouse-format clickhouse-local clickhouse-obfuscator; do ln -sf /usr/local/bin/clickhouse "/usr/local/bin/${name}"; done; \
    rm -rf /tmp/clickhouse /tmp/clickhouse-common-static.tgz /tmp/clickhouse-client.tgz; \
    psql --version; \
    mysql --version; \
    redis-cli --version; \
    mongosh --version; \
    duckdb --version; \
    usql --version; \
    clickhouse local --version; \
    sacd_extract --help | head -n 1

### SETUP SCRIPTS ###

COPY setup_universal.sh /opt/codex/setup_universal.sh
RUN chmod +x /opt/codex/setup_universal.sh

### AI CLIS ###

ARG CLAUDE_CODE_VERSION=2.1.181
ARG GEMINI_CLI_VERSION=0.47.0
ARG CODEX_CLI_VERSION=0.141.0
ARG CODEX_CLI_SHA256_AMD64=f1e2bf9fa0ba6eb82119d621b6b71bc38edd33c06dc2867b31a027052358957d
ARG CODEX_CLI_SHA256_ARM64=8c9f31811d659fcc17c5f1a21bc0971984469c9e3a63c2b39b61cc7694f3a101

ARG ANTIGRAVITY_CLI_VERSION=1.0.9
ARG ANTIGRAVITY_CLI_URL_AMD64=https://github.com/google-antigravity/antigravity-cli/releases/download/1.0.9/agy_cli_linux_x64.tar.gz
ARG ANTIGRAVITY_CLI_SHA512_AMD64=9c09eef905ea34079988908067cb716aaeadf3807ea572403d792c5113533213f98f43159d63679408819869bfe143d8e2789e3fab0f28593ffd04f2a7dcf47b
ARG ANTIGRAVITY_CLI_URL_ARM64=https://github.com/google-antigravity/antigravity-cli/releases/download/1.0.9/agy_cli_linux_arm64.tar.gz
ARG ANTIGRAVITY_CLI_SHA512_ARM64=e0b13d0cc3f1337962d1dff7f03f44b2c44b5e07dd483c9633a00235d7b5c8257c6dc5e084b12281aaa18e1c94aa81602c994ee19b5d2e376bc24d85f569372d

RUN --mount=type=cache,target=/root/.npm \
    set -e; \
    . "$NVM_DIR/nvm.sh"; \
    nvm use "$NODE_VERSION"; \
    npm install -g \
        "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
        "@google/gemini-cli@${GEMINI_CLI_VERSION}"; \
    npm cache clean --force || true; \
    case "$TARGETARCH" in \
      amd64) codex_arch="x86_64"; codex_sha256="$CODEX_CLI_SHA256_AMD64" ;; \
      arm64) codex_arch="aarch64"; codex_sha256="$CODEX_CLI_SHA256_ARM64" ;; \
      *) echo "Unsupported Codex CLI architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    codex_asset="codex-${codex_arch}-unknown-linux-musl"; \
    codex_url="https://github.com/openai/codex/releases/download/rust-v${CODEX_CLI_VERSION}/${codex_asset}.tar.gz"; \
    curl -fsSL "$codex_url" -o /tmp/codex.tar.gz; \
    echo "${codex_sha256}  /tmp/codex.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/codex.tar.gz -C /tmp; \
    install -m 0755 "/tmp/${codex_asset}" /usr/local/bin/codex; \
    rm -f /tmp/codex.tar.gz "/tmp/${codex_asset}"; \
    case "$TARGETARCH" in \
      amd64) agy_url="$ANTIGRAVITY_CLI_URL_AMD64"; agy_sha512="$ANTIGRAVITY_CLI_SHA512_AMD64" ;; \
      arm64) agy_url="$ANTIGRAVITY_CLI_URL_ARM64"; agy_sha512="$ANTIGRAVITY_CLI_SHA512_ARM64" ;; \
      *) echo "Unsupported Antigravity CLI architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "$agy_url" -o /tmp/antigravity.tar.gz; \
    echo "${agy_sha512}  /tmp/antigravity.tar.gz" | sha512sum -c -; \
    tar -xzf /tmp/antigravity.tar.gz -C /tmp antigravity; \
    install -m 0755 /tmp/antigravity /usr/local/bin/agy; \
    ln -sf /usr/local/bin/agy /usr/local/bin/antigravity; \
    rm -f /tmp/antigravity.tar.gz /tmp/antigravity; \
    codex --version; \
    claude --version; \
    gemini --version; \
    test "$(agy --version)" = "$ANTIGRAVITY_CLI_VERSION"

### VERIFICATION SCRIPT ###

COPY verify.sh /opt/verify.sh
RUN chmod +x /opt/verify.sh \
    && PYTHON_VERSIONS="$PYTHON_VERSIONS" \
        NODE_VERSIONS="$NODE_VERSION" \
        RUST_VERSIONS="$RUST_VERSIONS" \
        GO_VERSIONS="$GO_VERSIONS" \
        SWIFT_VERSIONS="$SWIFT_VERSIONS" \
        RUBY_VERSIONS="$RUBY_VERSIONS" \
        PHP_VERSIONS="$PHP_VERSIONS" \
        JAVA_VERSIONS="$JAVA_VERSION" \
        "/opt/verify.sh"

### ENTRYPOINT ###

COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

ENTRYPOINT  ["/opt/entrypoint.sh"]
