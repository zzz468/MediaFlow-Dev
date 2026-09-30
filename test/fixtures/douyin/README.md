# Authorized gallery fixture

`authorized_gallery_13_sanitized.json` comes from an actual original F2 detail
response for `7690029886242009957`, captured through a fresh App-owned session
on 2026-09-28. It is an allowlisted projection, not an invented response and not
the complete raw payload. Image order and `url_list` shape are preserved.
URL values and description are replaced. No Cookie, credentials, original CDN
URLs, account metadata, or signatures are included.

The adjacent provenance file records source commit, transformation and SHA256.
Tests validate preservation of fixture URLs; they do not assert that placeholder
URLs are downloadable or that actual CDN URLs remain valid.

Original F2: Johnserf-Seed/f2, commit
`a30feaf92a40f421273b01b6ef36aa83a93f63c0`, Apache-2.0. The adapter is an original
field mapper informed by the upstream response/filter contract; no upstream
signer or HTTP client source is included in this fixture or adapter.
