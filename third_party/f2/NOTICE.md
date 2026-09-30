# F2 attribution — MediaFlow Gallery production candidate

Upstream: **Johnserf-Seed/f2**, https://github.com/Johnserf-Seed/f2

Pinned source commit: `a30feaf92a40f421273b01b6ef36aa83a93f63c0`

Copyright (c) 2023 JohnserfSeed. Author of the algorithm file: JohnserfSeed.
License: Apache License 2.0; complete text in the adjacent `LICENSE`.
No upstream root NOTICE was found in this pinned tree. This file is MediaFlow's
source/adaptation record, not a purported upstream NOTICE.

| Upstream file / function | MediaFlow counterpart | Use |
|---|---|---|
| `f2/utils/crypto/bytedance/abogus.py`: ABogus.generate_abogus | `lib/features/parser/data/douyin/gallery/f2_gallery_signer.dart`: F2GallerySigner.sign | Direct attributed Dart adaptation |
| Same file: CryptoUtility.transform_bytes, rc4_encrypt, base64_encode, abogus_encode; StringProcessor.generate_random_bytes | Same Dart module: transform loop, _rc4, _encode, entropy prefix | Direct attributed adaptation; original integer encoding semantics retained |
| Same file: CryptoUtility.sm3_to_array | gallerySm3 | SM3 implemented locally from its public algorithm specification; replaces gmssl/hashlib runtime dependency |
| `f2/apps/douyin/model.py`: BaseRequestModel/PostDetail | douyin_gallery_backend.dart: request fields | Behavioral reference for endpoint/query ordering and names |
| `f2/apps/douyin/utils.py`: ABogusManager.model_2_endpoint, GatewayHeaderManager | Same backend: canonical input / signature placement / compatibility flag | Behavioral reference; no random browser identity generation copied |
| `f2/apps/douyin/crawler.py`: fetch_post_detail; `f2/crawlers/base_crawler.py`: JSON handling | F2DouyinGalleryDetailClient / DirectDouyinDetailTransport | Behavioral reference; independent bounded transport and typed errors |

MediaFlow changes (2026-09-28/29): Dart implementation; explicit UA and measured
browser facts; injectable clock and algorithm entropy; no Python, gmssl or F2
CLI; no generated fingerprint/device identity; no proxy, retry or unrelated
endpoints; minimal private owned-session input; optional normally issued msToken
only, no random/fake token fallback; note Referer and Origin; default Argus
compatibility header off at the low-level client's default and explicitly enabled
by the Android Gallery factory / successful Windows candidate; allowlisted raw
content output and typed failures. This header is confined to Gallery detail;
it is not added to public HTTP clients, video parsers or other platforms.

Signer equivalence is tested against the existing research synthetic golden
(fixed query/UA/metrics/clock/entropy); it is not proof of server acceptance of
the production candidate or necessity of any individual query/header. Separate
real acceptance on 2026-09-29 verified the fixed 13-image target on Windows and
Android with App-owned normal sessions. Windows' bounded A/B established that
adding only the upstream `x-tt-argus: 1` changed 403 to business JSON in that
environment; Android used the same scoped compatibility setting successfully,
without an Android necessity A/B. See the two platform acceptance reports in
`v0.4.0/research/`. No new signature algorithm or workaround was introduced.

SM3 specification/vector reference:
https://datatracker.ietf.org/doc/draft-oscca-cfrg-sm3/01/
No source code from that document was copied.

No GPL, commercial-restricted or unknown-origin signer was included. The full
F2 project and its dependencies were not adopted. Upstream README describes
research/learning and commercial attribution; provenance and copyright are
retained here. Runtime dependencies remain the already present Dart/Flutter and
Windows .NET/WebView2 stack, whose existing platform-specific distribution and
runtime availability requirements still apply.

Keep this record, LICENSE, attribution and notices of changes with applicable
source/binary distributions. The normal MediaFlow main entry now uses this
capability; verification is limited to the tested gallery and platform/device
configurations. No release has been published.
