# Android user validation 2026-10-02
Device: PJZ110 / TEST_DEVICE. Package: com.mediaflow.research.v050.feasibility. Build identity: youtube-client-probe-20261002-9.
Read-only ADB observation: no installation, replacement, uninstall or data clear.
Raw app report: youtube-client-probe-user-android-20261002.json; copied without modifying app data.
VISIONOS video itag313: HTTP200, 31,480,042 bytes, full download successful, no403, VP9 video track.
VISIONOS audio itag139: HTTP200, 113,197 bytes, full download successful, no403, AAC audio track.
User explicitly confirmed both files open and play normally in the preceding chat. App systemPlaybackSucceeded remains null; human confirmation is separate evidence, not an automatically recorded app PASS.
Conclusion: YOUTUBE CLIENT FALLBACK FEASIBLE for this Android device, network and fixed hLY9KMIU2BA sample. This does not establish repeat-run stability, Windows validation or universal video support. Do not implement SABR based on this result.
Client direct URL counts / progressive / video-only / audio-only:
VISIONOS 29 / 0 / 24 / 5; ANDROID_SDKLESS 29 / 1 / 24 / 4; ANDROID 32 / 1 / 25 / 6; IOS 29 / 0 / 24 / 5.
MWEB and SAFARI_WEB: player UNPLAYABLE. ANDROID_VR: LOGIN_REQUIRED with transport securityChallenge classification; no bypass attempted. WEB current run NOT TESTED after safety stop; historical baseline remains SABR-only.
Next research priority: manually validate an ANDROID_SDKLESS or ANDROID progressive resource to determine whether ordinary combined audio/video download works without media merging. No additional online requests initiated by the agent in this observation turn. No code, dependencies or Git writes.
