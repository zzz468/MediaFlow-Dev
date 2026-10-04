"""Isolated reference runs, never imported by Flutter. No user config/cookies.

Stop on denial BEFORE upstream automatic retries/fallbacks. Only platform-owned
hosts. Do not print credentials, response bodies, direct URLs or raw exceptions.
"""
import json
import sys
from pathlib import Path
from urllib.parse import urlsplit
from http.cookies import SimpleCookie

root = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(root / '.reference-runtime'))
events = []
class ControlledStop(BaseException):
    pass

def guard(url, status):
    host = urlsplit(str(url)).hostname or ''
    allowed = ('instagram.com', 'cdninstagram.com', 'fbcdn.net', 'x.com', 'twitter.com', 'twimg.com')
    if not any(host == h or host.endswith('.' + h) for h in allowed):
        raise ControlledStop('Non-platform request refused')
    if status is not None:
        events.append({'host': host, 'status': status})
        if status in (401, 403, 429) or '/accounts/login' in str(url) or '/challenge/' in str(url):
            raise ControlledStop(f'Platform response {status}; no retry/fallback')
    if len(events) >= 5:
        raise ControlledStop('Reference request budget reached')

import requests
original_send = requests.Session.send
def send(self, request, **kwargs):
    guard(request.url, None)
    cookie = SimpleCookie(request.headers.get('Cookie', ''))
    if any(k in cookie and cookie[k].value for k in ('sessionid', 'auth_token')):
        raise ControlledStop('Account cookie refused')
    kwargs['timeout'] = 15
    kwargs['allow_redirects'] = False
    response = original_send(self, request, **kwargs)
    guard(response.url, response.status_code)
    if 300 <= response.status_code < 400:
        raise ControlledStop('Redirect stopped; no upstream replay')
    return response
requests.Session.send = send

tool, url = sys.argv[1:3]
record = {'tool': tool, 'url':url, 'events':events, 'noExternalCookies':True, 'noAutomaticRetry':True}
try:
    if tool == 'yt-dlp':
        import yt_dlp
        from yt_dlp.version import __version__
        record['version'] = __version__
        class QuietLogger:
            def debug(self, *args): pass
            def warning(self, *args): pass
            def error(self, *args): pass
        with yt_dlp.YoutubeDL({'quiet':True,'logger':QuietLogger(),'skip_download':True,'socket_timeout':15,
                              'retries':0,'extractor_retries':0,'extractor_args':{'twitter':{'api':['syndication']}}}) as ydl:
            original_open = ydl.urlopen
            def urlopen(request):
                target = request.url if hasattr(request,'url') else str(request)
                guard(target,None)
                response=original_open(request)
                guard(response.url,response.status)
                return response
            ydl.urlopen=urlopen
            result=ydl.extract_info(url,download=False)
            record['metadataSucceeded']=bool(result)
            record['entryCount']=len(result.get('entries',[])) if result.get('_type')=='playlist' else 1
            record['formatCount']=len(result.get('formats',[]))
    elif tool == 'gallery-dl':
        import gallery_dl
        from gallery_dl import config, extractor, version
        record['version']=version.__version__
        config.clear()
        config.set(('extractor',), 'retries', 0)
        config.set(('extractor',), 'timeout', 15)
        config.set(('extractor','instagram'), 'api', 'graphql')
        extr=extractor.find(url)
        resources=[]
        for item in extr:
            if int(item[0]) == 3:
                resources.append(urlsplit(item[1]).hostname)
        record['resourceCount']=len(resources)
        record['resourceHosts']=resources
    elif tool == 'instaloader':
        import instaloader
        record['version']=instaloader.__version__
        loader=instaloader.Instaloader(max_connection_attempts=1,request_timeout=15,quiet=True)
        shortcode=urlsplit(url).path.strip('/').split('/')[-1]
        post=instaloader.Post.from_shortcode(loader.context,shortcode)
        record['metadataSucceeded']=bool(post.mediaid)
        record['typename']=post.typename
        record['resourceCount']=post.mediacount
    else:
        raise ValueError('Unknown tool')
except ControlledStop as e:
    record['result']='CONTROLLED STOP'
    record['reason']=str(e)
except Exception as e:
    record['result']='REFERENCE RUN FAILED'
    record['exceptionType']=type(e).__name__
record.setdefault('result','REFERENCE RUN COMPLETED')
out=root / 'evidence' / f'reference-{tool}-{urlsplit(url).path.strip("/").split("/")[-1]}.json'
out.write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(record,ensure_ascii=False,indent=2))
