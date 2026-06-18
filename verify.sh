#!/bin/bash --login

set -euo pipefail

echo "Verifying language runtimes ..."

read -ra PYTHON <<< "$PYTHON_VERSIONS"
read -ra NODE   <<< "$NODE_VERSIONS"
read -ra RUST   <<< "$RUST_VERSIONS"
read -ra GO     <<< "$GO_VERSIONS"
read -ra SWIFT  <<< "$SWIFT_VERSIONS"
read -ra RUBY   <<< "$RUBY_VERSIONS"
read -ra PHP    <<< "$PHP_VERSIONS"
read -ra JAVA   <<< "$JAVA_VERSIONS"

max=$(printf "%s\n" \
  ${#PYTHON[@]} \
  ${#NODE[@]} \
  ${#RUST[@]} \
  ${#GO[@]} \
  ${#SWIFT[@]} \
  ${#RUBY[@]} \
  ${#PHP[@]} \
  ${#JAVA[@]} \
  | sort -nr | head -1)

for ((i=max-1; i>=0; i--)); do
  CODEX_ENV_PYTHON_VERSION=${PYTHON[i]:-${PYTHON[0]}} \
  CODEX_ENV_NODE_VERSION=${NODE[i]:-${NODE[0]}} \
  CODEX_ENV_RUST_VERSION=${RUST[i]:-${RUST[0]}} \
  CODEX_ENV_GO_VERSION=${GO[i]:-${GO[0]}} \
  CODEX_ENV_SWIFT_VERSION=${SWIFT[i]:-${SWIFT[0]}} \
  CODEX_ENV_RUBY_VERSION=${RUBY[i]:-${RUBY[0]}} \
  CODEX_ENV_PHP_VERSION=${PHP[i]:-${PHP[0]}} \
  CODEX_ENV_JAVA_VERSION=${JAVA[i]:-${JAVA[0]}} \
  bash -lc '
    printf "\n\nTesting setup_universal with versions:\n"
    env | grep "^CODEX_ENV_" | sort
    printf "\n"
    /opt/codex/setup_universal.sh
  '
done

echo "- Python:"
python3 --version
pyenv versions | sed 's/^/  /'

echo "- Node.js:"
node --version
npm --version
pnpm --version
yarn --version
codex --version
claude --version
gemini --version
agy --version
npm ls -g

echo "- Database clients:"
psql --version
mysql --version
redis-cli --version
mongosh --version
duckdb --version
usql --version
clickhouse client --version
clickhouse local --version

echo "- Media, audio, and subtitle CLIs:"
ffmpeg -version | head -n 1
ffprobe -version | head -n 1
mediainfo --Version
mkvmerge --version
mkvextract --version
flac --version
metaflac --version
shnsplit -v 2>&1 | head -n 1
cuetag 2>&1 | head -n 1
sacd_extract --help | head -n 1
ffsubsync --version
subliminal --version
ccextractor --version 2>&1 | head -n 1 || true
cueprint --version | head -n 1
bchunk 2>&1 | head -n 1 || true
wavpack --version | head -n 1
mp3splt -v | head -n 1
mp3gain -v 2>&1 | head -n 1
lame --version | head -n 1
twolame --help 2>&1 | head -n 1 || true
faad --help 2>&1 | head -n 1 || true
mpcdec -h 2>&1 | head -n 1
MP4Box -version > /tmp/mp4box-version.out 2>&1
head -n 2 /tmp/mp4box-version.out
rm -f /tmp/mp4box-version.out
rm -rf /root/.gpac
dvdbackup --version | head -n 1
lsdvd --version 2>&1 | head -n 1 || true
vobcopy -v 2>&1 | head -n 1 || true
abcde -v | head -n 1
cdparanoia -V 2>&1 | head -n 1 || true
rsgain --version | head -n 1
vorbisgain --version | head -n 1

echo "- Bun:"
bun --version

echo "- Java / Gradle:"
java -version
javac -version
gradle --version | head -n 3
mvn --version | head -n 1

echo "- Swift:"
swift --version

echo "- Ruby:"
ruby --version

echo "- Rust:"
rustc --version
cargo --version

echo "- Go:"
go version

echo "- PHP:"
php --version
composer --version

echo "- Elixir:"
elixir --version
erl -version
erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell

echo "All language runtimes detected successfully."
