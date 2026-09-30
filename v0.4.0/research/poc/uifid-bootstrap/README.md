# UIFID first-bootstrap metadata experiment

Independent Windows-only research probe; not Browser Observation Parser or production. No login, credentials import, signer, detail API experiment or media download. Reuses the already installed WebView2 SDK/runtime; no package changes. Default invocation refuses network; `--self-test` is offline.

## Bounded plan (2026-09-28)

One new GUID-owned persistent profile, no shared browser state. A: locally intercept the Douyin origin with an empty HTML fixture (zero platform traffic), verify Cookie jar and same-origin local/session storage and IndexedDB database metadata. B: one normal homepage navigation, up to 12 seconds. C: only if no UIFID and no safety stop, one public note navigation, up to 12 seconds. Stop immediately on security resource, visible verification, HTTP 401/403/429, unexpected navigation or observed UIFID. No retry. Requests already issued may complete during shutdown. Images/media and automatic detail API requests are blocked; this can affect initialization and must be reported as a limitation. Default runtime UA is unchanged.

Only cookie names/domain/path/flags/expiry and UIFID lengths, storage keys/database metadata and script URLs without queries are logged. Cookie values stay within the WebView2 process/profile; no values, hashes or response bodies are logged. Script reads metadata only; it does not replace cookie setters, change storage, spoof identity or solve challenges. IndexedDB values are not read. Profile deletion happens only after browser process exit and checking the exact GUID-owned path under the intended build root.

## Candidate matrix before experiment

All bindings (UA/ttwid/profile), expiry/refresh and cross-request persistence are unknown until a UIFID is actually observed. “No result in one bounded run” is not proof of impossibility.

| Candidate | Anonymous action | Existing evidence / experiment | UIFID location / first timing |
|---|---|---|---|
| Plain homepage GET | Yes | Prior HTTP 200, nonce only; B adds normal browser JS | Prior response: no visible UIFID; B unknown |
| Homepage with normal web parameters | Potentially | No verified necessary parameter; do not invent one | Unknown |
| Public work page | Yes if accessible | C uses one public note | Unknown |
| share/note | Yes if accessible | Same C; no additional share navigation | Unknown |
| Page JS SDK initialization | Potentially | Observe loaded scripts + storage metadata during B/C | Unknown; JS necessity not established |
| SecSDK/Argus initialization | Potentially | Observe normal page, stop challenge; no SDK invocation | Unknown; no demonstrated generator |
| document.cookie | Read in page origin | Cookie names sampled, non-HttpOnly only | Presence gives storage, not setter provenance |
| Set-Cookie | Normal platform response | Names recorded with resource host/path/time | Positive UIFID header could support server-issued |
| localStorage | Origin-local | Keys and UIFID length only | Unknown; presence alone does not prove generation |
| sessionStorage | Tab-local | Keys and UIFID length only | Unknown |
| IndexedDB | Origin-local | Database names/versions only, no records | UIFID within records remains untested |
| WebView profile | Local isolated | Cookie metadata, empty-origin preflight | Persistence/binding requires positive state first |
| User login | Not authorized this round | No login action/import | Auth-bound not proven |
| Pre-login anonymous identifier | Potentially | Fresh A followed by B/C | Unknown; do not substitute nonce/ttwid/msToken |
| Other confirmed action | No confirmed UIFID bootstrap | media-parser independent ttwid registration consumes separate identifier | No evidence ttwid generates UIFID |

## Build / execution

`powershell -File v0.4.0/research/poc/uifid-bootstrap/build.ps1`

`build/uifid_context_research/ContextBootstrapProbe.exe --self-test`

Public execution requires explicit `--run-public` and an isolated parent path. Keep raw profile out of version control; never attach it to reports. This probe deliberately does not implement the optional subsequent detail experiment.
