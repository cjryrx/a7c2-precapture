"""Audit the entire source tree, including untracked files; never trust .gitignore alone."""
from pathlib import Path
import hashlib, json, re, stat, sys, zipfile
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SUFFIXES = {".py", ".md", ".txt", ".json", ".S", ".ld", ".yml", ".yaml"}
SPECIAL = {"LICENSE", "LICENSE.a7c2-dat-tools", ".gitignore", ".gitattributes"}

def inspect(name, data):
    p = Path(name)
    if p.suffix not in SUFFIXES and p.name not in SPECIAL: raise ValueError("Unexpected file type: " + name)
    if len(data) > 200000 or b"\0" in data: raise ValueError("Binary/oversize file: " + name)
    text = data.decode("utf-8")
    if re.search(r"[0-9a-fA-F]{129,}", text) or re.search(r"[A-Za-z0-9+/]{400,}={0,2}", text):
        raise ValueError("Possible encoded binary payload: " + name)
    if re.search(r"[A-Za-z]:[/\\]Users[/\\][^/\\\s]+", text):
        raise ValueError("Private user directory: " + name)
    if re.search(r"(?:ghp_|github_pat_)[A-Za-z0-9_]{20,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----", text):
        raise ValueError("Possible credential: " + name)
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

def audit(root=ROOT):
    files = {}
    for path in sorted(root.rglob("*")):
        rel = path.relative_to(root)
        if rel.parts[0] == ".git": continue
        if path.is_symlink(): raise ValueError("Symlinks prohibited: " + str(rel))
        if path.is_file(): files[rel.as_posix()] = inspect(rel.as_posix(), path.read_bytes())
    if not files: raise ValueError("Empty source tree")
    return files

def audit_zip(path):
    files = {}
    with zipfile.ZipFile(path) as z:
        for entry in z.infolist():
            if entry.file_size > 200000 or stat.S_ISLNK(entry.external_attr >> 16): raise ValueError("Oversize or symlink zip member")
            if entry.is_dir(): continue
            parts = Path(entry.filename).parts
            if Path(entry.filename).is_absolute() or ".." in parts or ".git" in parts: raise ValueError("Unsafe zip path")
            name = "/".join(parts[1:]) if parts and parts[0] == "a7c2-precapture" else entry.filename
            if name in files: raise ValueError("Duplicate zip path")
            files[name] = inspect(name, z.read(entry))
    return files

if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--zip": result = audit_zip(Path(sys.argv[2]))
    elif len(sys.argv) == 1: result = audit()
    else: raise SystemExit("usage: audit_release.py [--zip source-archive.zip]")
    print(json.dumps({"status": "SOURCE_ONLY_SCAN_PASSED", "files": result}, indent=2))
