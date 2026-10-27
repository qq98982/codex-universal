#!/bin/bash

set -euo pipefail

echo "Verifying slim AI agent toolbox ..."

need() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null; then
      echo "missing command: $cmd" >&2
      return 1
    fi
  done
}

echo "- Core shell and search tools:"
need bash git gh rg rga rga-preproc fd fzf jq yq bat delta eza zoxide btop duf \
  tree tmux vim nano curl wget rsync ssh scp zip unzip 7zz unar xz make parallel \
  shellcheck shfmt sqlite3 socat strace telnet whois nc lsof pv progress
bash --version | sed -n '1p'
git --version
gh --version | sed -n '1p'
rg --version | sed -n '1p'
rga --version
fd --version
fzf --version
jq --version
yq --version
bat --version
delta --version

echo "- AI CLIs:"
need node npm codex codex-code-mode-host claude gemini agy antigravity
node --version
npm --version
codex --version
codex-code-mode-host --help >/dev/null
timeout 5 codex-code-mode-host </dev/null
/opt/codex/test_codex_package.sh
claude --version
gemini --version
agy --version

echo "- Container and cloud CLIs:"
need docker docker-compose aws az gcloud gke-gcloud-auth-plugin kubectl helm
docker --version
docker buildx version
docker compose version
docker-compose version
aws --version
az version --output json | jq -r '."azure-cli"'
gcloud --version | sed -n '1p'
gke-gcloud-auth-plugin --version
kubectl version --client=true
helm version --short

echo "- Headless browsers:"
need playwright playwright-browser fetch-page browser-use chromium chromium-browser google-chrome chrome firefox webkit
browser_use_home="$(mktemp -d)"
browser_use_runtime="$(mktemp -d)"
cleanup_browser_use() {
  if [[ -s "$browser_use_runtime/chromium.pid" ]]; then
    kill "$(cat "$browser_use_runtime/chromium.pid")" 2>/dev/null || true
    for _ in $(seq 1 50); do
      kill -0 "$(cat "$browser_use_runtime/chromium.pid")" 2>/dev/null || break
      sleep 0.1
    done
  fi
  rm -rf "$browser_use_home" "$browser_use_runtime" /tmp/browser-use-smoke.out \
    /tmp/org.chromium.Chromium.*
}
trap cleanup_browser_use EXIT

playwright --version
HOME="$browser_use_home" browser-use --version
/opt/browser-use/tools/browser-use/bin/python - <<'PY'
import os
from importlib.metadata import version

assert version("browser-use") == os.environ["EXPECTED_BROWSER_USE_VERSION"]
PY
chromium --headless --no-sandbox --disable-gpu --dump-dom 'data:text/html,<main>browser-wrapper-ok</main>' | grep browser-wrapper-ok
fetch-page 'data:text/html,<main><h1>fetch-page-ok</h1><table><tr><td>Progressive</td></tr></table></main>' | grep fetch-page-ok
fetch-page --selector table 'data:text/html,<main><h1>fetch-page-ok</h1><table><tr><td>Progressive</td></tr></table></main>' | grep Progressive
fetch-page --html --selector main 'data:text/html,<main><h1>fetch-page-ok</h1><table><tr><td>Progressive</td></tr></table></main>' | grep '<main>'
NODE_PATH="$(npm root -g)" node - <<'JS'
const { chromium, firefox, webkit } = require("playwright");

(async () => {
  for (const [name, launcher] of Object.entries({ chromium, firefox, webkit })) {
    const browser = await launcher.launch({ headless: true });
    const page = await browser.newPage();
    await page.setContent("<main>browser-ok</main>");
    const text = await page.textContent("main");
    await browser.close();

    if (text !== "browser-ok") {
      throw new Error(`${name} returned unexpected page text: ${text}`);
    }

    console.log(`${name} headless launch ok`);
  }
})();
JS

for agent in codex claude gemini; do
  mkdir -p "$browser_use_home/.$agent/skills/unrelated"
  printf 'keep-%s\n' "$agent" >"$browser_use_home/.$agent/skills/unrelated/SKILL.md"
done
HOME="$browser_use_home" \
  BROWSER_USE_BIN=/opt/browser-use/bin/browser-use \
  /opt/codex/refresh-browser-use-skills
for agent in codex claude gemini; do
  grep -F "keep-${agent}" "$browser_use_home/.$agent/skills/unrelated/SKILL.md"
  test -s "$browser_use_home/.$agent/skills/browser-use/SKILL.md"
done

printf 'new_tab("data:text/html,<title>browser-use-smoke</title><main>browser-use-ok</main>")\nprint(page_info())\n' \
  | HOME="$browser_use_home" \
    BROWSER_USE_RUNTIME_DIR="$browser_use_runtime" \
    BROWSER_USE_CDP_PORT=19222 \
    timeout 90 browser-use >/tmp/browser-use-smoke.out
