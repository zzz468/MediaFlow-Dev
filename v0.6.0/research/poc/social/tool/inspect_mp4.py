"""Container/track inspection only; does not claim decoded video/playback."""
import json
import struct
import sys
from pathlib import Path
def boxes(data, start, end):
    while start + 8 <= end:
        size, kind = struct.unpack_from('>I4s', data, start)
        header = 8
        if size == 1:
            size = struct.unpack_from('>Q', data, start + 8)[0]
            header = 16
        elif size == 0:
            size = end - start
        if size < header or start + size > end:
            raise ValueError('Truncated/invalid MP4 box')
        yield kind, start + header, start + size
        start += size
    if start != end:
        raise ValueError('Trailing incomplete box')
def inspect(path):
    data = path.read_bytes()
    kinds = []
    tracks = []
    def walk(start, end):
        for kind, payload, stop in boxes(data, start, end):
            if start == 0:
                kinds.append(kind.decode('ascii'))
            if kind in (b'moov', b'trak', b'mdia'):
                walk(payload, stop)
            elif kind == b'hdlr':
                tracks.append(data[payload+8:payload+12].decode('ascii'))
    walk(0, len(data))
    return {'file':path.name, 'bytes':len(data), 'topLevelBoxes':kinds, 'trackHandlers':tracks,
            'hasVideoTrack':'vide' in tracks, 'hasAudioTrack':'soun' in tracks,
            'containerStructure': 'PASS' if {'ftyp','moov','mdat'}.issubset(kinds) else 'FAIL',
            'systemPlayback':'USER VALIDATION PENDING'}
root=Path(sys.argv[1])
records=[inspect(p) for p in root.glob('*.mp4')]
out=root.parent / 'windows-mp4-containers.json'
out.write_text(json.dumps(records,indent=2),encoding='utf-8')
print(json.dumps(records,indent=2))
