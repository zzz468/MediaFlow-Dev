param([Parameter(Mandatory=$true)][string]$BuiltRuntime)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$manifest=Get-Content -LiteralPath (Join-Path $repo 'third_party/ffmpeg/runtime-manifest.json') -Raw | ConvertFrom-Json
$source=[IO.Path]::GetFullPath($BuiltRuntime)
$destination=Join-Path $repo 'windows/third_party/ffmpeg/bin'
foreach($entry in $manifest) {
  $file=Join-Path $source $entry.name
  if(!(Test-Path -LiteralPath $file) -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower() -ne $entry.sha256) {
    throw "Unreviewed runtime input: $($entry.name). Rebuild/source correspondence must be reviewed before changing the lock."
  }
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach($entry in $manifest) {
  $target=Join-Path $destination $entry.name
  if(Test-Path -LiteralPath $target) {
    if((Get-FileHash -LiteralPath $target).Hash.ToLower() -ne $entry.sha256) { throw "Existing runtime differs; preserve: $target" }
  } else { Copy-Item -LiteralPath (Join-Path $source $entry.name) -Destination $target }
}
Write-Output 'Pinned FFmpeg runtime prepared for Windows builds.'
