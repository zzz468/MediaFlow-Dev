"""Run the audited yt-dlp source with a bounded anonymous WEB configuration."""
import io
import json
from pathlib import Path
import sys
import zipfile
from reference_audit import ROOT, CACHE, request

repo = 'yt-dlp/yt-dlp'
meta = json.loads((CACHE / 'yt-dlp__yt-dlp' / 'metadata.json').read_text(encoding='utf-8'))
code_root = CACHE / 'yt-dlp-runtime'

def prepare():
    content = request('https://codeload.github.com/yt-dlp/yt-dlp/zip/' + meta['head'])
    code_root.mkdir(exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        for member in archive.infolist():
            if not (code_root / member.filename).resolve().is_relative_to(code_root.resolve()):
                raise RuntimeError('Archive path outside audit cache')
        archive.extractall(code_root)
    print('Audited source runtime prepared:', meta['head'])

def run():
    folder = next(code_root.iterdir())
    sys.path.insert(0, str(folder))
    import yt_dlp
    from yt_dlp.networking.common import Response

    class SilentLogger:
        def debug(self, _): pass
        def warning(self, _): pass
        def error(self, _): pass

    class BoundedYoutubeDL(yt_dlp.YoutubeDL):
        def __init__(self):
            super().__init__({'quiet':True, 'no_warnings':True, 'logger':SilentLogger(),
                'proxy':'', 'noplaylist':True, 'skip_download':True, 'socket_timeout':12,
                'retries':0, 'extractor_retries':0, 'js_runtimes':{}, 'remote_components':[],
                'http_headers':{'User-Agent':'MediaFlowResearch/0.5.0 (Windows)'},
                'extractor_args':{'youtube':{'player_client':['web'],'player_skip':['js']}}})
            self.events = []
            self.stopped = None
        def urlopen(self, req):
            from urllib.parse import urlsplit
            uri = urlsplit(req.url)
            if self.stopped or len(self.events) >= 6:
                raise RuntimeError('Bounded operation stopped')
            if not any(uri.hostname == host or uri.hostname.endswith('.'+host)
                       for host in ['youtube.com','googlevideo.com','ytimg.com']):
                self.stopped = 'unsupportedUrl'
                raise RuntimeError('Unapproved origin')
            event = {'host':uri.hostname, 'path':uri.path, 'proxy':'DIRECT'}
            self.events.append(event)
            try:
                response = super().urlopen(req)
                event['status'] = response.status
                if uri.path.endswith('/player'):
                    body = response.read()
                    player = json.loads(body)
                    status = player.get('playabilityStatus', {})
                    event['playabilityStatus'] = status.get('status')
                    if status.get('status') != 'OK':
                        reason = status.get('reason','').lower()
                        self.stopped = 'securityChallenge' if 'bot' in reason or 'confirm' in reason else 'loginRequired' if status.get('status') == 'LOGIN_REQUIRED' else 'privateOrRestricted'
                        raise RuntimeError('Player denied; no alternate client allowed')
                    return Response(io.BytesIO(body),response.url,response.headers,status=response.status)
                return response
            except Exception as error:
                status = getattr(error,'status',None)
                event['errorType'] = type(error).__name__
                event['status'] = status or event.get('status')
                if not self.stopped:
                    self.stopped = 'resourceForbidden' if status == 403 else 'rateLimited' if status == 429 else 'networkFailure'
                raise

    results = []
    for video_id in ['jNQXAC9IVRw','aqz-KE-bpKQ']:
        with BoundedYoutubeDL() as client:
            result = {'repository':repo,'commit':meta['head'],'videoId':video_id,
                      'configuration':'WEB only; anonymous; no JS solver; no proxy; retries=0', 'events':client.events}
            try:
                data = client.extract_info('https://www.youtube.com/watch?v='+video_id,download=False)
                result['metadata'] = {key:data.get(key) for key in ['id','title','duration','channel']}
                result['formats'] = [{key:item.get(key) for key in ['format_id','ext','vcodec','acodec','width','height','tbr','protocol']}
                                     for item in data.get('formats',[])]
                result['status'] = 'METADATA/FORMATS OBTAINED; download NOT RUN'
            except Exception as error:
                result.update(status='RUN STOPPED',failure=client.stopped or 'unknown',errorType=type(error).__name__)
            results.append(result)
            (ROOT.parent / 'yt-dlp-real-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
            print(json.dumps({key:result.get(key) for key in ['videoId','status','failure']}))

if __name__ == '__main__':
    if sys.argv[1:] == ['--prepare']: prepare()
    elif sys.argv[1:] == ['--run']: run()
    else: raise SystemExit('Use --prepare or --run')
