# Isolated, pinned build inputs. No system installation or production changes.
$ErrorActionPreference = 'Stop'
$taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../local/phase3a'))
$downloadDir = Join-Path $taskRoot 'downloads'
$toolsDir = Join-Path $taskRoot 'tools'
$sourceDir = Join-Path $taskRoot 'source'
New-Item -ItemType Directory -Force -Path $downloadDir,$toolsDir,$sourceDir | Out-Null
$inputs = @(
  @('ffmpeg-8.1.3.tar.xz','https://ffmpeg.org/releases/ffmpeg-8.1.3.tar.xz','7138d28c96d9d3e3af4ee3d8cad72741f8ffb40da90c1112235dea3ecd3178a3'),
  @('llvm-mingw-20260922-ucrt-x86_64.zip','https://github.com/mstorsjo/llvm-mingw/releases/download/20260922/llvm-mingw-20260922-ucrt-x86_64.zip','e3ad77d117a4bea19a7a3b333341824d79a5a371004a10e25b8504e7b3047666'),
  @('msys2-base-x86_64-20260927.tar.xz','https://github.com/msys2/msys2-installer/releases/download/2026-09-27/msys2-base-x86_64-20260927.tar.xz','ea2f31a0b6ade63914ce441ffb022f0f6aa96982bfefa2326460a26d5fb01322'),
  @('make-4.4.1-3-x86_64.pkg.tar.zst','https://repo.msys2.org/msys/x86_64/make-4.4.1-3-x86_64.pkg.tar.zst','af0bdba17f06fe037f0194069adaa31a8fe45f1a11381501896aea1fae37bd5d'),
  @('diffutils-3.12-1-x86_64.pkg.tar.zst','https://repo.msys2.org/msys/x86_64/diffutils-3.12-1-x86_64.pkg.tar.zst','7902c8ce3d4dd69a0f5e98dc9d5c83c17b23314ba486169db57ef6e2835ce3b6'),
  @('mingw-w64-57b5950.tar.gz','https://github.com/mingw-w64/mingw-w64/archive/57b595039040eaa15bece85b7cc71d952281b269.tar.gz','a68816e314290facd5da1ac96c7eead7e6de6ea4f709a1fbdcf8185497c57eb2'),
  @('ffmpeg-devel.asc','https://ffmpeg.org/ffmpeg-devel.asc','397b3becedcd5a98769967ff1ff8501ddc89f8368b8f766e4701377d7dbaabe5')
)
foreach ($inputItem in $inputs) {
  $destination = Join-Path $downloadDir $inputItem[0]
  if (!(Test-Path -LiteralPath $destination)) { Invoke-WebRequest -UseBasicParsing $inputItem[1] -OutFile $destination }
  if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLower() -ne $inputItem[2]) { throw "Hash mismatch: $destination" }
}
foreach ($extract in @(
  @('llvm-mingw-20260922-ucrt-x86_64.zip',$toolsDir,'llvm-mingw-20260922-ucrt-x86_64'),
  @('msys2-base-x86_64-20260927.tar.xz',$toolsDir,'msys64'),
  @('ffmpeg-8.1.3.tar.xz',$sourceDir,'ffmpeg-8.1.3'),
  @('mingw-w64-57b5950.tar.gz',$sourceDir,'mingw-w64-57b595039040eaa15bece85b7cc71d952281b269')
)) {
  if (!(Test-Path -LiteralPath (Join-Path $extract[1] $extract[2]))) {
    & tar.exe -xf (Join-Path $downloadDir $extract[0]) -C $extract[1]
    if ($LASTEXITCODE -ne 0) { throw 'Extraction failed' }
  }
}
$bash = Join-Path $toolsDir 'msys64/usr/bin/bash.exe'
# Bash reads this repository recipe; no shell interpolation of user paths.
& $bash --noprofile --norc (Join-Path $PSScriptRoot 'prepare-tools.sh')
if ($LASTEXITCODE -ne 0) { throw 'Tool preparation failed' }
Write-Output 'Pinned inputs verified. Run build-minimal.sh in a NEW build directory.'
