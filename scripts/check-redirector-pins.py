#!/usr/bin/env python3
"""Compare the wheels pinned in packages/mo2-redirector.nix with upstream's uv.lock."""
import re
import sys
import tomllib
from pathlib import Path

lock_path = sys.argv[1] if len(sys.argv) > 1 else "source/uv.lock"
nix_path = sys.argv[2] if len(sys.argv) > 2 else "packages/mo2-redirector.nix"
nix = Path(nix_path).read_text()
lock = tomllib.loads(Path(lock_path).read_text())
locked = {p["name"]: p["version"] for p in lock["package"]}

pinned = {}
for m in re.finditer(r'/([A-Za-z0-9_.]+)-([0-9][^-/"]*)-[^/"]*\.whl"', nix):
    pinned[m.group(1).lower().replace("_", "-")] = m.group(2)

if not pinned:
    sys.exit("no wheel URLs found in packages/mo2-redirector.nix: pattern broke?")

bad = False
for name, ver in sorted(pinned.items()):
    want = locked.get(name)
    ok = want == ver
    bad |= not ok
    print(f"{name:28} {ver:12} {'ok' if ok else f'MISMATCH (uv.lock has {want})'}")
sys.exit(1 if bad else 0)
