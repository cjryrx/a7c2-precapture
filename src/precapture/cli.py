import argparse, json, sys, subprocess
from .core import PatchError, identify, build, verify, recipe

def main(argv=None):
    p = argparse.ArgumentParser(description="A7C II precapture research tools. No firmware supplied; no camera access.")
    sub = p.add_subparsers(dest="command", required=True)
    sub.add_parser("profiles")
    check = sub.add_parser("check"); check.add_argument("--input", required=True)
    b = sub.add_parser("build"); b.add_argument("--input", required=True); b.add_argument("--out", required=True); b.add_argument("--zig", required=True); b.add_argument("--acknowledge-risk", action="store_true")
    v = sub.add_parser("verify"); v.add_argument("--input", required=True); v.add_argument("--work", required=True)
    a = p.parse_args(argv)
    try:
        if a.command == "profiles": print(json.dumps(recipe()["profiles"], indent=2))
        elif a.command == "check": print(json.dumps(identify(a.input)[1], indent=2))
        elif a.command == "build": build(a.input, a.out, a.zig, a.acknowledge_risk)
        elif a.command == "verify": print(json.dumps(verify(a.input, a.work), indent=2))
        return 0
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as e:
        print("ERROR: " + str(e), file=sys.stderr)
        return 2
