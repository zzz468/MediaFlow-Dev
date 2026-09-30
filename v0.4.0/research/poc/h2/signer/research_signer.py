"""Local research adapter for an attributed Apache-2.0 algorithm.

No platform requests, credential storage, or browser identity generation.
"""
from dataclasses import dataclass, field
import random
import time
from urllib.parse import quote, urlencode
from vendor.f2_abogus import ABogus


class SignerInputError(ValueError):
    def __str__(self):
        return "ResearchSigner input rejected (values redacted)"


@dataclass(frozen=True, repr=False)
class LocalWebContext:
    user_agent: str
    referer: str
    # Non-secret runtime measurements. Never randomly generated identity.
    browser_metrics: tuple[int, ...]
    browser_platform: str
    ttwid: str | None = field(default=None, repr=False)
    uifid: str | None = field(default=None, repr=False)
    ms_token: str | None = field(default=None, repr=False)

    def __repr__(self):
        return "LocalWebContext(redacted)"

    @property
    def capabilities(self):
        found = {"userAgent", "referer", "measuredBrowserMetrics"}
        for name, value in (("ttwid", self.ttwid), ("uifid", self.uifid),
                            ("msToken", self.ms_token)):
            if value:
                found.add(name)
        return frozenset(found)


@dataclass(frozen=True, repr=False)
class SignedQuery:
    encoded_query: str
    signature: str
    def __repr__(self):
        return "SignedQuery(redacted)"


def canonical_query(pairs):
    pairs = tuple(pairs)
    seen = set()
    for key, value in pairs:
        if (not isinstance(key, str) or not key or not isinstance(value, str)
                or key in seen or key.lower() in {"a_bogus", "x-bogus"}):
            raise SignerInputError()
        seen.add(key)
    # Preserve caller order; percent-encode exactly once with spaces as %20.
    return urlencode(pairs, quote_via=quote, safe="")


class ResearchSigner:
    required_capabilities = frozenset({"userAgent", "measuredBrowserMetrics"})

    def sign(self, pairs, context, *, timestamp_ms=None, rng=None):
        if (not self.required_capabilities <= context.capabilities
                or not context.user_agent.strip()
                or any(ord(c) < 32 or ord(c) > 127 for c in context.user_agent)
                or len(context.browser_metrics) != 16
                or any(type(n) is not int or n < 0 for n in context.browser_metrics)
                or not context.browser_platform.isascii()
                or not context.browser_platform.isalnum()):
            raise SignerInputError()
        query = canonical_query(pairs)
        if timestamp_ms is not None and (type(timestamp_ms) is not int
                                        or timestamp_ms < 0
                                        or timestamp_ms >= 2**48):
            raise SignerInputError()
        clock = ((lambda: timestamp_ms) if timestamp_ms is not None
                 else lambda: int(time.time() * 1000))
        # Algorithm noise is distinct from browser identity. Offline tests
        # inject a seed; live uses OS-backed entropy. Never mutates global RNG.
        engine = ABogus(
            fp="|".join(map(str, context.browser_metrics)) + "|" + context.browser_platform,
            user_agent=context.user_agent, clock_ms=clock,
            rng=rng if rng is not None else random.SystemRandom(),
        )
        result = engine.generate_abogus(query, "")
        signature = result[1]
        if (not signature or any(c not in engine.character + "=" for c in signature)
                or result[0] != query + "&a_bogus=" + signature):
            raise SignerInputError()
        return SignedQuery(query + "&a_bogus=" + quote(signature, safe=""), signature)


@dataclass(frozen=True)
class WebDetailStrategy:
    required_capabilities: frozenset = frozenset({"userAgent", "referer"})
    include_ttwid: bool = False

    def validate(self, context):
        required = self.required_capabilities | ({"ttwid"} if self.include_ttwid else set())
        if not required <= context.capabilities:
            raise SignerInputError()

    def query(self, aweme_id):
        if not aweme_id.isascii() or not aweme_id.isdigit() or len(aweme_id) > 30:
            raise SignerInputError()
        return (("device_platform", "webapp"), ("aid", "6383"),
                ("channel", "channel_pc_web"), ("aweme_id", aweme_id))
