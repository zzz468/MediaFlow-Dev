"""Bounded W1/W2 research operations; no bootstrap/context harvesting."""
import argparse
import hashlib
import json
from pathlib import Path
import ssl
import time
import urllib.error
import urllib.request
from research_signer import LocalWebContext, ResearchSigner, WebDetailStrategy

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--facts', required=True)
    parser.add_argument('--result', required=True)
    parser.add_argument('--experiment', choices=['W1', 'W2'], default='W1')
    args = parser.parse_args()
    result_path = Path(args.result)
    expected = Path(__file__).resolve().parent / (args.experiment.lower() + '-result.json')
    if result_path.resolve() != expected:
        raise SystemExit('Only the fixed W1/W2 evidence paths are permitted')
    if args.experiment == 'W1' and expected.with_name('w2-result.json').exists():
        raise SystemExit('Two-operation experiment closed; no request sent')
    if args.experiment == 'W2':
        first = expected.with_name('w1-result.json')
        regression = expected.with_name('reader-regression.json')
        if not first.exists() or not regression.exists():
            raise SystemExit('W2 requires W1 and offline correction evidence')
        if json.loads(first.read_text(encoding='utf-8'))['outcome'] != 'transport_error':
            raise SystemExit('W2 correction applies only to the recorded transport failure')
    # Persist pre-dispatch budget. Re-running the same operation is refused,
    # even after a transport failure: do not retry to hit probability.
    if result_path.exists():
        raise SystemExit('Operation already recorded; no request sent')
    facts = json.loads(Path(args.facts).read_text(encoding='utf-8-sig'))
    if facts['platformNavigations'] != 0 or facts['source'] != 'offline-about-blank-runtime':
        raise SystemExit('Runtime facts origin rejected')
    target='7690029886242009957'
    context=LocalWebContext(facts['userAgent'],
        'https://www.douyin.com/note/'+target, tuple(facts['metrics']), facts['platform'])
    strategy=WebDetailStrategy()
    strategy.validate(context)
    query=ResearchSigner().sign(strategy.query(target),context)
    url='https://www.douyin.com/aweme/v1/web/aweme/detail/?'+query.encoded_query
    result={'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),
        'experiment':args.experiment,'requestBudgetConsumed':1,'maximumDetailRequests':1,
        'target':target,'signer':'attributed F2 algorithm; measured metrics; local SM3',
        'uifidSent':False,'ttwidSent':False,'accountCookiesSent':False,
        'msTokenSent':False,'xBogusSent':False,'secsdkSent':False,
        'deviceIdentityGenerated':False,'proxy':False,'redirects':False,
        'runtimeFactsSha256':hashlib.sha256(Path(args.facts).read_bytes()).hexdigest(),
        'outcome':'dispatch_pending'}
    result_path.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    request=urllib.request.Request(url,headers={'User-Agent':context.user_agent,
        'Accept':'application/json','Referer':context.referer})
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect(),
        urllib.request.HTTPSHandler(context=ssl.create_default_context()))
    started=time.monotonic()
    try:
        try:
            response=opener.open(request,timeout=15)
        except urllib.error.HTTPError as error:
            response=error
        with response:
            http_response = response.fp if isinstance(response, urllib.error.HTTPError) else response
            result.update(httpStatus=response.code,
                          contentType=response.headers.get_content_type(),
                          stage='response_headers_received')
            result_path.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
            transport_socket = http_response.fp.raw._sock
            chunks=[];size=0
            while True:
                if http_response.isclosed():break
                if time.monotonic()-started>25:
                    raise TimeoutError()
                transport_socket.settimeout(max(0.1, min(15, 25-(time.monotonic()-started))))
                chunk=response.read1(min(8192,2*1024*1024+1-size))
                if not chunk:break
                chunks.append(chunk);size+=len(chunk)
                if size>2*1024*1024:raise ValueError('body limit')
            body=b''.join(chunks).decode('utf-8',errors='replace')
            lower=body.lower()
            missing='uifid not found' in lower
            signature=any(v in lower for v in ('signature not found','signature invalid',
                                             'invalid signature','signature missing'))
            safety=any(v in lower for v in ('captcha','jschallenge','verifycenter','verify_center'))
            detail=None;business=False;gallery=0;aweme_type=None;image_post=False
            if response.code==200:
                try:
                    payload=json.loads(body)
                    if isinstance(payload,dict):
                        item=payload.get('aweme_detail')
                        if isinstance(item,dict):
                            detail=item
                            business=payload.get('status_code')==0 and str(item.get('aweme_id'))==target
                            if business:
                                aweme_type=item.get('aweme_type') if isinstance(item.get('aweme_type'),int) else None
                                post=item.get('image_post_info');image_post=isinstance(post,dict)
                                images=item.get('images')
                                if not isinstance(images,list) and image_post:images=post.get('images')
                                if isinstance(images,list):gallery=len(images)
                except (ValueError,TypeError):pass
            error_class=('uifid-gate' if missing else 'security-stop' if safety
                         else 'business-json' if business else 'signature-error' if signature
                         else 'unclassified-response')
            result.update(httpStatus=response.code,bodyBytes=size,
                contentType=response.headers.get_content_type(),uifidNotFound=missing,
                argusMarker='argussecurityplugin' in lower,explicitSignatureError=signature,
                securityMarker=safety,businessJson=business,detailPresent=detail is not None,
                targetMatch=business,awemeType=aweme_type,imagePostInfo=image_post,
                imageCount=gallery,errorClass=error_class,outcome='http_response',
                rawBodyLogged=False,signatureLogged=False,mediaDownloaded=False)
    except (OSError,ValueError,urllib.error.URLError) as error:
        # No exception messages/URL/body/signature are exposed.
        result.update(outcome='transport_error',exceptionType=type(error).__name__,
                      errno=getattr(error, 'errno', None))
    result_path.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result))

if __name__=='__main__':main()
