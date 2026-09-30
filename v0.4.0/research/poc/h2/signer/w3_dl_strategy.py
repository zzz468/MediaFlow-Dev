"""Bounded DL-style strategy A/B using the unchanged research signer/transport."""
import argparse
import ast
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
from types import SimpleNamespace
from urllib.parse import urlencode

HERE = Path(__file__).resolve().parent
TARGET = '7690029886242009957'
ENDPOINT = 'https://www.douyin.com/aweme/v1/web/aweme/detail/'


def strategy():
    workspace = HERE.parents[4]
    source_dir = workspace / 'build/w3-source'
    metadata = json.loads((source_dir / 'source-metadata.json').read_text(encoding='utf-8-sig'))
    data = (source_dir / 'douyin_video_parser.py').read_bytes()
    if hashlib.sha256(data).hexdigest() != metadata['sha256']:
        raise SystemExit('Reference source hash mismatch')
    tree = ast.parse(data.decode('utf-8-sig'))
    cls = next(node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == 'DouyinVideoParser')
    params = next(ast.literal_eval(node.value) for node in cls.body if isinstance(node, ast.Assign)
                  and any(isinstance(target, ast.Name) and target.id == 'BASE_PARAMS' for target in node.targets))
    facts = json.loads((HERE / 'runtime-facts.json').read_text(encoding='utf-8-sig'))
    # Preserve the source shape without adopting invented screen dimensions.
    params['screen_width'] = str(facts['metrics'][8])
    params['screen_height'] = str(facts['metrics'][9])
    params['aweme_id'] = TARGET
    method = next(node for node in cls.body if isinstance(node, ast.FunctionDef) and node.name == '_build_headers')
    literal = next(node.value for node in method.body if isinstance(node, ast.Assign)
                   and any(isinstance(target, ast.Name) and target.id == 'headers' for target in node.targets))
    headers = {ast.literal_eval(key): ast.literal_eval(value) for key, value in zip(literal.keys, literal.values)
               if isinstance(value, ast.Constant)}
    headers.update({'User-Agent': facts['userAgent'], 'Referer': 'https://www.douyin.com/note/' + TARGET})
    assert len(params) == 18 and len(headers) == 8
    assert not {'msToken', 'uifid', 'verifyFp'} & params.keys()
    assert headers['Origin'] == 'https://www.douyin.com'
    assert urlencode(params) == urlencode(tuple(params.items()))
    snapshot = json.loads((HERE.parent / 'request-strategy-snapshot.json').read_text(encoding='utf-8'))
    for name, expected in snapshot['frozenFileHashes'].items():
        if hashlib.sha256((HERE.parent / name).read_bytes()).hexdigest() != expected:
            raise SystemExit('Frozen signer/runner evidence changed')
    return metadata, facts, params, headers


