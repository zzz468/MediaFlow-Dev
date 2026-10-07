param(
    [string]$Sdk = 'D:\Android\Sdk',
    [string]$Java = 'D:\dev\jdk-17',
    [Parameter(Mandatory=$true)][string]$FixtureDirectory
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$tools = Join-Path $Sdk 'build-tools\36.0.0'
$platform = Join-Path $Sdk 'platforms\android-36\android.jar'
function Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with $LASTEXITCODE" }
}
New-Item -ItemType Directory -Force build,build\classes,build\dex,build\assets | Out-Null
Copy-Item -LiteralPath (Join-Path $FixtureDirectory '素材 中文 sample.mp4') -Destination build\assets\sample.mp4
Copy-Item -LiteralPath (Join-Path $FixtureDirectory 'video-only.mp4') -Destination build\assets\video-only.mp4
Copy-Item -LiteralPath (Join-Path $FixtureDirectory 'audio-only.m4a') -Destination build\assets\audio-only.m4a
$sources = @(Get-ChildItem src -Recurse -Filter *.java | ForEach-Object FullName)
Checked "$Java\bin\javac.exe" (@('-encoding','UTF-8','-source','17','-target','17','-classpath',$platform,'-d','build\classes') + $sources)
Checked "$Java\bin\jar.exe" @('cf','build\classes.jar','-C','build\classes','.')
Checked "$tools\d8.bat" @('--lib',$platform,'--min-api','24','--output','build\dex','build\classes.jar')
Checked "$tools\aapt.exe" @('package','-f','-M','AndroidManifest.xml','-I',$platform,'-A','build\assets','-F','build\unsigned.apk')
Copy-Item build\dex\classes.dex build\classes.dex
Push-Location build
try { Checked "$tools\aapt.exe" @('add','unsigned.apk','classes.dex') } finally { Pop-Location }
Checked "$tools\zipalign.exe" @('-f','4','build\unsigned.apk','build\aligned.apk')
if (!(Test-Path build\poc-test.jks)) {
    # Dedicated local test key, never production signing material.
    Checked "$Java\bin\keytool.exe" @('-genkeypair','-keystore','build\poc-test.jks','-alias','poc','-storepass','poc-local-only','-keypass','poc-local-only','-dname','CN=MediaFlow Isolated PoC','-keyalg','RSA','-validity','3650')
}
Checked "$tools\apksigner.bat" @('sign','--ks','build\poc-test.jks','--ks-key-alias','poc','--ks-pass','pass:poc-local-only','--key-pass','pass:poc-local-only','--out','build\processing-poc.apk','build\aligned.apk')
Checked "$tools\apksigner.bat" @('verify','--print-certs','build\processing-poc.apk')
Checked "$tools\aapt.exe" @('dump','badging','build\processing-poc.apk')
Get-Item build\processing-poc.apk | Select-Object FullName,Length
# This script builds only. Installation requires the AGENTS.md preflight.
