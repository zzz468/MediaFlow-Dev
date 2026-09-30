param([Parameter(Mandatory=$true)][string]$Marker)
$ErrorActionPreference='Stop'
$workspaceRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$binaryRoot=Join-Path $workspaceRoot 'build/gallery_observation_research'
$profileRoot=[IO.Path]::GetFullPath((Join-Path $binaryRoot 'profiles'))
$mutex=$null
$locked=$false
function Report($result,$extra=@{}) { @{result=$result;details=$extra} | ConvertTo-Json -Compress -Depth 5 }
try {
  $markerPath=[IO.Path]::GetFullPath($Marker)
  $name=[IO.Path]::GetFileName($markerPath)
  if([IO.Path]::GetDirectoryName($markerPath) -ne $profileRoot -or $name -notmatch '^network-observation-[a-f0-9]{32}\.owner\.json$'){throw 'Invalid marker path'}
  $profilePath=Join-Path $profileRoot $name.Replace('.owner.json','')
  $mutex=New-Object Threading.Mutex($false,('Local\MediaFlowV040Recovery-'+$name))
  try {$locked=$mutex.WaitOne(0)} catch [Threading.AbandonedMutexException] {$locked=$true}
  if(-not $locked){Report 'RECOVERY_BUSY';return}
  if(-not(Test-Path -LiteralPath $markerPath)) {
    if(Test-Path -LiteralPath $profilePath){Report 'INVALID_MARKER'}else{Report 'ALREADY_GONE'}
    return
  }
  foreach($path in @($binaryRoot,$profileRoot,$markerPath)) {
    if((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse rejected'}
  }
  $ownership=Get-Content -Raw -LiteralPath $markerPath | ConvertFrom-Json
  foreach($field in @('kind','profile','helperPid','helperStarted','runId','nonce')) {
    if(-not $ownership.PSObject.Properties[$field] -or $null -eq $ownership.$field){throw 'Required field absent'}
  }
  if($ownership.kind -ne 'MediaFlow-v040-research-owned-profile-v2' -or
     $ownership.profile -cne $profilePath -or $ownership.runId -cne $name.Replace('network-observation-','').Replace('.owner.json','') -or
     $ownership.nonce -notmatch '^[a-f0-9]{32}$' -or $ownership.helperPid -isnot [long] -and $ownership.helperPid -isnot [int] -or $ownership.helperPid -le 0){throw 'Invalid ownership fields'}
  $started=if($ownership.helperStarted -is [DateTime]) {$ownership.helperStarted} else {[DateTime]::ParseExact([string]$ownership.helperStarted,'o',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind)}
  if($started.Kind -ne [DateTimeKind]::Utc){throw 'UTC instance time required'}
  $innerPath=Join-Path $profilePath '.mediaflow-research-owner.json'
  if(-not(Test-Path -LiteralPath $innerPath)){throw 'Inner ownership absent'}
  if((Get-Item -LiteralPath $profilePath).Attributes -band [IO.FileAttributes]::ReparsePoint -or (Get-Item -LiteralPath $innerPath).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse owner rejected'}
  $inner=Get-Content -Raw -LiteralPath $innerPath | ConvertFrom-Json
  foreach($field in @('kind','profile','helperPid','helperStarted','runId','nonce')) {
    if(-not $inner.PSObject.Properties[$field] -or $inner.$field -cne $ownership.$field){throw 'Ownership pair mismatch'}
  }
  $helperProcess=Get-Process -Id ([int]$ownership.helperPid) -ErrorAction SilentlyContinue
  if($helperProcess) {
    $sameInstance=$helperProcess.StartTime.ToUniversalTime().Ticks -eq $started.Ticks
    Report $(if($sameInstance){'ACTIVE_SKIP'}else{'PID_REUSE_BLOCKED'}) @{sameInstance=$sameInstance}
    return
  }
  $webViews=@(Get-CimInstance Win32_Process -Filter "Name = 'msedgewebview2.exe'")
  if(@($webViews | Where-Object {-not $_.CommandLine}).Count -gt 0){Report 'PROCESS_STATE_BLOCKED';return}
  $associated=@($webViews | Where-Object {$_.CommandLine.Contains($profilePath)})
  if($associated.Count -gt 0){Report 'ACTIVE_SKIP' @{ownedWebViews=$associated.Count};return}
  $entries=@(Get-Item -LiteralPath $profilePath)+@(Get-ChildItem -LiteralPath $profilePath -Recurse -Force)
  if(@($entries | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count -gt 0){throw 'Reparse descendant rejected'}
  # Exact workspace path, matching ownership pair, inactive processes and mutex verified.
  Remove-Item -LiteralPath $profilePath -Recurse -Force
  Remove-Item -LiteralPath $markerPath
  Report 'RECOVERED' @{directoryExists=(Test-Path -LiteralPath $profilePath)}
} catch {
  Report 'INVALID_MARKER' @{errorType=$_.Exception.GetType().Name}
} finally {
  if($locked){$mutex.ReleaseMutex()}
  if($mutex){$mutex.Dispose()}
}
