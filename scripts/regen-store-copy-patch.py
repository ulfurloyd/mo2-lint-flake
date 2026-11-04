#!/usr/bin/env python3
"""Apply the store-copy permission edits to a clean source checkout (argv[1]).

Files copied out of the Nix store keep its read-only mode (0444/0555), which
later breaks overwrites. Replace that with explicit, owner-writable modes.
"""
import pathlib
import sys

root = pathlib.Path(sys.argv[1])


def sub(rel, old, new, count=1):
    p = root / rel
    s = p.read_text()
    assert s.count(old) == count, f"{rel}: expected {count}x, found {s.count(old)}: {old!r}"
    p.write_text(s.replace(old, new))


sub("src/mo2-lint/util/nexus/install_handler.py",
    "        copy2(internal_path, output)\n"
    "        output.chmod(output.stat().st_mode | stat.S_IEXEC)\n",
    "        output.unlink(missing_ok=True)\n"
    "        copy2(internal_path, output)\n"
    "        output.chmod(0o755)\n", 2)

sub("src/mo2-lint/util/redirector/install.py",
    "    copy2(redirector_build, redirector_path)\n"
    "    redirector_path.chmod(redirector_path.stat().st_mode | stat.S_IEXEC)\n",
    "    redirector_path.unlink(missing_ok=True)\n"
    "    copy2(redirector_build, redirector_path)\n"
    "    redirector_path.chmod(0o755)\n")

sub("src/mo2-lint/__init__.py",
    "        copy2(tweaks_file, edit_file)\n"
    "        txt = edit_file.read_text()\n",
    "        edit_file.unlink(missing_ok=True)\n"
    "        copy2(tweaks_file, edit_file)\n"
    "        edit_file.chmod(0o644)\n"
    "        txt = edit_file.read_text()\n")

# new: first-run copies into ~/.config and ~/.local/bin
sub("src/mo2-lint/__init__.py",
    "            copy2(src, settings_path)\n",
    "            copy2(src, settings_path)\n"
    "            settings_path.chmod(0o644)\n")

sub("src/mo2-lint/__init__.py",
    "                copy2(src, dest)\n",
    "                copy2(src, dest)\n"
    "                dest.chmod(0o644)\n")

sub("src/mo2-lint/__init__.py",
    "            copy2(src, wine2linux_path)\n"
    "            wine2linux_path.chmod(wine2linux_path.stat().st_mode | 0o111)\n",
    "            copy2(src, wine2linux_path)\n"
    "            wine2linux_path.chmod(0o755)\n")
