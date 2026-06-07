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
bash --version | head -n 1
git --version
gh --version | head -n 1
rg --version | head -n 1
rga --version
fd --version
fzf --version
jq --version
yq --version
bat --version
delta --version

echo "- AI CLIs:"
need node npm codex claude gemini agy antigravity
node --version
npm --version
codex --version
claude --version
gemini --version
agy --version

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
rclone version | head -n 1
smbclient --version
mount.cifs --help 2>&1 | head -n 1 || true
showmount --version 2>&1 | head -n 1 || true
smartctl --version | head -n 1
hdparm -V
parted --version | head -n 1
sgdisk --version
testdisk /version | head -n 1
ncdu --version
duf --version
jdupes --version | head -n 1
rmlint --version | head -n 1
czkawka --version

echo "- Media, subtitle, and image tools:"
need ffmpeg ffprobe mediainfo mkvmerge mkvextract exiftool identify convert cwebp \
  dwebp avifenc avifdec heif-convert jpegoptim optipng pngquant gifsicle flac \
  metaflac id3v2 mp3val AtomicParsley sox eyeD3 kid3-cli subliminal \
  srt-normalise srt-fixed-timeshift srt-linear-timeshift srt-process
ffmpeg -version | head -n 1
ffprobe -version | head -n 1
mediainfo --Version
mkvmerge --version
mkvextract --version
exiftool -ver
identify -version | head -n 1
cwebp -version
avifenc --version | head -n 1
heif-convert --version
jpegoptim --version | head -n 1
optipng -v | head -n 1
pngquant --version | head -n 1
flac --version
metaflac --version
id3v2 --version
mp3val 2>&1 | head -n 1
AtomicParsley -v 2>&1 | head -n 1
sox --version
subliminal --version

echo "- Documents, OCR, and encoding tools:"
need pandoc pdftotext pdfinfo tesseract ocrmypdf antiword catdoc odt2txt unrtf \
  xlsx2csv csvcut uchardet enca nkf iconv dos2unix convmv detox recode
pandoc --version | head -n 1
pdftotext -v 2>&1 | head -n 1
pdfinfo -v 2>&1 | head -n 1
tesseract --version | head -n 1
ocrmypdf --version
antiword -h 2>&1 | head -n 1
catdoc -V 2>&1 | head -n 1
odt2txt --version
unrtf --version | head -n 1
xlsx2csv --version
csvcut --version
uchardet --version
enca --version | head -n 1
nkf --version | head -n 1
iconv --version | head -n 1
dos2unix --version | head -n 1
convmv 2>&1 | head -n 1 || true

echo "Slim toolbox detected successfully."
