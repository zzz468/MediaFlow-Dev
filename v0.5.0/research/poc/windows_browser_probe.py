"""Prepare an official WebView2 SDK for an isolated, ordinary anonymous page probe."""
import io
import json
from pathlib import Path
import sys
import urllib.request
import zipfile
import subprocess
import hashlib
import shutil
import time
import uuid
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent
SDK = ROOT / '.reference-cache' / 'webview2-sdk'

def fetch(url):
    with urllib.request.urlopen(url, timeout=25) as response:
        return response.read()

def prepare():
    base = 'https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/'
    versions = json.loads(fetch(base + 'index.json'))['versions']
    version = next(v for v in reversed(versions) if '-' not in v)
    data = fetch(base + version + '/microsoft.web.webview2.' + version + '.nupkg')
    SDK.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for item in archive.infolist():
            if not (SDK / item.filename).resolve().is_relative_to(SDK.resolve()):
                raise RuntimeError('Unsafe SDK archive')
        archive.extractall(SDK)
    license_files = list(SDK.glob('*LICENSE*'))
    print(json.dumps({'version':version, 'licenseFiles':[p.name for p in license_files]}))
    (ROOT / 'windows-browser-sdk-evidence.json').write_text(json.dumps({
        'package':'Microsoft.Web.WebView2','version':version,
        'source':base + version + '/microsoft.web.webview2.' + version + '.nupkg',
        'scope':'research only; official Windows SDK; no production dependency',
        'platforms':{'Windows':'native SDK','Android':'use independent System WebView adapter',
                     'iOS':'future WKWebView adapter','macOS':'future WKWebView adapter','Linux':'future browser adapter'},
        'runtime':'existing system WebView2, no runtime installation requested',
        'licenseFiles':[p.name for p in license_files],
    },ensure_ascii=False,indent=2),encoding='utf-8')

def run():
    output = ROOT / '.reference-cache' / 'windows-page-runtime'
    profile = output / 'profiles' / ('anonymous-' + uuid.uuid4().hex)
    output.mkdir(parents=True,exist_ok=True)
    for source in ['lib/net462/Microsoft.Web.WebView2.Core.dll',
                   'lib/net462/Microsoft.Web.WebView2.WinForms.dll',
                   'runtimes/win-x64/native/WebView2Loader.dll','LICENSE.txt']:
        shutil.copy2(SDK / source, output / Path(source).name)
    command = [r'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe','/nologo','/target:exe','/platform:x64',
               '/out:' + str(output / 'WindowsAnonymousPage.exe'),'/r:System.Windows.Forms.dll',
               '/r:System.Drawing.dll','/r:System.Web.Extensions.dll',
               '/r:' + str(output / 'Microsoft.Web.WebView2.Core.dll'),
               '/r:' + str(output / 'Microsoft.Web.WebView2.WinForms.dll'), str(ROOT / 'WindowsAnonymousPage.cs')]
    compiled = subprocess.run(command,capture_output=True)
    if compiled.returncode:
        print(compiled.stdout.decode('utf-8',errors='replace'))
        raise RuntimeError('Research helper build failed')
    # No credentials/profile import; single sample which previously timed out on Windows.
    request = subprocess.run([str(output / 'WindowsAnonymousPage.exe'),'https://xhslink.cn/o/4wRbjSYrcBJ',str(profile)],
                             capture_output=True,timeout=45)
    data = json.loads(request.stdout.decode('utf-8-sig'))
    for group in ['images','videoStreams']:
        for item in data.get(group,[]):
            source = item.pop('url',None)
            if source:
                parsed = urlsplit(source)
                item.update(urlHost=parsed.hostname,urlScheme=parsed.scheme,
                            urlSha256=hashlib.sha256(source.encode()).hexdigest())
    cleaned = not profile.exists()
    if profile.exists():
        if not profile.resolve().is_relative_to((output / 'profiles').resolve()):
            raise RuntimeError('Profile cleanup escaped owned research root')
        for attempt in range(3):
            try:
                shutil.rmtree(profile)
                cleaned=True
                break
            except OSError:
                time.sleep(0.4)
    data.update(profileCleaned=cleaned,sample='xhs-gallery-8',sessionLevel=1,
                scope='ordinary own anonymous WebView2; no login; no exported cookies; one sample')
    (ROOT / 'windows-anonymous-browser-results.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({key:data.get(key) for key in ['status','failure','reason','noteId','imageCount','profileCleaned']}))

if __name__ == '__main__' and sys.argv[1:] == ['--prepare']:
    prepare()
elif __name__ == '__main__' and sys.argv[1:] == ['--run']:
    run()
