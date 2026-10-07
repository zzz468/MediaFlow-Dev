param([string]$Sdk = 'D:\Android\Sdk', [string]$Java = 'D:\dev\jdk-17')
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$tools = Join-Path $Sdk 'build-tools\36.0.0'
$platform = Join-Path $Sdk 'platforms\android-36\android.jar'
function Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed: $LASTEXITCODE" }
}
New-Item -ItemType Directory -Force build\baseline,build\baseline\classes,build\baseline\dex | Out-Null
# Same fixture assets, Activity, provider, SDK and signing; only the engine is
# replaced with a no-op. Baseline is never installed or used as a fake result.
@'
package com.mediaflow.research.v070.processing;
import java.io.File;
import org.json.JSONObject;
public final class NativeEngine {
 public enum Operation { trim, extractAudio, mux, remux, extractFrame }
 public interface Progress { void update(long p,long t); }
 public static final class Request {
  public Request(Operation o,File[] i,File f,long s,long e) {}
 }
 public void cancel() {}
 public JSONObject execute(Request r,Progress p) throws Exception { return new JSONObject(); }
 public static JSONObject inspect(File f,boolean image) throws Exception { return new JSONObject(); }
}
'@ | Set-Content -Encoding utf8 build\baseline\NativeEngine.java
$src = Join-Path $PSScriptRoot 'src\com\mediaflow\research\v070\processing'
Checked "$Java\bin\javac.exe" @('-encoding','UTF-8','-source','17','-target','17','-classpath',$platform,'-d','build\baseline\classes','build\baseline\NativeEngine.java',"$src\PocActivity.java","$src\OutputProvider.java")
Checked "$Java\bin\jar.exe" @('cf','build\baseline\classes.jar','-C','build\baseline\classes','.')
Checked "$tools\d8.bat" @('--lib',$platform,'--min-api','24','--output','build\baseline\dex','build\baseline\classes.jar')
Checked "$tools\aapt.exe" @('package','-f','-M','AndroidManifest.xml','-I',$platform,'-A','build\assets','-F','build\baseline\unsigned.apk')
Copy-Item build\baseline\dex\classes.dex build\baseline\classes.dex
Push-Location build\baseline
try { Checked "$tools\aapt.exe" @('add','unsigned.apk','classes.dex') } finally { Pop-Location }
Checked "$tools\zipalign.exe" @('-f','4','build\baseline\unsigned.apk','build\baseline\aligned.apk')
Checked "$tools\apksigner.bat" @('sign','--ks','build\poc-test.jks','--ks-key-alias','poc','--ks-pass','pass:poc-local-only','--key-pass','pass:poc-local-only','--out','build\baseline\baseline-poc.apk','build\baseline\aligned.apk')
$baselineBytes = (Get-Item build\baseline\baseline-poc.apk).Length
$candidateBytes = (Get-Item build\processing-poc.apk).Length
[pscustomobject]@{BaselineIsolatedApk=$baselineBytes;CandidateIsolatedApk=$candidateBytes;EngineDelta=$candidateBytes-$baselineBytes;NativeLibraryBytes=0;ProductionApk=55863403;ProductionIntegratedDelta='NOT MEASURED: production is unchanged'} | ConvertTo-Json | Set-Content build\apk-size.json
Get-Content build\apk-size.json
