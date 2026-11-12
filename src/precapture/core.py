"""Identity-pinned, source-assembled offline patcher. No USB or device operations."""
from pathlib import Path
import hashlib, json, mmap, os, shutil, struct, subprocess, tarfile, zlib
ROOT = Path(__file__).resolve().parents[2]
TAR_OFFSET = 0x132200

class PatchError(ValueError):
    pass

def require(condition, message):
    if not condition:
        raise PatchError(message)

def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for block in iter(lambda: f.read(8 << 20), b""):
            h.update(block)
    return h.hexdigest()

def external(path):
    path = Path(path).expanduser().resolve()
    require(path != ROOT and ROOT not in path.parents,
            "Firmware, work files and output must be OUTSIDE the source/release directory")
    return path

def recipe():
    r = json.loads((ROOT / "patches/recipe.json").read_text(encoding="utf-8"))
    require(r["format"] == 1 and r["effective_window_ms"] == 800, "Unsupported recipe")
    return r

def identify(path, r=None):
    path = external(path)
    require(path.is_file(), "Input file not found")
    r = r or recipe()
    size = path.stat().st_size
    require(any(x["input_size"] == size for x in r["profiles"]), "Unsupported input size")
    digest = sha(path)
    matches = [x for x in r["profiles"] if x["input_sha256"] == digest]
    require(len(matches) == 1, "Unsupported firmware SHA256; do not bypass this check: " + digest)
    return path, matches[0]

def elf_text(path):
    """Read assembler output only; do not redistribute the resulting executable."""
    b = Path(path).read_bytes()
    require(b[:4] == b"\x7fELF" and b[5] == 1, "Expected little-endian ELF")
    if b[4] == 1:
        off = struct.unpack_from("<I", b, 32)[0]
        size, count, names = struct.unpack_from("<HHH", b, 46)
        fmt = "<10I"
    elif b[4] == 2:
        off = struct.unpack_from("<Q", b, 40)[0]
        size, count, names = struct.unpack_from("<HHH", b, 58)
        fmt = "<IIQQQQIIQQ"
    else:
        raise PatchError("Unsupported ELF class")
    require(size == struct.calcsize(fmt) and off + size * count <= len(b), "Invalid section table")
    sections = [struct.unpack_from(fmt, b, off + i * size) for i in range(count)]
    require(names < count, "Invalid ELF string table")
    strings = sections[names]
    require(strings[4] + strings[5] <= len(b), "Truncated string table")
    table = b[strings[4]:strings[4] + strings[5]]
    found = []
    for s in sections:
        require(s[1] not in (4, 9) or s[5] == 0, "Unresolved relocations")
        require(s[0] < len(table), "Invalid section name")
        end = table.find(b"\0", s[0])
        require(end >= 0, "Unterminated section name")
        if table[s[0]:end] == b".text":
            require(s[4] + s[5] <= len(b), "Truncated code section")
            found.append((s[3], b[s[4]:s[4] + s[5]]))
    require(len(found) == 1, "Expected one text section")
    return found[0]

def compile_payloads(r, zig, work):
    zig_path = shutil.which(str(zig)) or str(Path(zig).expanduser().resolve())
    require(subprocess.check_output([zig_path, "version"], text=True).strip() == "0.14.1",
            "Reproducible build requires Zig 0.14.1")
    env = os.environ.copy()
    env["ZIG_GLOBAL_CACHE_DIR"] = str(work / "zig-global")
    env["ZIG_LOCAL_CACHE_DIR"] = str(work / "zig-local")
    env["TEMP"] = env["TMP"] = str(work)
    built = {}
    for entry in r["payloads"]:
        name = entry["name"]
        require(name.replace("_", "").isalnum(), "Invalid payload name")
        src = ROOT / "patches" / (name + ".S")
        ld = ROOT / "patches" / (name + ".ld")
        require(sha(src) == entry["source_sha256"] and sha(ld) == entry["linker_sha256"], "Patch source changed: " + name)
        target = ["-target", "arm-freestanding-eabi", "-mcpu=cortex_a9", "-mthumb"] if entry["target"] == "arm" else ["-target", "aarch64-freestanding-none"]
        dest = work / (name + ".elf")
        subprocess.run([zig_path, "cc", *target, "-nostdlib", "-Wl,-T," + str(ld),
                        "-Wl,--build-id=none", str(src), "-o", str(dest)], check=True, env=env)
        address, code = elf_text(dest)
        require(address == entry["link_address"] and len(code) == entry["size"] and
                hashlib.sha256(code).hexdigest() == entry["code_sha256"], "Compiler output differs: " + name)
        built[name] = code
    return built

