"""Create a source-only ZIP and verify each archived file against the audited tree."""
from pathlib import Path
import argparse, hashlib, json, sys, zipfile
sys.dont_write_bytecode = True
from audit_release import ROOT, audit, audit_zip

def package(output):
    output = Path(output).expanduser().resolve()
    if output == ROOT or ROOT in output.parents or output.suffix.lower() != ".zip":
        raise ValueError("Choose a ZIP path OUTSIDE this repository")
    checksum = output.with_suffix(output.suffix + ".sha256")
    manifest = output.with_suffix(output.suffix + ".manifest.json")
    if not output.parent.is_dir() or any(p.exists() for p in (output, checksum, manifest)):
        raise ValueError("Output parent must exist and all output files must be new")
    files = audit()
    with zipfile.ZipFile(output, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, expected in files.items():
            data = (ROOT / name).read_bytes()
            if hashlib.sha256(data).hexdigest() != expected["sha256"]:
                raise ValueError("Source changed during packaging: " + name)
            info = zipfile.ZipInfo("a7c2-precapture/" + name, date_time=(2026, 11, 15, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            z.writestr(info, data)
    if audit_zip(output) != files or audit() != files:
        raise ValueError("Archive or source tree changed; do not publish this ZIP")
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    checksum.write_text(digest + "  " + output.name + "\n", encoding="utf-8", newline="\n")
    manifest.write_text(json.dumps({"source_only": True, "files": files}, indent=2) + "\n", encoding="utf-8", newline="\n")
    return {"archive": output.name, "sha256": digest, "files": len(files), "source_only_scan_passed": True}

if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--output", required=True)
    print(json.dumps(package(p.parse_args().output), indent=2))