curl -fsS http://127.0.0.1:19222/json/version | jq -e '.Browser | length > 0' >/dev/null
grep -F 'browser-use-smoke' /tmp/browser-use-smoke.out
head -n 5 /tmp/browser-use-smoke.out
cleanup_browser_use
trap - EXIT
test ! -e /root/.config/browser-harness
if compgen -G '/tmp/org.chromium.Chromium.*' >/dev/null; then
  echo "Chromium runtime data remained after browser verification" >&2
  exit 1
fi

echo "- Python and automation:"
need python uv pipx ffsubsync
python --version
uv --version
pipx --version
ffsubsync --version
python - <<'PY'
import chardet
import charset_normalizer
import magic
import srt

print("python media/text helpers import successfully")
PY

echo "- NAS, disk, and filesystem tools:"
need rclone smbclient mount.cifs mount.nfs smartctl hdparm parted sgdisk testdisk \
  ncdu duf jdupes fdupes rdfind rmlint duperemove czkawka trash-put plocate
rclone version | sed -n '1p'
smbclient --version
mount.cifs --help 2>&1 | sed -n '1p' || true
showmount --version 2>&1 | sed -n '1p' || true
smartctl --version | sed -n '1p'
hdparm -V
parted --version | sed -n '1p'
sgdisk --version
testdisk /version | sed -n '1p'
ncdu --version
duf --version
jdupes --version | sed -n '1p'
rmlint --version | sed -n '1p'
czkawka --version

echo "- Media, subtitle, and image tools:"
need ffmpeg ffprobe mediainfo mkvmerge mkvextract exiftool identify convert cwebp \
  dwebp avifenc avifdec heif-convert jpegoptim optipng pngquant gifsicle flac \
  metaflac id3v2 mp3val AtomicParsley sox eyeD3 kid3-cli subliminal \
  srt-normalise srt-fixed-timeshift srt-linear-timeshift srt-process ffsubsync \
  ccextractor sacd_extract shnsplit cuetag cuebreakpoints cueprint cueconvert \
  bchunk wavpack wvunpack mp3splt mp3gain lame twolame faad mpcdec mpcenc \
  MP4Box dvdbackup lsdvd vobcopy abcde cdparanoia rsgain vorbisgain
ffmpeg -version | sed -n '1p'
ffprobe -version | sed -n '1p'
mediainfo --Version
mkvmerge --version
mkvextract --version
exiftool -ver
identify -version | sed -n '1p'
cwebp -version
avifenc --version | sed -n '1p'
heif-convert --version
jpegoptim --version | sed -n '1p'
optipng -v | sed -n '1p'
pngquant --version | sed -n '1p'
flac --version
metaflac --version
id3v2 --version
mp3val 2>&1 | sed -n '1p'
AtomicParsley -v 2>&1 | sed -n '1p'
sox --version
subliminal --version
ffsubsync --version
ccextractor --version 2>&1 | sed -n '1p' || true
sacd_extract --help | sed -n '1p'
shnsplit -v 2>&1 | sed -n '1p'
cuetag 2>&1 | sed -n '1p'
cueprint --version | sed -n '1p'
wavpack --version | sed -n '1p'
mp3splt -v | sed -n '1p'
mp3gain -v 2>&1 | sed -n '1p'
lame --version | sed -n '1p'
twolame --help 2>&1 | sed -n '1p' || true
faad --help 2>&1 | sed -n '1p' || true
mpcdec -h 2>&1 | sed -n '1p'
MP4Box -version > /tmp/mp4box-version.out 2>&1
head -n 2 /tmp/mp4box-version.out
rm -f /tmp/mp4box-version.out
rm -rf /root/.gpac
dvdbackup --version | sed -n '1p'
lsdvd --version 2>&1 | sed -n '1p' || true
vobcopy -v 2>&1 | sed -n '1p' || true
abcde -v | sed -n '1p'
cdparanoia -V 2>&1 | sed -n '1p' || true
rsgain --version | sed -n '1p'
vorbisgain --version | sed -n '1p'

echo "- Database clients:"
need psql mysql redis-cli mongosh duckdb usql clickhouse clickhouse-client clickhouse-local
psql --version
mysql --version
redis-cli --version
mongosh --version
duckdb --version
usql --version
clickhouse client --version
clickhouse local --version

echo "- Documents, OCR, and encoding tools:"
need pandoc pdftotext pdfinfo tesseract ocrmypdf antiword catdoc odt2txt unrtf \
  xlsx2csv csvcut uchardet enca nkf iconv dos2unix convmv detox recode
pandoc --version | sed -n '1p'
pdftotext -v 2>&1 | sed -n '1p'
pdfinfo -v 2>&1 | sed -n '1p'
tesseract --version | sed -n '1p'
ocrmypdf --version
antiword -h 2>&1 | sed -n '1p' || true
catdoc -V 2>&1 | sed -n '1p'
odt2txt --version
unrtf --version | sed -n '1p'
xlsx2csv --version
csvcut --version
uchardet --version
enca --version | sed -n '1p'
nkf --version | sed -n '1p'
iconv --version | sed -n '1p'
dos2unix --version | sed -n '1p'
convmv 2>&1 | sed -n '1p' || true

echo "Slim toolbox detected successfully."
