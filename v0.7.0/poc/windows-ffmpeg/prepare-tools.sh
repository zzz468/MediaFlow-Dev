#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/bin
root="$(cd "$(dirname "$0")/../local/phase3a" && pwd)"
cd "$root/tools/msys64"
tar --zstd -xf "$root/downloads/make-4.4.1-3-x86_64.pkg.tar.zst" usr/bin/make.exe
tar --zstd -xf "$root/downloads/diffutils-3.12-1-x86_64.pkg.tar.zst" usr/bin/cmp.exe usr/bin/diff.exe
mkdir -p "$root/gnupg"
chmod 700 "$root/gnupg"
gpg --homedir "$root/gnupg" --batch --import "$root/downloads/ffmpeg-devel.asc"
if [[ ! -f "$root/downloads/ffmpeg-8.1.3.tar.xz.asc" ]]; then
  curl --fail --location https://ffmpeg.org/releases/ffmpeg-8.1.3.tar.xz.asc -o "$root/downloads/ffmpeg-8.1.3.tar.xz.asc"
fi
gpg --homedir "$root/gnupg" --batch --status-fd 1 --verify \
  "$root/downloads/ffmpeg-8.1.3.tar.xz.asc" "$root/downloads/ffmpeg-8.1.3.tar.xz" > "$root/source-signature.txt" 2>&1
grep -q 'VALIDSIG FCF986EA15E6E293A5644F10B4322F04D67658D8' "$root/source-signature.txt"
