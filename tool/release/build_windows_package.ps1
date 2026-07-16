param(
    [string]$FlutterCommand = "D:\dev\flutter\bin\flutter.bat",
    [string]$Version = "v0.1.0-beta",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$distRoot = Join-Path $repoRoot "dist"
$packageName = "MediaFlow-$Version-windows-x64"
$packageDirectory = Join-Path $distRoot $packageName
$zipPath = Join-Path $distRoot "$packageName.zip"
$hashPath = "$zipPath.sha256"
$releaseDirectory = Join-Path $repoRoot "build\windows\x64\runner\Release"

Push-Location $repoRoot
try {
    if (-not $SkipBuild) {
        & $FlutterCommand clean
        if ($LASTEXITCODE -ne 0) {
            throw "flutter clean failed."
        }

        & $FlutterCommand build windows --release --build-name 0.1.0 --build-number 1
        if ($LASTEXITCODE -ne 0) {
            throw "Windows Release build failed."
        }
    }

    if (-not (Test-Path -LiteralPath (Join-Path $releaseDirectory "MediaFlow.exe"))) {
        throw "MediaFlow.exe was not found in the Windows Release directory."
    }

    New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
    if (Test-Path -LiteralPath $packageDirectory) {
        Remove-Item -LiteralPath $packageDirectory -Recurse -Force
    }
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    if (Test-Path -LiteralPath $hashPath) {
        Remove-Item -LiteralPath $hashPath -Force
    }

    New-Item -ItemType Directory -Force -Path $packageDirectory | Out-Null
    Copy-Item -Path (Join-Path $releaseDirectory "*") -Destination $packageDirectory -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot "README.md") -Destination $packageDirectory
    Copy-Item -LiteralPath (Join-Path $repoRoot "LICENSE") -Destination $packageDirectory
    Copy-Item -LiteralPath (Join-Path $repoRoot "docs\USER_GUIDE.md") -Destination $packageDirectory

    @"
MediaFlow $Version
Platform: Windows x64
Executable: MediaFlow.exe
License: Apache-2.0
Runtime: Windows 10/11 x64
Possible dependency: Microsoft Visual C++ Redistributable 2015-2022 x64
"@ | Set-Content -LiteralPath (Join-Path $packageDirectory "RELEASE_INFO.txt") -Encoding UTF8

    Compress-Archive -Path $packageDirectory -DestinationPath $zipPath -CompressionLevel Optimal
    $hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $([System.IO.Path]::GetFileName($zipPath))" | Set-Content -LiteralPath $hashPath -Encoding ASCII

    Write-Output "Package: $zipPath"
    Write-Output "SHA256: $hashPath"
} finally {
    Pop-Location
}