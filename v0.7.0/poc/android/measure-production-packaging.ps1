param(
    [Parameter(Mandatory=$true)][string]$ProductionApk,
    [string]$Sdk = 'D:\Android\Sdk', [string]$Java = 'D:\dev\jdk-17'
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$tools = Join-Path $Sdk 'build-tools\36.0.0'
$platform = Join-Path $Sdk 'platforms\android-36\android.jar'
function Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed: $LASTEXITCODE" }
}
New-Item -ItemType Directory -Force build\packaging,build\packaging\classes,build\packaging\dex | Out-Null
$src = Join-Path $PSScriptRoot 'src\com\mediaflow\research\v070\processing\NativeEngine.java'
Checked "$Java\bin\javac.exe" @('-encoding','UTF-8','-source','17','-target','17','-classpath',$platform,'-d','build\packaging\classes',$src)
Checked "$Java\bin\jar.exe" @('cf','build\packaging\engine.jar','-C','build\packaging\classes','.')
Checked "$tools\d8.bat" @('--lib',$platform,'--min-api','24','--output','build\packaging\dex','build\packaging\engine.jar')
Copy-Item build\packaging\dex\classes.dex build\packaging\classes2.dex
Copy-Item -LiteralPath $ProductionApk -Destination build\packaging\baseline-unsigned.apk
Copy-Item -LiteralPath $ProductionApk -Destination build\packaging\candidate-unsigned.apk
# Exact packaging specimen only. Original manifest/Flutter program retained;
# engine code is present but inactive. NEVER INSTALL: package still production,
# signatures are deliberately the separate test key. This does not prove an
# integrated Flutter adapter or a production Release build.
Push-Location build\packaging
try { Checked "$tools\aapt.exe" @('add','candidate-unsigned.apk','classes2.dex') } finally { Pop-Location }
foreach ($variant in @('baseline','candidate')) {
    Checked "$tools\zipalign.exe" @('-f','4',"build\packaging\$variant-unsigned.apk","build\packaging\$variant-aligned.apk")
    Checked "$tools\apksigner.bat" @('sign','--ks','build\poc-test.jks','--ks-key-alias','poc','--ks-pass','pass:poc-local-only','--key-pass','pass:poc-local-only','--out',"build\packaging\$variant-DO-NOT-INSTALL.apk","build\packaging\$variant-aligned.apk")
}
$base = (Get-Item build\packaging\baseline-DO-NOT-INSTALL.apk).Length
$candidate = (Get-Item build\packaging\candidate-DO-NOT-INSTALL.apk).Length
[pscustomobject]@{OriginalReleaseApk=(Get-Item -LiteralPath $ProductionApk).Length;BaselineReSigned=$base;CandidateReSigned=$candidate;EnginePackagingDelta=$candidate-$base;OriginalToCandidateDelta=$candidate-(Get-Item -LiteralPath $ProductionApk).Length;NativeLibrariesAdded=0;IntegratedFlutterAdapter='NOT BUILT';Installed=$false} | ConvertTo-Json | Set-Content build\packaging\sizes.json
Get-Content build\packaging\sizes.json