def admit(metadata_path, facts):
    entries = [json.loads(line) for line in Path(metadata_path).read_text(encoding='utf-8-sig').splitlines() if line.strip()]
    ready = [entry['data'] for entry in entries if entry['kind'] == 'authorized_session_subset_ready']
    created = [entry['data'] for entry in entries if entry['kind'] == 'profile_created']
    confirms = [entry['data'] for entry in entries if entry['kind'] == 'user_confirmation']
    if (len(ready) != 1 or len(created) != 1 or not confirms or any(entry['kind'] == 'finished' for entry in entries)):
        raise SystemExit('Live session source not admitted')
    ready = ready[0]
    if (not created[0]['appOwned'] or created[0]['importedState'] or not Path(created[0]['profilePath']).is_dir()
            or not confirms[-1]['normalInteractionCompleted'] or not confirms[-1]['loginCompleted']
            or ready['actualUa'] != facts['userAgent'] or not ready['uaMatchesFrozenW2']
            or ready.get('contextStorage') != 'child-process-environment'):
        raise SystemExit('Normal context or UA not admitted')
    cookies = {}
    for name in ('sessionid', 'sessionid_ss', 'ttwid'):
        value = os.environ.pop('DOUYIN_' + name.upper(), None)
        if value is None:
            continue
        if not value or len(value) > 16384 or any(ord(c) < 33 or ord(c) > 126 or c == ';' for c in value):
            raise SystemExit('Context value rejected (redacted)')
        cookies[name] = value
    if ('ttwid' not in cookies or not {'sessionid', 'sessionid_ss'} & cookies.keys()
            or set(cookies) != set(ready['cookieNames'])):
        raise SystemExit('Session subset absent or ambiguous')
    for item in ready['cookies']:
        meta = item['metadata']
        if (meta['length'] != len(cookies[item['name']]) or meta['domain'].lstrip('.') not in {'douyin.com', 'www.douyin.com'}
                or meta['path'] != '/' or (meta['expiry'] and datetime.fromisoformat(meta['expiry'].replace('Z', '+00:00'))
                                          <= datetime.now(timezone.utc))):
            raise SystemExit('Session metadata not admitted')
    return cookies, ready['cookies']


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--experiment', choices=['W3-A', 'W3-B'], required=True)
    parser.add_argument('--metadata')
    parser.add_argument('--preflight', action='store_true')
    args = parser.parse_args()
    source_meta, facts, params, headers = strategy()
    if args.preflight:
        # No credentials or signature are present in this shape record.
        record = {'source': source_meta, 'endpoint': ENDPOINT, 'target': TARGET,
                  'orderedQuery': list(params.items()), 'headers': headers,
                  'aBogusPlacement': 'last query; percent encoded once',
                  'measuredScreenSubstitution': True, 'platformRequests': 0}
        (HERE / 'w3-shape.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(record, ensure_ascii=False))
        return
    output = HERE / (args.experiment.lower() + '-result.json')
    if output.exists():
        raise SystemExit('Operation already recorded; no request sent')
    cookies = {}
    cookie_meta = []
    if args.experiment == 'W3-B':
        first = json.loads((HERE / 'w3-a-result.json').read_text(encoding='utf-8'))
        if (first.get('httpStatus') == 200 or not (first.get('uifidNotFound') or first.get('securityMarker'))
                or first.get('explicitSignatureError') or not args.metadata):
            raise SystemExit('W3-B not authorized by W3-A outcome')
        cookies, cookie_meta = admit(args.metadata, facts)
    elif (HERE / 'w3-b-result.json').exists():
        raise SystemExit('W3 experiment closed')
    with output.open('x', encoding='utf-8') as stream:
        stream.write('{"outcome":"reserved","requestBudgetConsumed":0}\n')
    spec = importlib.util.spec_from_file_location('frozen_w2_transport', HERE / 'web_detail_once.py')
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    class DLStrategy(runner.WebDetailStrategy):
        def query(self, target):
            if target != TARGET:
                raise ValueError('Unexpected target')
            return tuple(params.items())
    # All query values are ASCII with no spaces: DL urlencode and current
    # signer's percent encoder produce identical bytes for this experiment.
    assert runner.ResearchSigner.required_capabilities == frozenset({'userAgent', 'measuredBrowserMetrics'})
    actual_request = runner.urllib.request.Request
    request_count = 0
    def make_request(url, *, headers):
        nonlocal request_count
        if request_count or not url.startswith(ENDPOINT + '?'):
            raise ValueError('Request quota or endpoint rejected')
        request_count += 1
        request = actual_request(url, headers=strategy_headers)
        if cookies:
            request.add_header('Cookie', '; '.join(name + '=' + cookies[name] for name in ('sessionid', 'sessionid_ss', 'ttwid') if name in cookies))
        return request
    strategy_headers = dict(headers)
    def enrich(text):
        record = json.loads(text)
        record.update(experiment=args.experiment, ttwidSent=bool(cookies), accountCookiesSent=bool(cookies),
                      cookieNames=list(cookies), cookieMetadata=cookie_meta, strategy='DL-style; actual UA/screen',
                      sourceCommit=source_meta['commit'], strategyLevelAB=True)
        if record.get('outcome') == 'http_response':
            record['classification'] = ('W3-2' if record.get('uifidNotFound') else
                'W3-3' if record.get('explicitSignatureError') else
                'W3-4' if record.get('businessJson') else 'OTHER-RESPONSE')
            record['dataPathVerified'] = bool(record.get('businessJson') and record.get('imageCount', 0) > 0)
        return json.dumps(record, indent=2) + '\n'
    class Sink:
        def write_text(self, text, encoding):
            output.write_text(enrich(text), encoding=encoding)
    tree = ast.parse((HERE / 'web_detail_once.py').read_text(encoding='utf-8'))
    original_main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'main')
    start = next(i for i, node in enumerate(original_main.body) if isinstance(node, ast.Assign)
                 and any(isinstance(target, ast.Name) and target.id == 'facts' for target in node.targets))
    scope = dict(vars(runner), WebDetailStrategy=DLStrategy,
                 args=SimpleNamespace(facts=str(HERE / 'runtime-facts.json'), experiment=args.experiment),
                 result_path=Sink(), print=lambda text: None)
    runner.urllib.request.Request = make_request
    try:
        exec(compile(ast.Module(body=original_main.body[start:], type_ignores=[]), 'frozen_w2_dispatch', 'exec'), scope)
        record = json.loads(output.read_text(encoding='utf-8'))
        # Only a strict non-sensitive server-error vocabulary may be retained.
        body = scope.get('body', '').strip()
        if body in {'Blocked by ArgusSecurityPlugin Uifid Not Found', 'ArgusSecurityPlugin Uifid Not Found',
                    'Signature Not Found', 'Signature Invalid', 'Invalid signature', 'A-Bogus rejected'}:
            record['safeErrorText'] = body
        if 'abogus' in body.lower() or 'a-bogus' in body.lower():
            record['aBogusErrorMarker'] = True
        output.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(record))
    except Exception as error:
        record = {'outcome': 'harness_error', 'exceptionType': type(error).__name__,
                  'requestBudgetConsumed': request_count, 'noRetry': True}
        output.write_text(json.dumps(record) + '\n', encoding='utf-8')
        print(json.dumps(record))
    finally:
        runner.urllib.request.Request = actual_request
        cookies.clear()


if __name__ == '__main__':
    main()
