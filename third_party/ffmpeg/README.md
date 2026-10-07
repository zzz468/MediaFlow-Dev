# Windows processing runtime lock

FFmpeg official 8.1.3/n8.1.3, upstream commit 1041abdc962f4cc4f394aa8de9dc5236c0c3b9e7.
LGPL-2.1-or-later shared; GPL/nonfree/network disabled, external media libraries zero.
Runtime manifest locks the reviewed Phase3A build. No BtbN binary is distributed.

Build inputs/own reproducible recipe: v0.7.0/research/ffmpeg-build-recipe.md and
v0.7.0/poc/windows-ffmpeg/{bootstrap.ps1,prepare-tools.sh,build-minimal.sh}.
Run bootstrap and the fixed recipe to obtain a build; the recorded binary lock
was reproduced twice in the recorded workspace. Rebuilding at another location
can change the embedded configuration path: review/version its new manifest and
source correspondence rather than silently accepting unknown binaries.

Stage reviewed build with tools/processing/prepare_windows_ffmpeg.ps1 -BuiltRuntime
<absolute reviewed bin>. Generated files go to windows/third_party/ffmpeg/bin.
CMake verifies that lock at build time and installs only 2 EXE + 6 DLL into
processing/ffmpeg, and the files here into licenses/ffmpeg. The app discovers
relative to its own executable, with no PATH/download fallback or runtime hash lock.
Compatible FFmpeg DLLs remain replaceable by the user after installation.

Runtime distribution: these notices + locked EXE/DLL, no .lib/toolchain/source archive.
Source/compliance companion: exact official source archive, signature/key, CRT source,
configuration and build recipe; keep a matched independent release artifact.
Research-only: fixtures, test APK/EXE, build/toolchain/logs, package size models.
Formal download/about/EULA/installer/source-delivery/legal review remains required.
