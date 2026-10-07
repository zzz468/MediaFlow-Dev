# YouTube quality candidate audit — 2026-10-06

Current production Parser only; no library, signer, browser, transcoding or ProcessingEngine changes. URLs remain in memory only. HTTP 206 proves the bounded range request succeeded; 302 records an un-followed redirect and does not prove download failure. Missing direct URL is not a claim that no format exists on the platform.

## hLY9KMIU2BA

Old UI default: `youtube:ANDROID_SDKLESS:18`.

| Profile | itag | Resolution | Size | fps | bitrate bps | MIME / codec | Role | Direct URL | HTTP | Parser retention | Reason | Production mux |
|---|---:|---|---|---:|---:|---|---|---|---|---|---|---|
| WEB | 313 | 2160p | 3240×2160 | 24 | 15048162 | video/webm; codecs="vp9" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 401 | 2160p | 3240×2160 | 24 | 10902984 | video/mp4; codecs="av01.0.12M.08" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 271 | 1440p | 2160×1440 | 24 | 7389053 | video/webm; codecs="vp9" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 400 | 1440p | 2160×1440 | 24 | 5397612 | video/mp4; codecs="av01.0.12M.08" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 137 | 1080p | 1620×1080 | 24 | 3626311 | video/mp4; codecs="avc1.640028" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 248 | 1080p | 1620×1080 | 24 | 2292362 | video/webm; codecs="vp9" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 399 | 1080p | 1620×1080 | 24 | 1794568 | video/mp4; codecs="av01.0.08M.08" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 136 | 720p | 1080×720 | 24 | 1229216 | video/mp4; codecs="avc1.4d401f" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 247 | 720p | 1080×720 | 24 | 1294425 | video/webm; codecs="vp9" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 398 | 720p | 1080×720 | 24 | 1039488 | video/mp4; codecs="av01.0.05M.08" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 779 | 480p | 912×608 | 24 | 434301 | video/webm; codecs="vp9" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 780 | 480p | 912×608 | 24 | 742491 | video/webm; codecs="vp9" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 787 | 480p | 912×608 | 24 | 267822 | video/mp4; codecs="av01.0.04M.08" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 788 | 480p | 912×608 | 24 | 567142 | video/mp4; codecs="av01.0.04M.08" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 135 | 480p | 720×480 | 24 | 898387 | video/mp4; codecs="avc1.4d401e" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 244 | 480p | 720×480 | 24 | 743264 | video/webm; codecs="vp9" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 134 | 360p | 540×360 | 24 | 532633 | video/mp4; codecs="avc1.4d4015" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 243 | 360p | 540×360 | 24 | 201998 | video/webm; codecs="vp9" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 396 | 360p | 540×360 | 24 | 277577 | video/mp4; codecs="av01.0.01M.08" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 133 | 240p | 360×240 | 24 | 208546 | video/mp4; codecs="avc1.4d400d" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 242 | 240p | 360×240 | 24 | 95095 | video/webm; codecs="vp9" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 395 | 240p | 360×240 | 24 | 90246 | video/mp4; codecs="av01.0.00M.08" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 160 | 144p | 216×144 | 24 | 95652 | video/mp4; codecs="avc1.4d400c" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 278 | 144p | 216×144 | 24 | 75825 | video/webm; codecs="vp9" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 140 |  | × |  | 130363 | audio/mp4; codecs="mp4a.40.2" | audioOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 249 |  | × |  | 49911 | audio/webm; codecs="opus" | audioOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 250 |  | × |  | 66498 | audio/webm; codecs="opus" | audioOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 251 |  | × |  | 127224 | audio/webm; codecs="opus" | audioOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| ANDROID_SDKLESS | 18 | 360p | 640×426 | 24 | 677256 | video/mp4; codecs="avc1.42001E, mp4a.40.2" | progressive | True | 206 | True | retained | n/a |
| ANDROID_SDKLESS | 313 | 2160p | 3240×2160 | 24 | 15048162 | video/webm; codecs="vp9" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 401 | 2160p | 3240×2160 | 24 | 10902984 | video/mp4; codecs="av01.0.12M.08" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 271 | 1440p | 2160×1440 | 24 | 7389053 | video/webm; codecs="vp9" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 400 | 1440p | 2160×1440 | 24 | 5397612 | video/mp4; codecs="av01.0.12M.08" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 137 | 1080p | 1620×1080 | 24 | 3626311 | video/mp4; codecs="avc1.640028" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 248 | 1080p | 1620×1080 | 24 | 2292362 | video/webm; codecs="vp9" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 399 | 1080p | 1620×1080 | 24 | 1794568 | video/mp4; codecs="av01.0.08M.08" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 136 | 720p | 1080×720 | 24 | 1229216 | video/mp4; codecs="avc1.4d401f" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 247 | 720p | 1080×720 | 24 | 1294425 | video/webm; codecs="vp9" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 398 | 720p | 1080×720 | 24 | 1039488 | video/mp4; codecs="av01.0.05M.08" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 779 | 480p | 912×608 | 24 | 434301 | video/webm; codecs="vp9" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 780 | 480p | 912×608 | 24 | 742491 | video/webm; codecs="vp9" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 787 | 480p | 912×608 | 24 | 267822 | video/mp4; codecs="av01.0.04M.08" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 788 | 480p | 912×608 | 24 | 567142 | video/mp4; codecs="av01.0.04M.08" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 135 | 480p | 720×480 | 24 | 898387 | video/mp4; codecs="avc1.4d401e" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 244 | 480p | 720×480 | 24 | 743264 | video/webm; codecs="vp9" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 134 | 360p | 540×360 | 24 | 532633 | video/mp4; codecs="avc1.4d4015" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 243 | 360p | 540×360 | 24 | 201998 | video/webm; codecs="vp9" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 396 | 360p | 540×360 | 24 | 277577 | video/mp4; codecs="av01.0.01M.08" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 133 | 240p | 360×240 | 24 | 208546 | video/mp4; codecs="avc1.4d400d" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 242 | 240p | 360×240 | 24 | 95095 | video/webm; codecs="vp9" | videoOnly | True | 302 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 395 | 240p | 360×240 | 24 | 90246 | video/mp4; codecs="av01.0.00M.08" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 160 | 144p | 216×144 | 24 | 95652 | video/mp4; codecs="avc1.4d400c" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 278 | 144p | 216×144 | 24 | 75825 | video/webm; codecs="vp9" | videoOnly | True | TimeoutException | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 139 |  | × |  | 49926 | audio/mp4; codecs="mp4a.40.5" | audioOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 140 |  | × |  | 130363 | audio/mp4; codecs="mp4a.40.2" | audioOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 249 |  | × |  | 49911 | audio/webm; codecs="opus" | audioOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 251 |  | × |  | 127224 | audio/webm; codecs="opus" | audioOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| VISIONOS | 313 | 2160p | 3240×2160 | 24 | 15048162 | video/webm; codecs="vp9" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 401 | 2160p | 3240×2160 | 24 | 10902984 | video/mp4; codecs="av01.0.12M.08" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 271 | 1440p | 2160×1440 | 24 | 7389053 | video/webm; codecs="vp9" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 400 | 1440p | 2160×1440 | 24 | 5397612 | video/mp4; codecs="av01.0.12M.08" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 137 | 1080p | 1620×1080 | 24 | 3626311 | video/mp4; codecs="avc1.640028" | videoOnly | True | 206 | True | retained | yes |
| VISIONOS | 248 | 1080p | 1620×1080 | 24 | 2292362 | video/webm; codecs="vp9" | videoOnly | True | 302 | True | retained | unsupported codec/container |
| VISIONOS | 399 | 1080p | 1620×1080 | 24 | 1794568 | video/mp4; codecs="av01.0.08M.08" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 136 | 720p | 1080×720 | 24 | 1229216 | video/mp4; codecs="avc1.4d401f" | videoOnly | True | 206 | True | retained | yes |
| VISIONOS | 247 | 720p | 1080×720 | 24 | 1294425 | video/webm; codecs="vp9" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 398 | 720p | 1080×720 | 24 | 1039488 | video/mp4; codecs="av01.0.05M.08" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 779 | 480p | 912×608 | 24 | 434301 | video/webm; codecs="vp9" | videoOnly | True | 206 | False | deduplicated or parse did not complete | n/a |
| VISIONOS | 780 | 480p | 912×608 | 24 | 742491 | video/webm; codecs="vp9" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 787 | 480p | 912×608 | 24 | 267822 | video/mp4; codecs="av01.0.04M.08" | videoOnly | True | 206 | False | deduplicated or parse did not complete | n/a |
| VISIONOS | 788 | 480p | 912×608 | 24 | 567142 | video/mp4; codecs="av01.0.04M.08" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 135 | 480p | 720×480 | 24 | 898387 | video/mp4; codecs="avc1.4d401e" | videoOnly | True | 206 | True | retained | yes |
| VISIONOS | 244 | 480p | 720×480 | 24 | 743264 | video/webm; codecs="vp9" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 134 | 360p | 540×360 | 24 | 532633 | video/mp4; codecs="avc1.4d4015" | videoOnly | True | 206 | True | retained | yes |
| VISIONOS | 243 | 360p | 540×360 | 24 | 201998 | video/webm; codecs="vp9" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 396 | 360p | 540×360 | 24 | 277577 | video/mp4; codecs="av01.0.01M.08" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 133 | 240p | 360×240 | 24 | 208546 | video/mp4; codecs="avc1.4d400d" | videoOnly | True | 206 | True | retained | yes |
| VISIONOS | 242 | 240p | 360×240 | 24 | 95095 | video/webm; codecs="vp9" | videoOnly | True | 302 | True | retained | unsupported codec/container |
| VISIONOS | 395 | 240p | 360×240 | 24 | 90246 | video/mp4; codecs="av01.0.00M.08" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 160 | 144p | 216×144 | 24 | 95652 | video/mp4; codecs="avc1.4d400c" | videoOnly | True | 206 | True | retained | yes |
| VISIONOS | 278 | 144p | 216×144 | 24 | 75825 | video/webm; codecs="vp9" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 139 |  | × |  | 49926 | audio/mp4; codecs="mp4a.40.5" | audioOnly | True | 206 | True | retained | n/a |
| VISIONOS | 140 |  | × |  | 130363 | audio/mp4; codecs="mp4a.40.2" | audioOnly | True | 206 | True | retained | n/a |
| VISIONOS | 249 |  | × |  | 49911 | audio/webm; codecs="opus" | audioOnly | True | 206 | True | retained | n/a |
| VISIONOS | 250 |  | × |  | 66498 | audio/webm; codecs="opus" | audioOnly | True | 206 | True | retained | n/a |
| VISIONOS | 251 |  | × |  | 127224 | audio/webm; codecs="opus" | audioOnly | True | 206 | True | retained | n/a |

