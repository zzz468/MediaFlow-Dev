# Creates a NEW isolated deployment model and a corresponding-source companion.
# Does not modify the actual app release, install, publish, or sign anything.
$ErrorActionPreference = 'Stop'
$taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../local/phase3a'))
$baseline = 'D:\projects\mediaflow-v060\build\windows\x64\runner\Release'
$packageRoot = Join-Path $taskRoot 'deployment'
if (Test-Path -LiteralPath $packageRoot) { throw 'Preserve prior package evidence' }
New-Item -ItemType Directory -Path $packageRoot | Out-Null
Copy-Item -LiteralPath $baseline -Destination (Join-Path $packageRoot 'MediaFlow') -Recurse
$app = Join-Path $packageRoot 'MediaFlow'
$runtime = Join-Path $app 'processing/ffmpeg'
$notices = Join-Path $app 'licenses/ffmpeg'
New-Item -ItemType Directory -Path $runtime,$notices | Out-Null
Get-ChildItem (Join-Path $taskRoot 'build-a/stage/mediaflow-ffmpeg/bin') -File |
  Where-Object Extension -In '.exe','.dll' | Copy-Item -Destination $runtime
Copy-Item (Join-Path $PSScriptRoot '../../research/licenses/ffmpeg/*') -Destination $notices
Copy-Item (Join-Path $PSScriptRoot '../../research/ffmpeg-phase3a-configuration.txt') $notices
Copy-Item (Join-Path $PSScriptRoot '../../research/ffmpeg-phase3a-binary-manifest.json') $notices
$sourceCompanion = Join-Path $packageRoot 'corresponding-source'
New-Item -ItemType Directory -Path $sourceCompanion | Out-Null
Copy-Item (Join-Path $taskRoot 'downloads/ffmpeg-8.1.3.tar.xz') $sourceCompanion
Copy-Item (Join-Path $taskRoot 'downloads/ffmpeg-8.1.3.tar.xz.asc') $sourceCompanion
Copy-Item (Join-Path $taskRoot 'downloads/ffmpeg-devel.asc') $sourceCompanion
Copy-Item (Join-Path $taskRoot 'downloads/mingw-w64-57b5950.tar.gz') $sourceCompanion
Copy-Item -LiteralPath $PSScriptRoot -Destination (Join-Path $sourceCompanion 'recipe') -Recurse
Copy-Item (Join-Path $PSScriptRoot '../../research/ffmpeg-build-recipe.md') $sourceCompanion
Copy-Item (Join-Path $PSScriptRoot '../../research/ffmpeg-release-compliance.md') $sourceCompanion
Copy-Item -LiteralPath $notices -Destination (Join-Path $sourceCompanion 'licenses') -Recurse
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($baseline,(Join-Path $packageRoot 'baseline.zip'),[IO.Compression.CompressionLevel]::Optimal,$false)
[IO.Compression.ZipFile]::CreateFromDirectory($app,(Join-Path $packageRoot 'candidate.zip'),[IO.Compression.CompressionLevel]::Optimal,$false)
[IO.Compression.ZipFile]::CreateFromDirectory($sourceCompanion,(Join-Path $packageRoot 'corresponding-source.zip'),[IO.Compression.CompressionLevel]::Optimal,$false)
function Bytes($path) { (Get-ChildItem -LiteralPath $path -Recurse -File | Measure-Object Length -Sum).Sum }
$sizes = [ordered]@{
  baselineUnpacked = (Bytes $baseline); candidateUnpacked = (Bytes $app)
  runtimeBytes = (Bytes $runtime); noticesBytes = (Bytes $notices)
  baselineZip = (Get-Item (Join-Path $packageRoot 'baseline.zip')).Length
  candidateZip = (Get-Item (Join-Path $packageRoot 'candidate.zip')).Length
  sourceCompanionZip = (Get-Item (Join-Path $packageRoot 'corresponding-source.zip')).Length
}
$sizes.unpackedDelta = $sizes.candidateUnpacked - $sizes.baselineUnpacked
$sizes.zipDelta = $sizes.candidateZip - $sizes.baselineZip
$sizes | ConvertTo-Json | Set-Content (Join-Path $PSScriptRoot '../../research/ffmpeg-phase3a-sizes.json') -Encoding utf8
$sizes
