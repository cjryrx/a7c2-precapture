"""Offline research entry point. Firmware must remain outside this source tree."""
import sys
from pathlib import Path
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent / "src"))
from precapture.cli import main
if __name__ == "__main__":
    raise SystemExit(main())
