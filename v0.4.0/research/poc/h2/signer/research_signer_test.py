"""Real algorithm tests. Synthetic runtime facts are OFFLINE fixtures only."""
import contextlib
import hashlib
import io
import json
import random
import unittest
from urllib.parse import parse_qsl
from research_signer import (LocalWebContext, ResearchSigner, SignerInputError,
                             WebDetailStrategy, canonical_query)

T = 1790596800000
FIXTURE = LocalWebContext("FixtureBrowser/1.0", "https://www.douyin.com/note/1",
    (1100, 700, 1100, 780, 0, 0, 0, 0, 1920, 1080, 1920, 1040, 1100, 700, 24, 24), "Win32")


def sign(pairs=(("a", "1"),), context=FIXTURE, timestamp=T):
    return ResearchSigner().sign(pairs, context, timestamp_ms=timestamp,
                                 rng=random.Random(17))


class SignerTests(unittest.TestCase):
    def test_deterministic_full_algorithm(self):
        self.assertEqual(sign().signature, sign().signature)
        self.assertGreater(len(sign().signature), 100)

    def test_timestamp_changes(self):
        self.assertNotEqual(sign().signature, sign(timestamp=T + 1).signature)

    def test_ua_changes(self):
        changed = LocalWebContext("FixtureBrowser/2.0", FIXTURE.referer,
                                 FIXTURE.browser_metrics, "Win32")
        self.assertNotEqual(sign().signature, sign(context=changed).signature)

    def test_query_changes(self):
        self.assertNotEqual(sign().signature, sign((("a", "2"),)).signature)

    def test_unicode_and_roundtrip(self):
        pairs = (("文", "中 文+/=%"), ("empty", ""))
        actual = sign(pairs).encoded_query
        self.assertEqual(parse_qsl(actual, keep_blank_values=True)[:-1], list(pairs))
        self.assertTrue(actual.startswith("%E6%96%87=%E4%B8%AD%20%E6%96%87%2B%2F%3D%25&empty="))

    def test_parameter_order(self):
        self.assertNotEqual(sign((("a", "1"), ("b", "2"))).signature,
                            sign((("b", "2"), ("a", "1"))).signature)

    def test_empty_and_multiple(self):
        self.assertTrue(sign(()).signature)
        self.assertEqual(canonical_query((("a", ""), ("b", "2"))), "a=&b=2")

    def test_no_input_or_output_logging(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            result = sign((("token", "SYNTHETIC_SECRET"),))
        self.assertEqual(buf.getvalue(), "")
        self.assertNotIn("SYNTHETIC_SECRET", repr(result))
        self.assertNotIn(FIXTURE.user_agent, repr(FIXTURE))

    def test_invalid_inputs_are_redacted(self):
        for pairs in ((("a", "1"), ("a", "2")), (("a_bogus", "secret"),), (("", "x"),)):
            with self.assertRaises(SignerInputError):
                sign(pairs)
        with self.assertRaises(SignerInputError):
            sign(timestamp=-1)

    def test_uifid_is_optional(self):
        self.assertNotIn("uifid", FIXTURE.capabilities)
        WebDetailStrategy().validate(FIXTURE)
        self.assertTrue(sign(WebDetailStrategy().query("7690029886242009957")).signature)

    def test_conditional_capability_is_enforced(self):
        with self.assertRaises(SignerInputError):
            WebDetailStrategy(frozenset({"uifid"})).validate(FIXTURE)

    def test_no_global_random_state_mutation(self):
        before = random.getstate()
        sign()
        self.assertEqual(before, random.getstate())

    def test_sm3_standard_vectors(self):
        self.assertEqual(hashlib.new("sm3", b"abc").hexdigest(),
            "66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0")
        self.assertEqual(hashlib.new("sm3", b"abcd" * 16).hexdigest(),
            "debe9ff92275b8a138604889c18e5a4d6fdb70e5387e5765293dcba39c0c5732")

    def test_fixture_regression(self):
        # Recorded from attributed algorithm at fixed inputs/clock/entropy;
        # regression vector, NOT a platform acceptance or independent oracle.
        with open(__file__.replace("research_signer_test.py", "offline-vector.json"), encoding="utf-8") as f:
            vector = json.load(f)
        self.assertEqual(hashlib.sha256(sign().signature.encode()).hexdigest(),
                         vector["signatureSha256"])


if __name__ == "__main__":
    unittest.main()
