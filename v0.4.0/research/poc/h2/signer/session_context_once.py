"""One authorized Cookie-subset variable around the frozen W2 dispatch body.

Does not change the signer, original runner, query, UA or timestamp strategy.
No credential values are printed or persisted in results.
"""
import argparse
import ast
import hashlib
import importlib.util
import json
import os
from pathlib import Path
from datetime import datetime, timezone
from types import SimpleNamespace


def main():
    parser = argparse.ArgumentParser()
    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument('--secret')
    input_group.add_argument('--environment-context', action='store_true')
    parser.add_argument('--metadata', required=True)
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    result_path = here / 'session-context-result.json'
    if result_path.exists():
        raise SystemExit('Operation already recorded; no request sent')
    secret_path = Path(args.secret).resolve() if args.secret else None
    if secret_path and secret_path != Path('D:/MediaFlow-secrets/douyin-h2-context.env').resolve():
        raise SystemExit('Secret path not admitted')
    snapshot = json.loads((here.parent / 'request-strategy-snapshot.json').read_text(encoding='utf-8'))
    for name, expected in snapshot['frozenFileHashes'].items():
        if hashlib.sha256((here.parent / name).read_bytes()).hexdigest() != expected:
            raise SystemExit('Frozen W2 evidence changed; no request sent')
    facts_path = here / 'runtime-facts.json'
    facts = json.loads(facts_path.read_text(encoding='utf-8-sig'))
    historic = json.loads((here / 'w2-result.json').read_text(encoding='utf-8'))
    if hashlib.sha256(facts_path.read_bytes()).hexdigest() != historic['runtimeFactsSha256']:
        raise SystemExit('Frozen runtime facts changed')
    entries = [json.loads(line) for line in Path(args.metadata).read_text(encoding='utf-8-sig').splitlines() if line.strip()]
    ready = [item['data'] for item in entries if item['kind'] == 'authorized_session_subset_ready']
    created = [item['data'] for item in entries if item['kind'] == 'profile_created']
    confirmed = [item['data'] for item in entries if item['kind'] == 'user_confirmation']
    if (len(ready) != 1 or len(created) != 1 or not confirmed
            or any(item['kind'] == 'finished' for item in entries)):
        raise SystemExit('Live authorized profile evidence not admitted')
    ready = ready[0]
    profile = Path(created[0]['profilePath'])
    if (not created[0]['appOwned'] or created[0]['importedState']
            or not profile.is_dir() or not (profile / 'mediaflow-owner.txt').is_file()
            or not confirmed[-1]['normalInteractionCompleted'] or not confirmed[-1]['loginCompleted']
            or ready['sourceType'] != 'app-owned-profile-cookie'
            or ready['actualUa'] != facts['userAgent'] or not ready['uaMatchesFrozenW2']
            or (secret_path and Path(ready['secretPath']).resolve() != secret_path)
            or (args.environment_context and ready.get('contextStorage') != 'child-process-environment')):
        raise SystemExit('Context source or frozen UA not admitted')
    cookies = {}
    input_lines = (secret_path.read_text(encoding='utf-8').splitlines() if secret_path else
                   [name + '=' + os.environ.pop('DOUYIN_' + name.upper()) for name in
                    ('sessionid', 'sessionid_ss', 'ttwid') if 'DOUYIN_' + name.upper() in os.environ])
    for line in input_lines:
        name, sep, value = line.partition('=')
        name = name.lower()
        if (not sep or name not in {'sessionid', 'sessionid_ss', 'ttwid'} or name in cookies
                or not value or len(value) > 16384
                or any(ord(c) < 33 or ord(c) > 126 or c == ';' for c in value)):
            raise SystemExit('Cookie subset input rejected (values redacted)')
        cookies[name] = value
    input_lines.clear()
    if ('ttwid' not in cookies or not ({'sessionid', 'sessionid_ss'} & cookies.keys())
            or set(cookies) != set(ready['cookieNames'])):
        raise SystemExit('Required normal session subset absent')
    for item in ready['cookies']:
        meta = item['metadata']
        if (not meta['present'] or meta['length'] != len(cookies[item['name']])
                or meta['domain'].lstrip('.') not in {'douyin.com', 'www.douyin.com'}
                or meta['path'] != '/' or (meta['expiry'] and
                datetime.fromisoformat(meta['expiry'].replace('Z', '+00:00')) <= datetime.now(timezone.utc))):
            raise SystemExit('Cookie metadata not admitted')
    cookie_header = '; '.join(name + '=' + cookies[name] for name in ('sessionid', 'sessionid_ss', 'ttwid') if name in cookies)
    # Exclusive durable operation budget. No retries, even on transport error.
    with result_path.open('x', encoding='utf-8') as stream:
        stream.write('{"outcome":"reserved","requestBudgetConsumed":0}\n')
    source = (here / 'web_detail_once.py').read_text(encoding='utf-8')
    tree = ast.parse(source)
    main_node = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'main')
    start = next(i for i, node in enumerate(main_node.body) if isinstance(node, ast.Assign)
                 and any(isinstance(target, ast.Name) and target.id == 'facts' for target in node.targets))
    dispatch_body = ast.Module(body=main_node.body[start:], type_ignores=[])
    spec = importlib.util.spec_from_file_location('frozen_w2', here / 'web_detail_once.py')
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    actual_request = runner.urllib.request.Request
    request_count = 0
    def attach_context(url, *, headers):
        nonlocal request_count
        if request_count or headers != {'User-Agent': facts['userAgent'], 'Accept': 'application/json',
                                       'Referer': 'https://www.douyin.com/note/7690029886242009957'}:
            raise ValueError('Frozen headers or request limit rejected')
        request_count += 1
        request = actual_request(url, headers=headers)
        request.add_header('Cookie', cookie_header)
        return request
    def enrich(value):
        record = json.loads(value)
        record.update(experiment='SESSION-CONTEXT-W2', accountCookiesSent=True, ttwidSent=True,
                      cookieNames=list(cookies), cookieMetadata=ready['cookies'],
                      sourceType=ready['sourceType'], contextAdmitted=True,
                      frozenRunnerSha256=hashlib.sha256(source.encode('utf-8')).hexdigest())
        if record.get('outcome') == 'http_response':
            record['classification'] = ('SCTX-2' if record.get('httpStatus') == 403 and record.get('uifidNotFound')
                else 'SCTX-3' if record.get('securityMarker') or record.get('errorClass') == 'unclassified-response'
                else 'SCTX-1')
            record['dataPathVerified'] = bool(record.get('businessJson') and record.get('imageCount', 0) > 0)
        return json.dumps(record, indent=2) + '\n'
    class EvidenceSink:
        def write_text(self, value, encoding):
            result_path.write_text(enrich(value), encoding=encoding)
    runner.urllib.request.Request = attach_context
    globals_scope = dict(vars(runner), args=SimpleNamespace(facts=str(facts_path), experiment='SESSION-CONTEXT-W2'),
                         result_path=EvidenceSink(), print=lambda value: print(enrich(value)))
    try:
        # Exact original statements after per-operation W1/W2 budget admission.
        # Only Request's Cookie addition and redacted result metadata are adapted.
        exec(compile(dispatch_body, str(here / 'web_detail_once.py'), 'exec'), globals_scope)
    except Exception as error:
        failure = {'outcome': 'harness_error', 'exceptionType': type(error).__name__,
                   'requestBudgetConsumed': request_count, 'noRetry': True}
        result_path.write_text(json.dumps(failure) + '\n', encoding='utf-8')
        print(json.dumps(failure))
    finally:
        runner.urllib.request.Request = actual_request
        cookies.clear()
        cookie_header = ''


if __name__ == '__main__':
    main()
