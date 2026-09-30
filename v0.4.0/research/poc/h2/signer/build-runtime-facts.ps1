$ErrorActionPreference='Stop'
$workspaceRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../../../..')).Path
$outputRoot=Join-Path $workspaceRoot 'build/authorized_session_research'
$sourcePath=Join-Path $PSScriptRoot 'RuntimeFacts.cs'
& 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe' /nologo /target:exe /platform:x64 /out:"$outputRoot/RuntimeFacts.exe" /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:"$outputRoot/Microsoft.Web.WebView2.Core.dll" /r:"$outputRoot/Microsoft.Web.WebView2.WinForms.dll" $sourcePath
if($LASTEXITCODE -ne 0){throw 'Offline runtime facts compile failed'}
