# Douyin Local Session / Context Provider: bounded research PoC

This is a user-interactive Windows-specific research adapter, not production UI or Browser Observation. Reuses the existing WebView2 SDK/runtime, with no production dependency changes. Anonymous bootstrap history remains A4; this experiment does not investigate its generator.

## Plan recorded before network

One fresh, user-ACL-restricted MediaFlow-owned profile **outside the repository**, under the process temp root `mediaflow-v040-local-session/session-<GUID>`. The only initial navigation is the ordinary Douyin homepage in a visible window. User may complete normal platform login if required; the tool never types credentials, clicks login, obtains external browser data or solves challenges. It disables password/autofill persistence. A five-minute user window is a cancellation bound, not a conclusion about platform capability. Closing the window requests clear.

Read only Cookie snapshots scoped to the Douyin detail URI. Observe UIFID metadata, plus booleans for UIFID_TEMP/ttwid/msToken/login cookies; do not log all cookie names or values. Only an unambiguous, nonempty, unexpired UIFID Cookie qualifies. Cookie presence is **available, unvalidated**, not account validity. No storage/body/hydration/XHR decoder or CDP/MITM/proxy. Resource callbacks count requests/status only; explicit challenge paths and visible security title cause immediate invalidation and stop. WebView-generated detail requests are blocked; user interaction on normal pages remains possible. Popups and non-platform main-frame navigation are denied, so some normal login paths may be unsupported.

If UIFID is observed, stop page traffic, close the browser and wait for BrowserProcessExited; reopen the same profile **without a page navigation**, check whether UIFID persists. If it remains, one direct HTTP detail request uses exactly the old baseline query, UA, Accept and Referer, adding **only the UIFID header**. No Cookie header, ttwid/msToken, UIFID query, account Cookies, A-Bogus, X-Bogus or new headers. Log whether baseline UA differs from the actual WebView UA; a rejection cannot establish UA independence. No automatic second request. A changed recognized signature error or exact target data gives positive gate-change evidence; arbitrary different errors/redirects/empty responses do not prove acceptance. HTTP detail body exists only transiently for the explicitly authorized request, never as WebView network observation, and is not logged. Only status/error booleans and exact-target/detail/image counts are retained. No media export/download follows.

On clear, revoke handles/cancel in-flight work first; clear the dedicated profile's entire browsing data, check scoped UIFID absence; dispose the WebView, wait for browser process exit, verify exact parent/GUID and owner marker, then delete only that profile. If process exit or ownership verification fails, preserve it and report cleanup blocked. Strings/native buffers cannot promise cryptographic memory zeroing; no credential config files or raw profile artifacts are delivered.

## Contract and field matrix

`IDouyinContextProvider.Status / Acquire / Invalidate` and opaque owner+epoch `ContextHandle` are an offline research contract, with no OS types or Cookie values. Full production design adds explicit user establish/refresh/clear operations and a provider-controlled HTTP request executor. Parser depends on the handle/executor abstraction; adapter owns secrets. Only public content enters the unified content model.

| Input | PoC treatment | Production admission rule |
|---|---|---|
| UIFID | Native profile Cookie; transient header inside adapter | Proven origin/target scope; no values in public model/logs |
| UIFID_TEMP | Presence only; never substitute for UIFID | Need separate evidence before use |
| ttwid | Presence only; no explicit registration/replay | Add only if next bounded evidence requires it |
| msToken | Presence only; not generated/sent | Same evidence gate |
| Login Cookie subset | Presence booleans only; not sent to detail | Adapter-local, user authority, minimal task scope |
| UA / binding | Real default WebView UA internal; baseline comparison boolean | Native binding info stays adapter-local; no invented device data |
| expiration | Cookie expiration if non-session; session expiry unknown | Presence ≠ authorization; validate access separately |
| lastValidated | Only positive recognized acceptance evidence | Keep validation scope/time; invalidation on access rejection |
| profile state | Owner identity, active/rejected/clearing/cleared | Exact ownership; no cross-platform/browser import |

Production state flow: absent → userEstablishing → availableUnvalidated → scoped validation → valid; rejection/expiry/cancel → revoke; clear → no profile/context. Outstanding task may restart **once** after explicit user establishment, with target unchanged; safety/permission/pay/region rejection does not auto-login/retry. “Clear local Douyin session” does not imply revoking remote account sessions on other devices. PoC clears every run; it does not implement long-lived production storage.

## Windows / Android design

Windows: dedicated user data folder and profile-scoped CookieManager; adapter-controlled credential lease; browser exit precedes full owned-folder cleanup. This helper is replaceable and Windows-only; it must not enter Dart core.

Android has two candidate local adapters, both need capability gating: named `androidx.webkit.Profile` on supported MULTI_PROFILE runtime, or a dedicated persistent worker process using `WebView.setDataDirectorySuffix` before any WebView/provider initialization. Use that profile/process's CookieManager and run the HTTP operation inside the same adapter process; Binder passes an opaque context ID and sanitized status/content, not Cookie strings. No fallback to the main default WebView jar. The existing research proves limited lifecycle/worker cleanup only, not login/UIFID/context capability. CookieManager's standard URI Cookie API does not expose all expiration/HttpOnly/SameSite attributes; do not fill unknown metadata from guesses. Flush before restart, revoke leases before worker shutdown, OS-confirmed exit and exact owned paths before deletion. Runtime feature unavailable or unable to isolate/clear → context capability unavailable / production architecture gate BLOCKED. No Android installation or device modification this round.

Official primary API references: [Android Profile](https://developer.android.com/reference/androidx/webkit/Profile), [ProfileStore](https://developer.android.com/reference/androidx/webkit/ProfileStore), [WebView data-directory suffix](https://developer.android.com/reference/android/webkit/WebView#setDataDirectorySuffix(java.lang.String)), [Microsoft Cookie management](https://github.com/MicrosoftEdge/WebView2Feedback/blob/main/specs/CookieManagement.md), [clear browsing data](https://github.com/MicrosoftEdge/WebView2Feedback/blob/main/specs/ClearBrowsingData.md). These support the candidate isolation mechanisms, not proof that Douyin accepts either runtime.

## Commands

`powershell -File v0.4.0/research/poc/local-session/build.ps1`

`build/local_session_research/LocalSessionPoc.exe --self-test` — ten offline authorization/expiry/single-use/clear/ownership/security/status-snapshot assertions; no WebView or network.

`build/local_session_research/LocalSessionPoc.exe --user-session <public-target-id>` — user-interactive authorized operation, no arbitrary URL argument. Runtime profile must never be copied into research reports/repo.
