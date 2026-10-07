param([string]$Repository = 'D:\projects\mediaflow-v070')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$localRoot = Join-Path $Repository 'v0.7.0/poc/local/phase5'
$releaseRoot = Join-Path $localRoot 'windows-release-final-01'
$archivePath = Join-Path $localRoot 'windows-release-final-01.zip'
if (!(Test-Path -LiteralPath $archivePath)) {
    [IO.Compression.ZipFile]::CreateFromDirectory($releaseRoot, $archivePath, [IO.Compression.CompressionLevel]::Optimal, $false)
}
$files = @(Get-ChildItem -LiteralPath $releaseRoot -Recurse -File)
$native = foreach ($file in Get-ChildItem -LiteralPath (Join-Path $releaseRoot 'processing/ffmpeg') -File) {
    $baseline = Join-Path $Repository ('v0.7.0/poc/local/phase3b/windows-release-final/processing/ffmpeg/' + $file.Name)
    $digest = (Get-FileHash -LiteralPath $file.FullName).Hash
    [ordered]@{name=$file.Name; bytes=$file.Length; sha256=$digest; identicalToPhase3B=($digest -eq (Get-FileHash -LiteralPath $baseline).Hash)}
}
$apk = Join-Path $localRoot 'app-release-final-01.apk'
$zip = [IO.Compression.ZipFile]::OpenRead($apk)
$baseZip = [IO.Compression.ZipFile]::OpenRead((Join-Path $Repository 'v0.7.0/poc/local/phase4/app-release-final-02.apk'))
try {
    $libraries = foreach ($entry in $zip.Entries | Where-Object {$_.FullName -match '^lib/.*\.so$'}) {
        $stream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $digest = [Convert]::ToHexString($sha.ComputeHash($stream)) } finally {$stream.Dispose();$sha.Dispose()}
        $baseline = $baseZip.GetEntry($entry.FullName)
        $same = $null
        if ($entry.FullName -match 'libmediaflow_processing_storage\.so$') {
            $baseStream=$baseline.Open();$baseSha=[Security.Cryptography.SHA256]::Create()
            try {$same=$digest -eq [Convert]::ToHexString($baseSha.ComputeHash($baseStream))} finally {$baseStream.Dispose();$baseSha.Dispose()}
        }
        [ordered]@{name=$entry.FullName;bytes=$entry.Length;compressedBytes=$entry.CompressedLength;sha256=$digest;phase4Bytes=$baseline.Length;processingStorageUnchanged=$same}
    }
} finally {$zip.Dispose();$baseZip.Dispose()}
$windowsBytes=($files | Measure-Object Length -Sum).Sum
$zipBytes=(Get-Item -LiteralPath $archivePath).Length
$apkBytes=(Get-Item -LiteralPath $apk).Length
$result=[ordered]@{
    atUtc=[DateTime]::UtcNow.ToString('o')
    windows=[ordered]@{normalMainRelease=$true;files=$files.Count;bytes=$windowsBytes;phase4Bytes=41143724;deltaBytes=$windowsBytes-41143724;zipOptimalBytes=$zipBytes;phase4ZipBytes=17131783;zipDeltaBytes=$zipBytes-17131783;processingRuntime=$native}
    android=[ordered]@{normalMainRelease=$true;applicationId='com.mediaflow.mediaflow';installed=$false;bytes=$apkBytes;phase4Bytes=56148728;deltaBytes=$apkBytes-56148728;sha256=(Get-FileHash -LiteralPath $apk).Hash;nativeLibraries=$libraries}
}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $Repository 'v0.7.0/research/phase5-sizes.json') -Encoding utf8
[pscustomobject]$result.windows | Select-Object files,bytes,deltaBytes,zipOptimalBytes,zipDeltaBytes
[pscustomobject]$result.android | Select-Object bytes,deltaBytes,sha256
