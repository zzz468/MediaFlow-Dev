"""Classify Git-visible RC inputs without printing potential secret contents."""
import hashlib
import json
import re
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode('utf-8').strip()

def classify(name):
    path = name.replace('\\', '/')
    lower = path.lower()
    if lower.startswith('windows/third_party/webview2/'):
        return 'D'
    if re.search(r'(?:^|/)(?:key|local)\.properties$|\.(?:jks|keystore|p12|pfx|pem|key)$', lower):
        return 'G'
    if lower.startswith(('build/', 'dist/', '.dart_tool/', 'android/.gradle/', 'android/build/')):
        return 'E'
    if '/local/' in lower or '/build/' in lower or re.search(r'\.(?:apk|aab|zip|mp4|m4a|jpg|dmp|log|exe|dll)$', lower):
        return 'F'
    if path.startswith('third_party/'):
        return 'D'
    if path.startswith(('test/', 'integration_test/', 'tools/processing/native_tests/')):
        return 'B'
    if path.startswith(('lib/', 'android/', 'windows/')) or path in {'pubspec.yaml', 'pubspec.lock', '.gitignore'}:
        return 'A'
    return 'C'

def main():
    tracked = git('ls-files', '-z').split('\0')
    untracked = git('ls-files', '--others', '--exclude-standard', '-z').split('\0')
    ignored = git('ls-files', '--others', '--ignored', '--exclude-standard', '--directory', '-z').split('\0')
    entries = []
    problems = []
    private_hits = []
    credential_hits = []
    for name in sorted(set(tracked + untracked)):
        if not name or not (ROOT/name).is_file():
            continue
        category = classify(name)
        data = (ROOT/name).read_bytes()
        entries.append({'path': name, 'category': category, 'tracked': name in tracked,
                        'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        # Actual embedded private-key blocks, not tests mentioning key delimiters.
        if re.search(rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----\s+[A-Za-z0-9+/=\r\n]{80,}', data):
            private_hits.append(name)
        # Record locations only; never emit credential or signed URL values.
        patterns = {
            'provider_key': rb'\b(?:ghp_|github_pat_|sk_live_)[A-Za-z0-9_]{24,}',
            'aws_access_key': rb'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b',
            'signed_media_url': rb'https?://[^\s\"<>]{20,}[?&](?:X-Amz-Signature|sig|signature)=[A-Za-z0-9%_-]{24,}',
        }
        for kind, pattern in patterns.items():
            if re.search(pattern, data, re.IGNORECASE if kind == 'signed_media_url' else 0):
                credential_hits.append({'path': name, 'kind': kind})
        if category in {'E', 'F', 'G'}:
            problems.append({'path': name, 'category': category})
    output = {'cwd': str(ROOT), 'topLevel': git('rev-parse', '--show-toplevel'),
              'branch': git('branch', '--show-current'), 'head': git('rev-parse', 'HEAD'),
              'base': git('merge-base', 'HEAD', 'main'),
              'stagedAreaEmpty': not bool(git('diff', '--cached', '--name-only')),
              'counts': dict(Counter(e['category'] for e in entries)),
              'entries': entries, 'ignoredRoots': [p for p in ignored if p],
              'gitVisibleExcludedMaterial': problems, 'embeddedPrivateKeys': private_hits,
              'credentialPatternHits': credential_hits}
    destination = ROOT/'v0.7.0/release/workspace-audit.json'
    destination.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: output[k] for k in ['branch', 'head', 'base', 'stagedAreaEmpty', 'counts',
                                           'gitVisibleExcludedMaterial', 'embeddedPrivateKeys', 'credentialPatternHits']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