def checked_write(mm, entry, data):
    start, count = entry["offset"], entry["size"]
    require(isinstance(start, int) and start >= 0 and count == len(data) and start + count <= len(mm), "Invalid patch span")
    require(hashlib.sha256(mm[start:start + count]).hexdigest() == entry["old_sha256"], "Patch preimage differs at " + hex(start))
    mm[start:start + count] = data
    return set(range(start, start + count))

def members(path):
    with path.open("rb") as f:
        f.seek(TAR_OFFSET)
        with tarfile.open(fileobj=f, mode="r:") as archive:
            entries = archive.getmembers()
    required = ["0700_part_image/dev/" + x for x in ("nflasha15", "nflasha8", "nflasha5")] + ["0701_part_image_sum/part_image.sum"]
    result = {}
    for name in required:
        hit = [x for x in entries if x.name == name and x.isfile()]
        require(len(hit) == 1 and hit[0].offset_data + hit[0].size <= path.stat().st_size, "Missing or invalid member: " + name)
        result[name] = hit[0]
    return result

def update_checksums(mm, parts):
    allowed = set(range(8, 12)) | {32, 33}
    require(mm[32:34] in (b"\x01\x02", b"\x00\x02"), "Unsupported version header")
    mm[32:34] = b"\x00\x02"  # Research update label 2.00; does not unlock a camera.
    mm[8:12] = struct.pack("<I", zlib.crc32(mm[12:512]) & 0xffffffff)
    listing = parts["0701_part_image_sum/part_image.sum"]
    for name in ("nflasha15", "nflasha8", "nflasha5"):
        part = parts["0700_part_image/dev/" + name]
        crc = 0
        for pos in range(part.offset_data, part.offset_data + part.size, 8 << 20):
            crc = zlib.crc32(mm[pos:min(pos + (8 << 20), part.offset_data + part.size)], crc)
        raw = bytes(mm[listing.offset_data:listing.offset_data + listing.size])
        hits = [line for line in raw.splitlines() if line.endswith(("dev/" + name + ",").encode())]
        require(len(hits) == 1 and hits[0].startswith(b"0,") and len(hits[0]) > 10, "Ambiguous partition checksum")
        line = hits[0]
        int(line[2:10], 16)
        at = raw.find(line)
        require(raw.find(line, at + 1) < 0, "Repeated checksum entry")
        at += listing.offset_data + 2
        mm[at:at + 8] = ("%08x" % (crc & 0xffffffff)).encode()
        allowed.update(range(at, at + 8))
    return allowed

def compare_whitelist(before, after, allowed):
    import numpy as np
    total = changed = 0
    with before.open("rb") as a, after.open("rb") as b:
        while True:
            x, y = a.read(1 << 20), b.read(1 << 20)
            require(len(x) == len(y), "Plaintext sizes differ")
            if not x:
                break
            for i in np.flatnonzero(np.frombuffer(x, dtype=np.uint8) != np.frombuffer(y, dtype=np.uint8)):
                require(total + int(i) in allowed, "Unexpected plaintext change at " + hex(total + int(i)))
                changed += 1
            total += len(x)
    return {"bytes_compared": total, "changed_bytes": changed}

