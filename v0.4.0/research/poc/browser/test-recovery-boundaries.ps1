$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$profiles=[IO.Path]::GetFullPath((Join-Path $root 'build/gallery_observation_research/profiles'))
$recovery=Join-Path $PSScriptRoot 'recover-owned-profile.ps1'
$shell=(Get-Process -Id $PID).Path
$owned=New-Object Collections.Generic.List[object]
$children=New-Object Collections.Generic.List[Diagnostics.Process]
function Child([string]$arguments) {
  $info=New-Object Diagnostics.ProcessStartInfo
  $info.FileName=$shell;$info.Arguments=$arguments;$info.UseShellExecute=$false
  $info.CreateNoWindow=$true;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
  $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
  $p=[Diagnostics.Process]::Start($info);$children.Add($p);return $p
}
function Fixture($process) {
  $guid=[Guid]::NewGuid().ToString('N')
  $path=Join-Path $profiles ('network-observation-'+$guid)
  if(Test-Path -LiteralPath $path){throw 'Unexpected fixture exists'}
  New-Item -ItemType Directory -Path $path | Out-Null
  $data=@{kind='MediaFlow-v040-research-owned-profile-v2';profile=$path;runId=$guid;nonce=[Guid]::NewGuid().ToString('N');helperPid=$process.Id;helperStarted=$process.StartTime.ToUniversalTime().ToString('o')}
  $fixture=@{path=$path;marker=$path+'.owner.json';data=$data}
  $owned.Add($fixture)
  Write-Pair $fixture
  return $fixture
}
function Write-Pair($fixture) {
  $text=$fixture.data | ConvertTo-Json -Compress
  [IO.File]::WriteAllText($fixture.marker,$text)
  [IO.File]::WriteAllText((Join-Path $fixture.path '.mediaflow-research-owner.json'),$text)
}
function Assert($condition,$name,$result) {
  if(-not $condition){throw "Assertion failed: $name ($result)"}
  @{case=$name;status='PASS';actual=$result} | ConvertTo-Json -Compress
}
function Recover($fixture) { (& $recovery -Marker $fixture.marker) | ConvertFrom-Json }
try {
  $activeProcess=Child '-NoProfile -NonInteractive -Command "Start-Sleep -Seconds 120"'
  $staleProcess=Child '-NoProfile -NonInteractive -Command "Start-Sleep -Seconds 120"'
  $stale=Fixture $staleProcess
  $active=Fixture $activeProcess
  $badJson=Fixture $staleProcess
  $missing=Fixture $staleProcess
  $forged=Fixture $staleProcess
  $reuse=Fixture $activeProcess
  $concurrent=Fixture $staleProcess
  $abandoned=Fixture $staleProcess
  $staleProcess.Kill();$staleProcess.WaitForExit()
  $r=Recover $active
  Assert ($r.result -eq 'ACTIVE_SKIP' -and (Test-Path -LiteralPath $active.path)) 'active-marker' $r.result
  $r=Recover $stale
  Assert ($r.result -eq 'RECOVERED' -and -not(Test-Path -LiteralPath $stale.path) -and (Test-Path -LiteralPath $active.path)) 'mixed-stale-active' $r.result
  [IO.File]::WriteAllText($badJson.marker,'{broken')
  $r=Recover $badJson
  Assert ($r.result -eq 'INVALID_MARKER' -and (Test-Path -LiteralPath $badJson.path)) 'malformed-json' $r.result
  $missing.data.Remove('helperStarted');Write-Pair $missing
  $r=Recover $missing
  Assert ($r.result -eq 'INVALID_MARKER' -and (Test-Path -LiteralPath $missing.path)) 'missing-start-time' $r.result
  $outer=$forged.data.Clone();$outer.nonce=[Guid]::NewGuid().ToString('N')
  [IO.File]::WriteAllText($forged.marker,($outer | ConvertTo-Json -Compress))
  $r=Recover $forged
  Assert ($r.result -eq 'INVALID_MARKER' -and (Test-Path -LiteralPath $forged.path)) 'forged-outer-nonce' $r.result
  $reuse.data.helperStarted=$activeProcess.StartTime.ToUniversalTime().AddDays(-1).ToString('o');Write-Pair $reuse
  $r=Recover $reuse
  Assert ($r.result -eq 'PID_REUSE_BLOCKED' -and (Test-Path -LiteralPath $reuse.path)) 'pid-same-number-different-start-fixture' $r.result
  $arguments='-NoProfile -NonInteractive -File "'+$recovery+'" -Marker "'+$concurrent.marker+'"'
  $one=Child $arguments;$two=Child $arguments
  $one.WaitForExit();$two.WaitForExit()
  $results=@(($one.StandardOutput.ReadToEnd() | ConvertFrom-Json).result,($two.StandardOutput.ReadToEnd() | ConvertFrom-Json).result)
  Assert (@($results | Where-Object {$_ -eq 'RECOVERED'}).Count -eq 1 -and @($results | Where-Object {$_ -notin @('RECOVERED','RECOVERY_BUSY','ALREADY_GONE')}).Count -eq 0 -and -not(Test-Path -LiteralPath $concurrent.path) -and (Test-Path -LiteralPath $active.path)) 'two-concurrent-recoveries' ($results -join ',')
  # Keep a handle open so owner death leaves the kernel mutex abandoned,
  # rather than destroying the mutex and accidentally testing a new object.
  $mutexName='Local\MediaFlowV040Recovery-'+[IO.Path]::GetFileName($abandoned.marker)
  $observerMutex=New-Object Threading.Mutex($false,$mutexName)
  try {
    $command='$m=New-Object Threading.Mutex($false,'''+$mutexName+''');$null=$m.WaitOne();[Console]::WriteLine(''HELD'');Start-Sleep -Seconds 120'
    $holder=Child ('-NoProfile -NonInteractive -Command "'+$command+'"')
    $ready=$holder.StandardOutput.ReadLineAsync()
    if(-not $ready.Wait(5000) -or $ready.Result -ne 'HELD'){throw 'Mutex holder failed to become ready'}
    $r=Recover $abandoned
    Assert ($r.result -eq 'RECOVERY_BUSY' -and (Test-Path -LiteralPath $abandoned.path)) 'live-recovery-lock' $r.result
    $holder.Kill();$holder.WaitForExit()
    $r=Recover $abandoned
    Assert ($r.result -eq 'RECOVERED' -and -not(Test-Path -LiteralPath $abandoned.path) -and (Test-Path -LiteralPath $active.path)) 'abandoned-recovery-lock' $r.result
  } finally {$observerMutex.Dispose()}
} finally {
  foreach($child in $children){if(-not $child.HasExited){$child.Kill();$child.WaitForExit()};$child.Dispose()}
  foreach($fixture in $owned) {
    # Only explicit fixture paths created by this invocation, never root clearing.
    $absolute=[IO.Path]::GetFullPath($fixture.path)
    if([IO.Path]::GetDirectoryName($absolute) -ne $profiles -or [IO.Path]::GetFileName($absolute) -notmatch '^network-observation-[a-f0-9]{32}$'){throw 'Fixture cleanup path rejected'}
    if(Test-Path -LiteralPath $absolute){Remove-Item -LiteralPath $absolute -Recurse -Force}
    if(Test-Path -LiteralPath $fixture.marker){Remove-Item -LiteralPath $fixture.marker}
  }
}
