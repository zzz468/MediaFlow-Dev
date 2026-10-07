"""Audit local candidate packages and pinned FFmpeg; never uploads artifacts."""
import hashlib
import json
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    manifest = json.loads((ROOT/'third_party/ffmpeg/runtime-manifest.json').read_text())
    approved = json.loads((ROOT/'v0.7.0/research/ffmpeg-phase3a-binary-manifest.json').read_text())
    if isinstance(approved, dict):
        approved = approved.get('files', approved.get('binaries', []))
    archive = ROOT/'dist/MediaFlow-v0.7.0-windows-x64.zip'
    results = {'windows': {}, 'android': {}, 'assets': []}
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        runtime = []
        for entry in manifest:
            name = next(n for n in names if n.endswith('/processing/ffmpeg/'+entry['name']))
            data = z.read(name)
            assert digest(data) == entry['sha256'].lower(), entry['name']
            original = next(e for e in approved if e['name'] == entry['name'])
            assert digest(data) == original['sha256'].lower(), entry['name']
            runtime.append({'name': entry['name'], 'bytes': len(data), 'sha256': digest(data), 'approved': True})
        actual = [n for n in names if '/processing/ffmpeg/' in n and not n.endswith('/')]
        assert len(actual) == 8
        prohibited = [n for n in names if any(p in n.lower() for p in ['/.git/', '/poc/', '/test/', '/research/', 'key.properties', 'local.properties'])
                      or n.lower().endswith(('.apk', '.mp4', '.m4a', '.jks', '.keystore', '.log', '.dmp', '.tar.xz', '.tar.gz', '.zip'))]
        assert not prohibited, prohibited
        results['windows'] = {'files': len([n for n in names if not n.endswith('/')]),
                              'unpackedBytes': sum(i.file_size for i in z.infolist()),
                              'entries': names, 'runtime': runtime, 'prohibited': prohibited,
                              'noticePresent': any(n.endswith('/licenses/ffmpeg/NOTICE.txt') for n in names),
                              'licensePresent': any(n.endswith('/licenses/ffmpeg/COPYING.LGPLv2.1') for n in names)}
    apk = ROOT/'dist/MediaFlow-v0.7.0-android.apk'
    if apk.exists():
        with zipfile.ZipFile(apk) as z:
            names = z.namelist()
            native = [{'name': i.filename, 'bytes': i.file_size, 'compressedBytes': i.compress_size,
                       'sha256': digest(z.read(i.filename))} for i in z.infolist() if i.filename.startswith('lib/')]
            forbidden = [n for n in names if any(p in n.lower() for p in ['ffmpeg', 'avcodec', 'avformat', 'avutil', 'swscale', 'swresample'])
                         or n.lower().endswith(('.mp4', '.m4a', '.jks', '.keystore'))
                         or n.lower().endswith(('key.properties', 'local.properties'))]
            assert not forbidden, forbidden
            results['android'] = {'nativeLibraries': native, 'ffmpegCount': 0, 'forbidden': forbidden,
                                  'entries': len(names)}
    for p in sorted((ROOT/'dist').glob('MediaFlow-v0.7.0-*')):
        if p.is_file() and p.suffix in {'.zip', '.apk'}:
            results['assets'].append({'filename': p.name, 'bytes': p.stat().st_size, 'sha256': digest(p.read_bytes())})
    output = ROOT/'v0.7.0/release/package-audit.json'
    output.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'windowsFiles': results['windows']['files'], 'androidAudited': apk.exists(), 'assets': results['assets']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
