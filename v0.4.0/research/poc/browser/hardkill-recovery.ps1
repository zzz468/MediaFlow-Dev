param([string]$Recover)
$ErrorActionPreference='Stop'
$workspaceRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$binaryRoot=Join-Path $workspaceRoot 'build/gallery_observation_research'
$profileRoot=[IO.Path]::GetFullPath((Join-Path $binaryRoot 'profiles'))
function OwnedWebViews([string]$profilePath) {
  @(Get-CimInstance Win32_Process -Filter "Name = 'msedgewebview2.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($profilePath) })
}
function Report($data) { $data | ConvertTo-Json -Compress -Depth 8 }
if($Recover) {
  & (Join-Path $PSScriptRoot 'recover-owned-profile.ps1') -Marker $Recover
  return
}
$helper=Join-Path $binaryRoot 'GalleryObservationHelper.exe'
$info=New-Object Diagnostics.ProcessStartInfo
$info.FileName=$helper
$info.Arguments='douyinPublicObservation'
$info.UseShellExecute=$false
$info.RedirectStandardInput=$true
$info.RedirectStandardOutput=$true
$info.RedirectStandardError=$true
$info.CreateNoWindow=$true
$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$process=New-Object Diagnostics.Process
$process.StartInfo=$info
if(-not $process.Start()){throw 'Helper start failed'}
$errorDrain=$process.StandardError.ReadToEndAsync()
$config=@{enabled=$true;registered=$true;scenario='hardkill';navigation='https://www.douyin.com/note/7690029886242009957';hosts=@('www.douyin.com');paths=@('/aweme/v1/web/aweme/detail/','/aweme/v1/web/aweme/slidesinfo/');maxBodyBytes=1048576;maxTotalBytes=2097152;maxCandidates=8;maxConsumerCalls=8;durationMs=20000}
$process.StandardInput.WriteLine(($config | ConvertTo-Json -Compress))
$profilePath=$null
$markerPath=$null
try {
  while(-not $process.HasExited) {
    $readTask=$process.StandardOutput.ReadLineAsync()
    if(-not $readTask.Wait(12000)){throw 'Fixture event timeout'}
    $line=$readTask.Result
    if(-not $line){break}
    $frame=$line | ConvertFrom-Json
    if($frame.kind -eq 'candidate'){throw 'Offline fixture unexpectedly emitted body'}
    Write-Output $line
    if($frame.kind -eq 'profile') {
      $profilePath=[IO.Path]::GetFullPath([string]$frame.profile)
      if([IO.Path]::GetDirectoryName($profilePath) -ne $profileRoot -or [IO.Path]::GetFileName($profilePath) -notmatch '^network-observation-[a-f0-9]{32}$' -or -not $frame.initialDirectoryAbsent){throw 'Fresh ownership validation failed'}
      $markerPath=$profilePath+'.owner.json'
      $marker=@{kind='MediaFlow-v040-research-owned-profile-v2';profile=$profilePath;helperPid=$process.Id;helperStarted=$process.StartTime.ToUniversalTime().ToString('o');runId=[IO.Path]::GetFileName($profilePath).Replace('network-observation-','');nonce=[Guid]::NewGuid().ToString('N')}
      New-Item -ItemType Directory -Force -Path $profilePath | Out-Null
      [IO.File]::WriteAllText((Join-Path $profilePath '.mediaflow-research-owner.json'),($marker | ConvertTo-Json -Compress))
      [IO.File]::WriteAllText($markerPath,($marker | ConvertTo-Json -Compress))
    }
    if($frame.kind -eq 'fixtureLoaded') {
      if(-not $markerPath -or -not(Test-Path -LiteralPath $profilePath)){throw 'Missing owned ready profile'}
      # Verify startup recovery refuses a currently active owned profile.
      & $PSCommandPath -Recover $markerPath
      if(-not(Test-Path -LiteralPath $profilePath) -or $process.HasExited){throw 'Active profile protection failed'}
      $process.Kill()
      $process.WaitForExit()
      $remaining=$process.StandardOutput.ReadToEnd()
      Report @{phase='hardKill';exitCode=$process.ExitCode;directoryRemaining=(Test-Path -LiteralPath $profilePath);finalFrameReceived=$remaining.Contains('"kind":"final"');ownedWebViews=(OwnedWebViews $profilePath).Count;marker=$markerPath}
      for($attempt=0;$attempt -lt 10 -and (OwnedWebViews $profilePath).Count -gt 0;$attempt++){Start-Sleep -Milliseconds 500}
      Report @{phase='postKill';ownedWebViews=(OwnedWebViews $profilePath).Count;directoryRemaining=(Test-Path -LiteralPath $profilePath)}
      break
    }
    if($frame.kind -eq 'final'){throw 'Helper completed before controlled hard kill'}
  }
} finally {
  if(-not $process.HasExited){$process.StandardInput.WriteLine('{"command":"stop"}');if(-not $process.WaitForExit(6000)){$process.Kill();$process.WaitForExit()}}
  $process.Dispose()
}
if(-not $markerPath){throw 'No recoverable owned marker'}
Report @{phase='nextStartupRequired';marker=$markerPath}
