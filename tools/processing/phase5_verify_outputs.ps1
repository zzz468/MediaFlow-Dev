$ErrorActionPreference = 'Stop'
$repository = 'D:\projects\mediaflow-v070'
$phase5Root = Join-Path $repository 'v0.7.0/poc/local/phase5'
$validator = Join-Path $repository 'v0.7.0/poc/local/ffmpeg/ffmpeg-n8.1-latest-win64-lgpl-shared-8.1/bin'
$windowsEvidence = Get-Content -LiteralPath (Join-Path $phase5Root 'windows-run-04/phase5-acceptance.json') -Raw | ConvertFrom-Json
$windowsFiles = @($windowsEvidence.results | ForEach-Object { $_.output })
$androidFiles = @(Get-ChildItem -LiteralPath (Join-Path $phase5Root 'android-output-04') -File | ForEach-Object { $_.FullName })
$checks = foreach ($outputFile in @($windowsFiles) + @($androidFiles)) {
    $probe = & (Join-Path $validator 'ffprobe.exe') -v error -show_streams -show_format -of json $outputFile
    if ($LASTEXITCODE -ne 0) { throw "Probe failed: $outputFile" }
    $decode = & (Join-Path $validator 'ffmpeg.exe') -v error -i $outputFile -map 0 -f null - 2>&1
    if ($LASTEXITCODE -ne 0 -or $decode) { throw "Decode failed: $outputFile $decode" }
    [ordered]@{file=$outputFile;bytes=(Get-Item -LiteralPath $outputFile).Length;sha256=(Get-FileHash -LiteralPath $outputFile).Hash;fullDecode='PASS';probe=($probe -join "`n" | ConvertFrom-Json)}
}
$result = [ordered]@{atUtc=[DateTime]::UtcNow.ToString('o');validator='Independent existing LGPL FFmpeg 8.1';outputs=@($checks);originalSha256=(Get-FileHash -LiteralPath (Join-Path $phase5Root '输入 中文.mp4')).Hash}
$result | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath (Join-Path $repository 'v0.7.0/research/phase5-output-validation.json') -Encoding utf8
$checks | ForEach-Object { [pscustomobject]$_ } | Select-Object file,bytes,fullDecode
