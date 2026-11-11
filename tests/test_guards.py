"""Fail-closed tests using synthetic data only; no firmware or camera required."""
from pathlib import Path
import hashlib, importlib.util, json, sys, tempfile, unittest, zipfile
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT / "tools"))
from precapture import core
from audit_release import inspect, audit, audit_zip

class GuardTests(unittest.TestCase):
    def test_reject_source_tree_paths(self):
        for path in (ROOT, ROOT / "new-output", ROOT / "docs" / ".." / "firmware.dat"):
            with self.subTest(path=path), self.assertRaises(core.PatchError):
                core.external(path)

    def test_missing_risk_acknowledgement_creates_nothing(self):
        with tempfile.TemporaryDirectory(prefix="precapture-test-", dir=ROOT.parent) as temp:
            dest = Path(temp) / "output"
            with self.assertRaises(core.PatchError):
                core.build(Path(temp) / "missing.dat", dest, "missing-zig", False)
            self.assertFalse(dest.exists())

    def test_unknown_input_rejected_before_any_modification(self):
        with tempfile.TemporaryDirectory(prefix="precapture-test-", dir=ROOT.parent) as temp:
            path = Path(temp) / "input.txt"
            path.write_bytes(b"sample")
            config = {"profiles": [{"input_size": 6, "input_sha256": "0" * 64}]}
            with self.assertRaisesRegex(core.PatchError, "SHA256"):
                core.identify(path, config)
            self.assertEqual(path.read_bytes(), b"sample")

    def test_wrong_preimage_does_not_modify_buffer(self):
        buf = bytearray(b"abcdefgh")
        entry = {"offset": 2, "size": 2, "old_sha256": hashlib.sha256(b"zz").hexdigest()}
        with self.assertRaisesRegex(core.PatchError, "preimage"):
            core.checked_write(buf, entry, b"12")
        self.assertEqual(buf, b"abcdefgh")

    def test_invalid_span_does_not_modify_buffer(self):
        for offset, size in ((-1, 2), (7, 2), (0, 3)):
            buf = bytearray(b"abcdefgh")
            with self.subTest(offset=offset, size=size), self.assertRaises(core.PatchError):
                core.checked_write(buf, {"offset": offset, "size": size}, b"12")
            self.assertEqual(buf, b"abcdefgh")

    @unittest.skipUnless(importlib.util.find_spec("numpy"), "Install requirements for full whitelist test")
    def test_change_outside_whitelist_rejected(self):
        with tempfile.TemporaryDirectory(prefix="precapture-test-", dir=ROOT.parent) as temp:
            a, b = Path(temp) / "before.txt", Path(temp) / "after.txt"
            a.write_bytes(b"abcdefgh")
            b.write_bytes(b"aXcdefgY")
            with self.assertRaisesRegex(core.PatchError, "Unexpected"):
                core.compare_whitelist(a, b, {1})
            self.assertEqual(core.compare_whitelist(a, b, {1, 7})["changed_bytes"], 2)

    def test_release_profiles_and_patch_sources_are_pinned(self):
        r = core.recipe()
        for p in r["profiles"]:
            for key in ("input_sha256", "plain_sha256", "output_plain_sha256", "output_dat_sha256"):
                self.assertRegex(p[key], r"^[a-f0-9]{64}$")
        for p in r["payloads"]:
            self.assertEqual(core.sha(ROOT / "patches" / (p["name"] + ".S")), p["source_sha256"])
            self.assertEqual(core.sha(ROOT / "patches" / (p["name"] + ".ld")), p["linker_sha256"])

    def test_audit_rejects_binary_and_encoded_content(self):
        for name, data in (("BODYDATA.DAT", b"sample"), ("test.py", b"x\0y"), ("blob.txt", b"A" * 401)):
            with self.subTest(name=name), self.assertRaises(ValueError):
                inspect(name, data)

    def test_audit_checks_untracked_files(self):
        with tempfile.TemporaryDirectory(prefix="precapture-test-", dir=ROOT.parent) as temp:
            path = Path(temp)
            (path / "README.md").write_text("source only\n", encoding="utf-8")
            (path / "unexpected.dat").write_bytes(b"sample")
            with self.assertRaises(ValueError):
                audit(path)

    def test_archive_traversal_rejected(self):
        with tempfile.TemporaryDirectory(prefix="precapture-test-", dir=ROOT.parent) as temp:
            path = Path(temp) / "test.zip"
            with zipfile.ZipFile(path, "w") as z:
                z.writestr("../outside.py", "pass\n")
            with self.assertRaises(ValueError):
                audit_zip(path)

if __name__ == "__main__":
    unittest.main()
