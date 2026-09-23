param(
    [string]$FlutterCommand = "D:\dev\flutter\bin\flutter.bat",
    [string]$AndroidSdk = "D:\Android\Sdk",
    [string]$KeyPropertiesPath = $env:MEDIAFLOW_ANDROID_KEY_PROPERTIES,
    [string]$Version = "v0.2.0"
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
if ([string]::IsNullOrWhiteSpace($KeyPropertiesPath) -or -not (Test-Path -LiteralPath $KeyPropertiesPath -PathType Leaf)) {
    throw "Private Android Release signing properties are required. Pass -KeyPropertiesPath pointing outside the repository."
}
$resolvedKeyPropertiesPath = (Resolve-Path -LiteralPath $KeyPropertiesPath).Path
if ($resolvedKeyPropertiesPath.StartsWith($repoRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Android Release signing properties must be stored outside the repository."
}
$env:MEDIAFLOW_ANDROID_KEY_PROPERTIES = $resolvedKeyPropertiesPath

Push-Location $repoRoot
try {
    & $FlutterCommand config --android-sdk $AndroidSdk
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to configure Android SDK."
    }

    # Flutter 3.32+ can leave dev plugins such as integration_test in the
    # Android registrant when a release build uses --no-pub. Refresh the
    # release configuration first so dev-only plugins stay out of the APK.
    & $FlutterCommand build apk --config-only
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to prepare Android Release configuration."
    }

    & $FlutterCommand build apk --release --no-pub --build-name 0.2.0 --build-number 2
    if ($LASTEXITCODE -ne 0) {
        throw "Android Release APK build failed."
    }

    $apkSigner = Join-Path $AndroidSdk "build-tools\36.0.0\apksigner.bat"
    if (-not (Test-Path -LiteralPath $apkSigner)) {
        throw "Android apksigner was not found."
    }
    $signatureDetails = & $apkSigner verify --print-certs --verbose $apkOutput
    if ($LASTEXITCODE -ne 0 -or -not ($signatureDetails -match "Verified using v[23] scheme.*true")) {
        throw "Android Release APK signature verification failed."
    }
    if ($signatureDetails -match "CN=Android Debug") {
        throw "Android Release APK is signed with the debug certificate."
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
