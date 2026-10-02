"""Download licensed reference files into ignored audit cache; no production reuse."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
from reference_audit import ROOT, CACHE, request

SELECTED = {
 'Hexer10/youtube_explode_dart': ['pubspec.yaml', 'CHANGELOG.md', 'lib/src/videos/video_controller.dart',
   'lib/src/videos/streams/stream_client.dart', 'lib/src/videos/streams/stream_controller.dart',
   'lib/src/videos/youtube_api_client.dart', 'lib/src/reverse_engineering/player/player_response.dart',
   'lib/src/reverse_engineering/player/player_source.dart', 'lib/src/reverse_engineering/youtube_http_client.dart',
   'lib/src/reverse_engineering/challenges/ejs/deno_ejs_solver.dart',
   'lib/src/reverse_engineering/challenges/js_challenge.dart'],
 'Tyrrrz/YoutubeExplode': ['YoutubeExplode/YoutubeExplode.csproj', 'YoutubeExplode/Videos/VideoController.cs',
   'YoutubeExplode/Videos/Streams/StreamController.cs', 'YoutubeExplode/Videos/Streams/StreamClient.cs',
   'YoutubeExplode/Bridge/PlayerResponse.cs', 'YoutubeExplode/Bridge/PlayerSource.cs'],
 'TeamNewPipe/NewPipeExtractor': ['extractor/build.gradle.kts',
   'extractor/src/main/java/org/schabi/newpipe/extractor/services/youtube/extractors/YoutubeStreamExtractor.java',
   'extractor/src/main/java/org/schabi/newpipe/extractor/services/youtube/YoutubeParsingHelper.java',
   'extractor/src/main/java/org/schabi/newpipe/extractor/services/youtube/ItagItem.java'],
 'yt-dlp/yt-dlp': ['pyproject.toml', 'yt_dlp/extractor/youtube/_base.py',
   'yt_dlp/extractor/youtube/_video.py', 'yt_dlp/extractor/youtube/jsc/README.md',
   'yt_dlp/extractor/youtube/pot/README.md'],
 'Andy-SoulShell/xhs-downloader': ['pyproject.toml', 'package.json',
   'packages/xhs-adapters/src/xhs_adapters/http_feed_detail.py',
   'packages/xhs-adapters/src/xhs_adapters/_http_feed_page.py',
   'packages/xhs-adapters/src/xhs_adapters/_http_read_requests.py',
   'packages/xhs-adapters/src/xhs_adapters/parsing/feed_detail.py',
   'packages/xhs-adapters/src/xhs_adapters/parsing/media.py',
   'apps/extension/src/feed-detail-parser.ts', 'apps/extension/src/page-data.ts',
   'packages/xhs-adapters/src/xhs_adapters/managed_page_session.py'],
 'JoeanAmier/XHS-Downloader': ['pyproject.toml', 'source/application/explore.py',
   'source/application/request.py', 'source/application/video.py', 'source/application/image.py',
   'source/module/note_info.py', 'source/module/script.py'],
 'xpzouying/xiaohongshu-mcp': ['go.mod', 'xiaohongshu/feed_detail.go', 'xiaohongshu/types.go',
   'xiaohongshu/navigate.go', 'xiaohongshu/login.go', 'browser/browser.go', 'cookies/cookies.go'],
 'NanmiCoder/MediaCrawler': ['pyproject.toml', 'media_platform/xhs/client.py',
   'media_platform/xhs/extractor.py', 'media_platform/xhs/media.py',
   'media_platform/xhs/login.py', 'media_platform/xhs/playwright_sign.py'],
}

def fetch(item):
    repo, path = item
    folder = CACHE / repo.replace('/', '__')
    meta = json.loads((folder / 'metadata.json').read_text(encoding='utf-8'))
    url = 'https://raw.githubusercontent.com/' + repo + '/' + meta['head'] + '/' + path
    result = {'repository': repo, 'commit': meta['head'], 'file': path, 'url': url}
    try:
        content = request(url)
        target = folder / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        result.update(status='SOURCE FETCHED FOR AUDIT', bytes=len(content), sha256=hashlib.sha256(content).hexdigest())
    except Exception as error:
        result.update(status='SOURCE NOT FETCHED', error=str(error))
    return result

if __name__ == '__main__':
    import sys
    if len(sys.argv) == 3:
        result = fetch((sys.argv[1], sys.argv[2]))
        evidence_path = ROOT.parent / 'reference-source-index.json'
        evidence = json.loads(evidence_path.read_text(encoding='utf-8'))
        evidence.append(result)
        evidence_path.write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps(result))
        sys.exit(0)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(fetch, [(repo, path) for repo, paths in SELECTED.items() for path in paths]))
    (ROOT.parent / 'reference-source-index.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    package = json.loads(request('https://pub.dev/api/packages/youtube_explode_dart'))
    (ROOT.parent / 'youtube-dart-package-evidence.json').write_text(json.dumps(package, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Source files:', len(results), 'fetched:', sum(r['status'].startswith('SOURCE FETCHED') for r in results))
    print('pub.dev latest:', package['latest']['version'], package['latest']['published'])
    for result in results:
        if 'error' in result: print(json.dumps(result))
