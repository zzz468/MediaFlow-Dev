param(
    [string]$FlutterCommand = "D:\dev\flutter\bin\flutter.bat",
    [string]$AndroidSdk = "D:\Android\Sdk",
    [string]$Version = "v0.1.0-beta"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$distRoot = Join-Path $repoRoot "dist"
$apkOutput = Join-Path $repoRoot "build\app\outputs\flutter-apk\app-release.apk"
$releaseApk = Join-Path $distRoot "MediaFlow-$Version-android.apk"
$hashPath = "$releaseApk.sha256"

if (-not (Test-Path -LiteralPath $AndroidSdk)) {
    throw "Android SDK not found at $AndroidSdk. Install Command-line Tools, Platform Tools, platforms;android-36, build-tools;36.0.0, and ndk;28.2.13676358. Do not install an emulator or system image."
}

Push-Location $repoRoot
try {
    & $FlutterCommand config --android-sdk $AndroidSdk
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to configure Android SDK."
    }

    & $FlutterCommand build apk --release --build-name 0.1.0-beta --build-number 1
    if ($LASTEXITCODE -ne 0) {
        throw "Android Release APK build failed."
    }

    New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
    Copy-Item -LiteralPath $apkOutput -Destination $releaseApk -Force
    $hash = (Get-FileHash -LiteralPath $releaseApk -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $([System.IO.Path]::GetFileName($releaseApk))" | Set-Content -LiteralPath $hashPath -Encoding ASCII

    Write-Output "APK: $releaseApk"
    Write-Output "SHA256: $hashPath"
} finally {
    Pop-Location
}