param(
    [Parameter(Mandatory = $true)]
    [string] $KeyPropertiesPath,
    [Parameter(Mandatory = $true)]
    [string] $KeyStorePath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$registrantPath = Join-Path $projectRoot 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'
$propertiesPath = (Resolve-Path -LiteralPath $KeyPropertiesPath).Path
$storePath = (Resolve-Path -LiteralPath $KeyStorePath).Path
$originalRegistrant = [System.IO.File]::ReadAllText($registrantPath)
$devPluginPattern = '(?ms)^    try \{\r?\n      flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\r?\n    \} catch \(Exception e\) \{\r?\n      Log\.e\(TAG, "Error registering plugin integration_test, dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin", e\);\r?\n    \}\r?\n'
$releaseRegistrant = [regex]::Replace($originalRegistrant, $devPluginPattern, '')

if ($releaseRegistrant -eq $originalRegistrant) {
    throw 'Expected generated integration_test registration was not found; inspect Flutter plugin generation before building.'
}

$pluginMetadata = Get-Content -LiteralPath (Join-Path $projectRoot '.flutter-plugins-dependencies') -Raw | ConvertFrom-Json
$testPlugin = $pluginMetadata.plugins.android | Where-Object { $_.name -eq 'integration_test' }
if (@($testPlugin).Count -ne 1 -or $testPlugin.dev_dependency -ne $true) {
    throw 'integration_test is not an Android dev dependency; refusing to alter the generated registrant.'
}

$keyLines = @(Get-Content -LiteralPath $propertiesPath)
if (@($keyLines | Where-Object { $_ -match '^storeFile=' }).Count -ne 1) {
    throw 'Expected exactly one storeFile entry in signing properties.'
}
$keyLines = @($keyLines | ForEach-Object {
    if ($_ -match '^storeFile=') {
        'storeFile=' + ($storePath -replace '\\', '/')
    } else {
        $_
    }
})
$temporaryProperties = Join-Path $env:TEMP ('mediaflow-v030-signing-' + [guid]::NewGuid().ToString('N') + '.properties')
$previousProperties = $env:MEDIAFLOW_ANDROID_KEY_PROPERTIES

try {
    [System.IO.File]::WriteAllLines($temporaryProperties, [string[]] $keyLines)
    [System.IO.File]::WriteAllText($registrantPath, $releaseRegistrant)
    $env:MEDIAFLOW_ANDROID_KEY_PROPERTIES = $temporaryProperties
    Push-Location $projectRoot
    try {
        flutter build apk --release --no-pub
        if ($LASTEXITCODE -ne 0) {
            throw "Android Release build failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
} finally {
    [System.IO.File]::WriteAllText($registrantPath, $originalRegistrant)
    Remove-Item -LiteralPath $temporaryProperties -Force -ErrorAction SilentlyContinue
    $env:MEDIAFLOW_ANDROID_KEY_PROPERTIES = $previousProperties
}
