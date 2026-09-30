"""Offline source-shape audit; never imports third-party code or sends requests."""
import argparse
import ast
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cache', required=True)
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    manifest = json.loads((here / '../../douyin-gallery-horizontal-sources.json').read_text(encoding='utf-8-sig'))
    selected = {
        'DLWangSan/douyin_parse': ['douyin_video_parser.py'],
        'Johnserf-Seed/f2': ['f2/apps/douyin/model.py', 'f2/apps/douyin/crawler.py',
                            'f2/apps/douyin/utils.py', 'f2/apps/douyin/api.py', 'f2/conf/conf.yaml'],
        'ucmao/media-parser': ['src/parsers/douyin_parser.py'],
    }
    sources = {}
    provenance = []
    for repo in manifest['repositories']:
        name = repo['metadata']['repo']
        for source in repo['sources']:
            if source['path'] not in selected.get(name, []):
                continue
            file = Path(args.cache) / (name.replace('/', '--') + '--' + source['path'].replace('/', '__'))
            data = file.read_bytes()
            digest = hashlib.sha256(data).hexdigest()
            if digest != source['sha256']:
                raise SystemExit('Cached source hash mismatch; audit stopped')
            sources[(name, source['path'])] = data.decode('utf-8-sig')
            provenance.append({'repo': name, 'commit': repo['metadata']['sha'],
                               'path': source['path'], 'sha256': digest, 'url': source['url']})
    if len(provenance) != sum(map(len, selected.values())):
        raise SystemExit('Source coverage incomplete')
    f2_tree = ast.parse(sources[('Johnserf-Seed/f2', 'f2/apps/douyin/model.py')])
    classes = {node.name: node for node in f2_tree.body if isinstance(node, ast.ClassDef)}
    def fields(name):
        return [node.target.id for node in classes[name].body
                if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name)]
    f_keys = fields('BaseRequestModel') + fields('PostDetail')
    dl_tree = ast.parse(sources[('DLWangSan/douyin_parse', 'douyin_video_parser.py')])
    base = next(node.value for node in ast.walk(dl_tree)
                if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'BASE_PARAMS' for t in node.targets))
    d_keys = [ast.literal_eval(key) for key in base.keys] + ['aweme_id']
    assert 'uifid' not in f_keys and 'uifid' not in d_keys
    assert f_keys[:3] == d_keys[:3] == ['device_platform', 'aid', 'channel']
    assert 'msToken' in f_keys and 'msToken' not in d_keys
    assert 'verifyFp' not in f_keys and 'verifyFp' not in d_keys
    freeze_files = ['signer/research_signer.py', 'signer/vendor/f2_abogus.py',
                    'signer/web_detail_once.py', 'signer/w1-result.json', 'signer/w2-result.json',
                    'h2_contract.dart']
    result = {'scope': 'OFFLINE_SOURCE_SHAPES_NOT_PLATFORM_CAUSALITY',
              'platformRequestsThisTurn': 0, 'thirdPartyCodeExecuted': False,
              'sourceHashesVerified': len(provenance), 'sources': provenance,
              'M_orderedQueryKeysBeforeSignature': ['device_platform', 'aid', 'channel', 'aweme_id'],
              'F_declaredModelOrderBeforeSignature': f_keys,
              'D_orderedQueryKeysBeforeSignature': d_keys,
              'F_orderRuntimeVerified': False,
              'F_extraQueryKeys': [key for key in f_keys if key not in ['device_platform', 'aid', 'channel', 'aweme_id']],
              'D_extraQueryKeys': [key for key in d_keys if key not in ['device_platform', 'aid', 'channel', 'aweme_id']],
              'frozenFileHashes': {file: hashlib.sha256((here / file).read_bytes()).hexdigest() for file in freeze_files},
              'uniqueCausalDifferenceProven': False, 'sessionBindingProven': False}
    (here / 'request-strategy-snapshot.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'sourceHashesVerified': len(provenance), 'F_queryKeys': len(f_keys),
                      'D_queryKeys': len(d_keys), 'platformRequests': 0}))


if __name__ == '__main__':
    main()
