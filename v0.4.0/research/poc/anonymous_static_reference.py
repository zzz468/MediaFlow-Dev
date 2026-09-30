"""Bounded reference SSR experiment; never imports/initializes its full parser.

Loads unchanged methods from the user's separately downloaded MIT reference.
No signer, web detail, cookie bootstrap, browser, retry, or media download.
"""
import argparse
import ast
import copy
import hashlib
import json
import logging
import re
import time
import urllib.parse
from pathlib import Path
from types import SimpleNamespace

import requests
from bs4 import BeautifulSoup


class AnonymousTransport:
    def __init__(self):
        self.events = []

    def get(self, url, headers, timeout, verify):
        # Original fetch method adds an empty Cookie after credentials are disabled.
        headers = dict(headers)
        assert not headers.pop('Cookie', '')
        assert not any(k.lower() in ('cookie', 'authorization', 'uifid') for k in headers)
        started = time.monotonic()
        for _ in range(3):
            parsed = urllib.parse.urlparse(url)
            assert parsed.scheme == 'https' and parsed.hostname in (
                'www.iesdouyin.com', 'www.douyin.com')
            assert re.fullmatch(r'/(?:share/)?(?:video|note)/\d+/?', parsed.path)
            remaining = 6 - (time.monotonic() - started)
            if remaining <= 0:
                raise TimeoutError('budgetExceeded')
            # A new session per redirect: returned cookies cannot be sent onward.
            with requests.Session() as session:
                session.trust_env = False
                with session.get(url, headers=headers, timeout=min(timeout, remaining),
                                 verify=True, allow_redirects=False, stream=True) as response:
                    assert 'Cookie' not in response.request.headers
                    self.events.append({'status': response.status_code, 'host': parsed.hostname,
                                        'path': parsed.path, 'cookieSent': False})
                    if response.status_code in (301, 302, 303, 307, 308):
                        url = urllib.parse.urljoin(url, response.headers['Location'])
                        continue
                    raw = bytearray()
                    for chunk in response.iter_content(16384):
                        raw.extend(chunk)
                        if len(raw) > 1024 * 1024 or time.monotonic() - started > 6:
                            raise TimeoutError('sizeOrTimeBudgetExceeded')
                    text = raw.decode('utf-8', errors='replace')
                    self.events[-1]['bytes'] = len(raw)
                    return SimpleNamespace(status_code=response.status_code, text=text)
        raise RuntimeError('redirectBudgetExceeded')


def load_reference(root):
    path = root / 'src/parsers/douyin_parser.py'
    tree = ast.parse(path.read_text(encoding='utf-8'))
    cls = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == 'DouyinParser')
    names = {'fetch_html_content', '_try_share_ssr_detail', '_parse_ssr_data',
             '_find_aweme_detail', '_extract_json_object_after', 'get_image_list',
             '_build_play_endpoint_url', '_extract_best_url_from_play_addr'}
    methods = [n for n in cls.body if isinstance(n, ast.FunctionDef) and n.name in names]
    assert {n.name for n in methods} == names
    reduced = ast.Module(body=[ast.ClassDef(name='ReferenceSSR', bases=[], keywords=[],
                                         body=methods, decorator_list=[])], type_ignores=[])
    namespace = dict(copy=copy, json=json, re=re, urllib=urllib,
                     BeautifulSoup=BeautifulSoup, logger=logging.getLogger('reference'))
    exec(compile(ast.fix_missing_locations(reduced), str(path), 'exec'), namespace)
    # Original static methods recurse via the original class name.
    namespace['DouyinParser'] = namespace['ReferenceSSR']
    # Preserve original initial HTTP headers without creating/running a signer.
    init = next(n for n in cls.body if isinstance(n, ast.FunctionDef) and n.name == '__init__')
    header_expr = next(n.value for n in init.body if isinstance(n, ast.Assign)
                       and any(isinstance(t, ast.Attribute) and t.attr == 'headers' for t in n.targets))
    dummy = SimpleNamespace(signer=SimpleNamespace(user_agent='overridden by original mobile UA'))
    headers = eval(compile(ast.Expression(header_expr), str(path), 'eval'), {'self': dummy})
    return namespace['ReferenceSSR'], headers, hashlib.sha256(path.read_bytes()).hexdigest()


def run(root, output):
    cls, headers, source_hash = load_reference(root)
    logging.disable(logging.CRITICAL)  # Original logs may contain full URLs/error text.
    samples = [
        ('7690029886242009957', 'human-confirmed; prior session 13 images', 13),
        ('7669579412325683877', 'reference images-only fixture; current human count unknown', None),
        ('7675010865947858341', 'reference images-only fixture; current human count unknown', None),
        ('7626598460468333858', 'historical public 10-image reference; current status unknown', None),
        ('7159749791113645325', 'historical public image-post reference; current status unknown', None),
    ]
    rows = []
    for target, evidence, count in samples:
        parser = cls()
        parser.real_url = f'https://www.douyin.com/note/{target}'
        parser.aweme_id = target
        parser.is_note = True
        parser.is_music = parser.is_collection = parser.is_lvdetail = False
        parser.headers = headers
        parser.html_content = None
        parser.session = AnonymousTransport()
        parser._get_ttwid = lambda: None
        parser._get_cookie_header = lambda _ttwid: ''
        parser._get_uifid = lambda: None
        started = time.monotonic()
        parser.data = parser._try_share_ssr_detail()
        detail = (parser.data or {}).get('aweme_detail') or {}
        urls = parser.get_image_list()
        target_match = str(detail.get('aweme_id') or detail.get('id')) == target
        live = any(isinstance(u, dict) for u in urls)
        image_items = detail.get('images') or (detail.get('image_post_info') or {}).get('images') or []
        live = live or bool(detail.get('live_photo_type')) or any(
            isinstance(i, dict) and (i.get('video') or i.get('live_photo_type') or
                                    i.get('video_play_addr') or i.get('video_download_addr')) for i in image_items)
        distinct = len(set(u for u in urls if isinstance(u, str)))
        passed = target_match and len(urls) >= 2 and distinct == len(urls) and not live
        row = {'id': target, 'sampleEvidence': evidence, 'priorSessionImageCount': count,
               'status': 'success' if passed else 'notApplicable' if live else 'blocked',
               'category': 'staticGallery' if passed else 'livePhotoExcluded' if live else
                           'noTargetStructuredDetail' if not detail else 'invalidTargetOrImages',
               'targetMatch': target_match, 'imageCount': len(urls), 'distinctImages': distinct,
               'order': 'reference array order' if passed else 'notVerified',
               'latencyMs': round((time.monotonic() - started) * 1000),
               'requests': parser.session.events}
        rows.append(row)
        print(json.dumps(row, ensure_ascii=True), flush=True)
    result = {'referenceCommit': 'ee05d757c7feb657dcdb1582ec1ac4d0e24d38c6',
              'sourceSHA256': source_hash, 'credentialsSent': False,
              'originalSSRMethodsUnchanged': True, 'fullDefaultParserExecuted': False,
              'samples': rows}
    output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


if __name__ == '__main__':
    args = argparse.ArgumentParser()
    args.add_argument('reference_root', type=Path)
    args.add_argument('output', type=Path)
    opts = args.parse_args()
    run(opts.reference_root, opts.output)
