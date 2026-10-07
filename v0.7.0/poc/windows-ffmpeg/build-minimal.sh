#!/usr/bin/env bash
# Own MediaFlow recipe. Build-only, no installation into the Flutter project.
set -euo pipefail
export LC_ALL=C TZ=UTC SOURCE_DATE_EPOCH=1789948800 PATH=/usr/bin
root="$(cd "$(dirname "$0")/../local/phase3a" && pwd)"
variant="${1:-build-a}"
case "$variant" in build-a|build-a-repeat) ;; *) echo 'Unsupported build workspace' >&2; exit 2 ;; esac
toolchain="$root/tools/llvm-mingw-20260922-ucrt-x86_64/bin"
export PATH="$toolchain:/usr/bin"
source_dir="$root/source/ffmpeg-8.1.3"
build_dir="$root/$variant"
if [[ -e "$build_dir" ]]; then echo 'Build directory exists; preserve evidence' >&2; exit 2; fi
mkdir -p "$build_dir"
cd "$build_dir"
args=(
  --prefix=/mediaflow-ffmpeg
  --arch=x86_64 --target-os=mingw32 --enable-cross-compile
  --cross-prefix=x86_64-w64-mingw32-
  --cc=x86_64-w64-mingw32-clang --cxx=x86_64-w64-mingw32-clang++
  --ar=llvm-ar --ranlib=llvm-ranlib --nm=llvm-nm --strip=llvm-strip
  --enable-shared --disable-static
  --disable-gpl --disable-nonfree --disable-version3
  --disable-autodetect --disable-everything
  --disable-network --disable-avdevice
  --disable-doc --disable-debug --disable-ffplay --disable-x86asm
  --disable-hwaccels --disable-iconv --disable-zlib --disable-bzlib --disable-lzma
  --disable-pthreads --enable-w32threads
  --enable-ffmpeg --enable-ffprobe --enable-swscale --enable-swresample
  --enable-protocol=file,pipe
  --enable-demuxer=mov,matroska,aac,image2
  --enable-muxer=mp4,mov,ipod,matroska,webm,image2,null
  --enable-decoder=h264,aac,mjpeg,vp9,opus
  --enable-encoder=mjpeg,wrapped_avframe,pcm_s16le
  --enable-parser=h264,aac,mjpeg,vp9,opus
  --enable-bsf=aac_adtstoasc,h264_mp4toannexb,extract_extradata,vp9_superframe
  --enable-filter=scale,format,null,anull,aresample
  --extra-cflags=-ffile-prefix-map="$root"=/mediaflow-build
  --extra-ldflags=-Wl,--no-insert-timestamp
)
printf '%s\n' "${args[@]}" > requested-config.txt
"$source_dir/configure" "${args[@]}" > configure.log 2>&1
make -j4 > make.log 2>&1
make install DESTDIR="$build_dir/stage" > install.log 2>&1
"$build_dir/stage/mediaflow-ffmpeg/bin/ffmpeg.exe" -version > version.txt 2>&1
"$build_dir/stage/mediaflow-ffmpeg/bin/ffmpeg.exe" -L > license.txt 2>&1
echo "Build complete: $build_dir/stage/mediaflow-ffmpeg/bin"
