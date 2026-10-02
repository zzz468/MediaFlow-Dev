"""Read only this independent research app; preserve UTF-8 and binary bytes."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent
ADB = r'D:\Android\Sdk\platform-tools\adb.exe'
PACKAGE = 'com.mediaflow.research.v050.feasibility'
for source, target in [('results.json','android-latest-results.json'),
                       ('diagnostic.json','android-page-diagnostic.json'),
                       ('mobile-schema-results.json','android-mobile-schema-results.json'),
                       ('media-url-results.json','android-media-url-results.json')]:
    result = subprocess.run([ADB,'exec-out','run-as',PACKAGE,'cat','files/'+source],capture_output=True,check=True)
    data = json.loads(result.stdout.decode('utf-8'))
    (ROOT / target).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
for name in ['xhs-gallery-8-1.jpg','xhs-gallery-8-2.jpg']:
    result = subprocess.run([ADB,'exec-out','run-as',PACKAGE,'cat','files/downloads/'+name],capture_output=True,check=True)
    destination = ROOT / 'downloads' / 'android' / name
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_bytes(result.stdout)
print('Captured own-app evidence and two image files without transcoding.')
