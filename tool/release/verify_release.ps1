param(
    [string]$FlutterCommand = "D:\dev\flutter\bin\flutter.bat"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Push-Location $repoRoot
try {
    & $FlutterCommand analyze
    if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed." }

    & $FlutterCommand test
    if ($LASTEXITCODE -ne 0) { throw "flutter test failed." }
} finally {
    Pop-Location
}