## jNQXAC9IVRw

Old UI default: `youtube:ANDROID_SDKLESS:18`.

| Profile | itag | Resolution | Size | fps | bitrate bps | MIME / codec | Role | Direct URL | HTTP | Parser retention | Reason | Production mux |
|---|---:|---|---|---:|---:|---|---|---|---|---|---|---|
| WEB | 133 | 240p | 320×240 | 15 | 183848 | video/mp4; codecs="avc1.4d400c" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 134 | 240p | 320×240 | 15 | 150749 | video/mp4; codecs="avc1.4d400c" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 242 | 240p | 320×240 | 15 | 139537 | video/webm; codecs="vp9" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 395 | 240p | 320×240 | 15 | 105337 | video/mp4; codecs="av01.0.00M.08.0.110.05.01.06.0" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 160 | 144p | 192×144 | 15 | 83327 | video/mp4; codecs="avc1.4d400b" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 278 | 144p | 192×144 | 15 | 81831 | video/webm; codecs="vp9" | videoOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 140 |  | × |  | 130171 | audio/mp4; codecs="mp4a.40.2" | audioOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 140 |  | × |  | 130072 | audio/mp4; codecs="mp4a.40.2" | audioOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 249 |  | × |  | 48248 | audio/webm; codecs="opus" | audioOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 249 |  | × |  | 50981 | audio/webm; codecs="opus" | audioOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 250 |  | × |  | 61101 | audio/webm; codecs="opus" | audioOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 250 |  | × |  | 64072 | audio/webm; codecs="opus" | audioOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 251 |  | × |  | 106944 | audio/webm; codecs="opus" | audioOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| WEB | 251 |  | × |  | 108013 | audio/webm; codecs="opus" | audioOnly | False |  | False | no direct URL (cipher/URL-less) | n/a |
| ANDROID_SDKLESS | 18 | 240p | 320×240 | 15 | 266531 | video/mp4; codecs="avc1.42001E, mp4a.40.2" | progressive | True | 206 | True | retained | n/a |
| ANDROID_SDKLESS | 133 | 240p | 320×240 | 15 | 183848 | video/mp4; codecs="avc1.4d400c" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 134 | 240p | 320×240 | 15 | 150749 | video/mp4; codecs="avc1.4d400c" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 242 | 240p | 320×240 | 15 | 139537 | video/webm; codecs="vp9" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 395 | 240p | 320×240 | 15 | 105337 | video/mp4; codecs="av01.0.00M.08.0.110.05.01.06.0" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 160 | 144p | 192×144 | 15 | 83327 | video/mp4; codecs="avc1.4d400b" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 278 | 144p | 192×144 | 15 | 81831 | video/webm; codecs="vp9" | videoOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 139 |  | × |  | 49594 | audio/mp4; codecs="mp4a.40.5" | audioOnly | True | 302 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 139 |  | × |  | 49518 | audio/mp4; codecs="mp4a.40.5" | audioOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 140 |  | × |  | 130171 | audio/mp4; codecs="mp4a.40.2" | audioOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 140 |  | × |  | 130072 | audio/mp4; codecs="mp4a.40.2" | audioOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 249 |  | × |  | 48248 | audio/webm; codecs="opus" | audioOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 249 |  | × |  | 50981 | audio/webm; codecs="opus" | audioOnly | True | 302 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 251 |  | × |  | 106944 | audio/webm; codecs="opus" | audioOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| ANDROID_SDKLESS | 251 |  | × |  | 108013 | audio/webm; codecs="opus" | audioOnly | True | 206 | False | ANDROID route admits progressive only | n/a |
| VISIONOS | 133 | 240p | 320×240 | 15 | 183848 | video/mp4; codecs="avc1.4d400c" | videoOnly | True | 206 | True | retained | yes |
| VISIONOS | 134 | 240p | 320×240 | 15 | 150749 | video/mp4; codecs="avc1.4d400c" | videoOnly | True | 206 | False | deduplicated or parse did not complete | n/a |
| VISIONOS | 242 | 240p | 320×240 | 15 | 139537 | video/webm; codecs="vp9" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 395 | 240p | 320×240 | 15 | 105337 | video/mp4; codecs="av01.0.00M.08.0.110.05.01.06.0" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 160 | 144p | 192×144 | 15 | 83327 | video/mp4; codecs="avc1.4d400b" | videoOnly | True | 206 | True | retained | yes |
| VISIONOS | 278 | 144p | 192×144 | 15 | 81831 | video/webm; codecs="vp9" | videoOnly | True | 206 | True | retained | unsupported codec/container |
| VISIONOS | 139 |  | × |  | 49594 | audio/mp4; codecs="mp4a.40.5" | audioOnly | True | 206 | True | retained | n/a |
| VISIONOS | 139 |  | × |  | 49518 | audio/mp4; codecs="mp4a.40.5" | audioOnly | True | 206 | False | deduplicated: same profile/itag; higher bitrate retained | n/a |
| VISIONOS | 140 |  | × |  | 130171 | audio/mp4; codecs="mp4a.40.2" | audioOnly | True | 206 | True | retained | n/a |
| VISIONOS | 140 |  | × |  | 130072 | audio/mp4; codecs="mp4a.40.2" | audioOnly | True | 206 | False | deduplicated: same profile/itag; higher bitrate retained | n/a |
| VISIONOS | 249 |  | × |  | 48248 | audio/webm; codecs="opus" | audioOnly | True | 206 | False | deduplicated: same profile/itag; higher bitrate retained | n/a |
| VISIONOS | 249 |  | × |  | 50981 | audio/webm; codecs="opus" | audioOnly | True | 206 | True | retained | n/a |
| VISIONOS | 250 |  | × |  | 61101 | audio/webm; codecs="opus" | audioOnly | True | 206 | False | deduplicated: same profile/itag; higher bitrate retained | n/a |
| VISIONOS | 250 |  | × |  | 64072 | audio/webm; codecs="opus" | audioOnly | True | 206 | True | retained | n/a |
| VISIONOS | 251 |  | × |  | 106944 | audio/webm; codecs="opus" | audioOnly | True | 206 | False | deduplicated: same profile/itag; higher bitrate retained | n/a |
| VISIONOS | 251 |  | × |  | 108013 | audio/webm; codecs="opus" | audioOnly | True | 206 | True | retained | n/a |
