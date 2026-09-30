param([string]$SdkRoot='D:\projects\mediaflow-v020\build\browser_poc\sdk')
$ErrorActionPreference='Stop'
$workspaceRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$outputRoot=Join-Path $workspaceRoot 'build/gallery_observation_research'
if(-not(Test-Path -LiteralPath (Join-Path $SdkRoot 'lib/net462/Microsoft.Web.WebView2.Core.dll'))){throw 'Existing WebView2 SDK required; no dependency download'}
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
Copy-Item -LiteralPath "$SdkRoot/lib/net462/Microsoft.Web.WebView2.Core.dll","$SdkRoot/lib/net462/Microsoft.Web.WebView2.WinForms.dll","$SdkRoot/runtimes/win-x64/native/WebView2Loader.dll","$SdkRoot/LICENSE.txt" -Destination $outputRoot
$helperSource=Join-Path $PSScriptRoot 'GalleryObservationHelper.cs'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'share-hydration.js') -Destination $outputRoot
$policySource=Join-Path $PSScriptRoot 'NetworkObservationPolicy.cs'
$pipeSource=Join-Path $PSScriptRoot 'WindowsPipeInput.cs'
$helperOutput=Join-Path $outputRoot 'GalleryObservationHelper.exe'
$coreAssembly=Join-Path $outputRoot 'Microsoft.Web.WebView2.Core.dll'
$formsAssembly=Join-Path $outputRoot 'Microsoft.Web.WebView2.WinForms.dll'
& 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe' /nologo /target:exe /platform:x64 /out:"$helperOutput" /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:"$coreAssembly" /r:"$formsAssembly" $helperSource $policySource $pipeSource
if($LASTEXITCODE -ne 0){throw 'Research helper compile failed'}