def build(source, destination, zig, acknowledge):
    require(acknowledge, "Read README risks and pass --acknowledge-risk to build")
    from vendor import sony_dat_container as dat
    r = recipe()
    source, profile = identify(source, r)
    destination = external(destination)
    require(not destination.exists(), "Output directory already exists; never overwrite a prior build")
    require(destination.parent.is_dir(), "Create the output parent directory first")
    require(shutil.disk_usage(destination.parent).free >= 6 * (1 << 30), "At least 6 GiB free disk required")
    destination.mkdir()
    work = destination / "work"
    work.mkdir()
    print("1/6 compile and verify source payloads", flush=True)
    payloads = compile_payloads(r, zig, work)
    print("2/6 decrypt and identify user-owned firmware", flush=True)
    layout = dat.parse(source)
    original, modified = work / "original-plain.bin", work / "modified-plain.bin"
    require(dat.decrypt_to_plain(source, layout, original) == profile["plain_sha256"], "Plaintext identity differs")
    require(original.stat().st_size == profile["plain_size"], "Plaintext size differs")
    shutil.copyfile(original, modified)
    parts = members(modified)
    print("3/6 apply bounded patches and partition checksums", flush=True)
    allowed = set()
    with modified.open("r+b") as f, mmap.mmap(f.fileno(), 0) as mm:
        for entry in r["payloads"]:
            allowed.update(checked_write(mm, entry, payloads[entry["name"]]))
        for entry in r["scalar_edits"]:
            require(1 <= entry["size"] <= 4, "Scalar patch must be at most four bytes")
            allowed.update(checked_write(mm, entry, entry["value_le"].to_bytes(entry["size"], "little")))
        allowed.update(update_checksums(mm, parts))
        mm.flush()
    print("4/6 compare every plaintext byte against the change whitelist", flush=True)
    comparison = compare_whitelist(original, modified, allowed)
    require(comparison["bytes_compared"] == profile["plain_size"] and sha(modified) == profile["output_plain_sha256"], "Full target plaintext differs")
    print("5/6 encrypt; generated firmware remains outside the repository", flush=True)
    pending = destination / "NOT_VERIFIED.partial"
    dat.encrypt_from_plain(source, layout, modified, pending)
    print("6/6 full decrypt roundtrip and output hash verification", flush=True)
    dat.verify_roundtrip(pending, layout, modified)
    output_sha = sha(pending)
    require(output_sha == profile["output_dat_sha256"], "Target package differs")
    require(sha(source) == profile["input_sha256"], "Input changed during build")
    target = destination / "BODYDATA_PRECAPTURE_800MS_EXPERIMENTAL.DAT"
    pending.rename(target)
    report = {"tool_version": r["tool_version"], "profile": profile["id"], "input_sha256": profile["input_sha256"],
              "output_sha256": output_sha, "output_plain_sha256": sha(modified), "roundtrip_verified": True,
              "comparison": comparison, "effective_window_ms": 800, "output_version_label": "2.00",
              "camera_access": False, "hardware_stability_verified": False, "custom_seconds_supported": False,
              "trigger": "AF_function_button", "halfpress_starts_cache": False,
              "reference_hardware_test_scope_passed": profile.get("hardware_test_scope_passed", False),
              "warning": "Research only. Limited reference tests are not long-term stability or installation guarantees. RAW retention may be shorter than800ms. Do not redistribute firmware/work files."}
    (destination / "build-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return report

def verify(path, work):
    from vendor import sony_dat_container as dat
    path, work = external(path), external(work)
    digest = sha(path)
    hits = [x for x in recipe()["profiles"] if x.get("output_dat_sha256") == digest]
    require(len(hits) == 1, "Not an identity-pinned output package")
    require(not work.exists() and work.parent.is_dir(), "Verification work directory must be new with an existing parent")
    work.mkdir()
    plain = work / "verified-plain.bin"
    require(dat.decrypt_to_plain(path, dat.parse(path), plain) == hits[0]["output_plain_sha256"], "Output plaintext differs")
    plain.unlink()  # Only this explicitly created file; no recursive cleanup.
    return {"profile": hits[0]["id"], "output_sha256": digest, "container_and_plaintext_verified": True, "hardware_stability_verified": False}
