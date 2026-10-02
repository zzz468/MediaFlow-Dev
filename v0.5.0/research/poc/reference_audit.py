"""Read-only GitHub evidence collector. Source cache is audit-only, not vendored code."""
import concurrent.futures
import datetime
import hashlib
import json
from pathlib import Path
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parent
CACHE = ROOT / '.reference-cache'
REPOS = [
    'yt-dlp/yt-dlp', 'Tyrrrz/YoutubeExplode',
    'TeamNewPipe/NewPipeExtractor', 'Hexer10/youtube_explode_dart',
    'Andy-SoulShell/xhs-downloader', 'JoeanAmier/XHS-Downloader',
    'xpzouying/xiaohongshu-mcp', 'NanmiCoder/MediaCrawler',
]

def request(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'MediaFlow-Research/0.5.0',
                                             'Accept': 'application/vnd.github+json'})
    with urllib.request.urlopen(req, timeout=25) as response:
        return response.read()

def api(repo, suffix=''):
    return json.loads(request('https://api.github.com/repos/' + repo + suffix))

def collect(repo):
    record = {'repository': repo, 'checked_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    folder = CACHE / repo.replace('/', '__')
    folder.mkdir(parents=True, exist_ok=True)
    try:
        meta = api(repo)
        record.update({k: meta.get(k) for k in ['html_url', 'default_branch', 'archived',
                                               'pushed_at', 'language', 'license']})
        commit = api(repo, '/commits/' + meta['default_branch'])
        record['head'] = commit['sha']
        record['head_date'] = commit['commit']['committer']['date']
        record['head_subject'] = commit['commit']['message'].splitlines()[0]
        for label, suffix in [('releases', '/releases?per_page=3'),
                              ('issues', '/issues?state=open&per_page=8'),
                              ('license_evidence', '/license')]:
            try:
                data = api(repo, suffix)
                if label == 'releases':
                    data = [{k: item.get(k) for k in ['tag_name', 'published_at', 'html_url', 'body']} for item in data]
                elif label == 'issues':
                    data = [{k: item.get(k) for k in ['number', 'title', 'updated_at', 'html_url', 'body']}
                            for item in data if 'pull_request' not in item]
                else:
                    import base64
                    license_text = base64.b64decode(data['content']).decode('utf-8', errors='replace')
                    (folder / 'LICENSE.audit.txt').write_text(license_text, encoding='utf-8')
                    data = {k: data.get(k) for k in ['path', 'sha', 'html_url', 'license']}
                record[label] = data
            except Exception as error:
                record[label] = {'error': str(error)}
        tree = api(repo, '/git/trees/' + commit['sha'] + '?recursive=1')
        paths = [item['path'] for item in tree['tree'] if item['type'] == 'blob']
        (folder / 'tree.json').write_text(json.dumps(paths, ensure_ascii=False, indent=2), encoding='utf-8')
        record['tree_truncated'] = tree.get('truncated')
        record['tree_path_count'] = len(paths)
        record['status'] = 'METADATA VERIFIED; runtime NOT RUN'
        (folder / 'metadata.json').write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
    except Exception as error:
        record['status'] = 'UNVERIFIED'
        record['error'] = str(error)
    return record

if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        records = list(pool.map(collect, REPOS))
    output = ROOT.parent / 'reference-project-evidence.json'
    output.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding='utf-8')
    for record in records:
        print(json.dumps({k: record.get(k) for k in ['repository', 'status', 'head', 'head_date', 'error']}, ensure_ascii=False))
