"""Install Python dependencies and (Windows x64) Zig outside the source tree."""
from pathlib import Path
import argparse, hashlib, os, platform, shutil, stat, subprocess, sys, urllib.request, venv, zipfile
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
URL = "https://ziglang.org/download/0.14.1/zig-x86_64-windows-0.14.1.zip"
DIGEST = "554f5378228923ffd558eac35e21af020c73789d87afeabf4bfd16f2e6feed2c"

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--directory", required=True, type=Path)
    p.add_argument("--zig", type=Path, help="Use an existing Zig 0.14.1; skip compiler download")
    a = p.parse_args()
    dest = a.directory.expanduser().resolve()
    if dest == ROOT or ROOT in dest.parents or dest.exists():
        p.error("Choose a NEW directory OUTSIDE this repository")
    if a.zig is None and (os.name != "nt" or platform.machine().lower() not in ("amd64", "x86_64")):
        p.error("On this platform install Zig 0.14.1 from ziglang.org and pass --zig")
    dest.mkdir(parents=True)
    env = dest / "venv"
    venv.create(env, with_pip=True)
    py = env / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    subprocess.run([str(py), "-m", "pip", "--disable-pip-version-check", "install", "-r", str(ROOT / "requirements.txt")], check=True)
    if a.zig:
        zig = a.zig.expanduser().resolve()
    else:
        archive = dest / "zig-0.14.1.zip"
        h = hashlib.sha256()
        with urllib.request.urlopen(URL, timeout=45) as response, archive.open("xb") as f:
            while block := response.read(1 << 20):
                f.write(block); h.update(block)
        if h.hexdigest() != DIGEST:
            raise RuntimeError("Zig archive checksum mismatch; archive NOT extracted")
        with zipfile.ZipFile(archive) as z:
            for item in z.infolist():
                target = (dest / item.filename).resolve()
                if dest not in target.parents or stat.S_ISLNK(item.external_attr >> 16):
                    raise RuntimeError("Unsafe compiler archive member")
                if item.is_dir(): target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with z.open(item) as src, target.open("xb") as dst: shutil.copyfileobj(src, dst)
        zig = dest / "zig-x86_64-windows-0.14.1/zig.exe"
    if subprocess.check_output([str(zig), "version"], text=True).strip() != "0.14.1":
        raise RuntimeError("Zig 0.14.1 required")
    print("Python:", py)
    print("Zig:", zig)
    print("Tools installed. No firmware downloaded and no camera accessed.")
if __name__ == "__main__": main()
