#!/usr/bin/env python3
"""Make winetricks use the Wine/Proton runner Heroic assigned to the game.

Usage: regen-winetricks-heroic-patch.py <clean source checkout>
"""
import pathlib
import sys

path = pathlib.Path(sys.argv[1]) / "src/mo2-lint/util/wine/winetricks.py"
s = path.read_text()


def sub(old, new, count=1):
    global s
    assert s.count(old) == count, f"expected {count}x, found {s.count(old)}: {old!r}"
    s = s.replace(old, new)


sub("import os\nimport re\n", "import json\nimport os\nimport re\n")

HELPER = '''def _heroic_runner_bin(prefix: Path) -> Path | None:
    """
    Find the bin directory of the Wine/Proton build Heroic uses for the game that
    owns this prefix. winetricks needs wine and wineserver from that same build.

    Heroic keeps them per game in GamesConfig/<app>.json (winePrefix, wineVersion.bin).
    Returns None if the prefix is not a Heroic game's, or nothing usable is found.
    """
    config_dirs = [
        Path("~/.config/heroic").expanduser(),
        Path("~/.var/app/com.heroicgameslauncher.hgl/config/heroic").expanduser(),
    ]
    for config_dir in config_dirs:
        for config_json in sorted((config_dir / "GamesConfig").glob("*.json")):
            try:
                data = json.loads(config_json.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            if not isinstance(data, dict):
                continue
            for entry in data.values():
                if not isinstance(entry, dict):
                    continue
                game_prefix = entry.get("winePrefix")
                wine_bin = (entry.get("wineVersion") or {}).get("bin")
                if not game_prefix or not wine_bin:
                    continue
                try:
                    if Path(game_prefix).expanduser().resolve() != prefix:
                        continue
                except OSError:
                    continue
                wine_bin = Path(wine_bin)
                if wine_bin.name == "proton":
                    bin_dir = wine_bin.parent / "files" / "bin"
                else:
                    bin_dir = wine_bin.parent
                if (bin_dir / "wine").exists() and (bin_dir / "wineserver").exists():
                    logger.debug(f"Using Heroic runner from {bin_dir}")
                    return bin_dir
    return None


'''
sub("def run(\n", HELPER + "def run(\n")

sub(
    '    env = os.environ.copy()\n'
    '    env.setdefault("WINEPREFIX", str(prefix))\n'
    '    logger.trace(f"Using Wine prefix: {prefix}")\n',
    '    env = os.environ.copy()\n'
    '    env.setdefault("WINEPREFIX", str(prefix))\n'
    '    logger.trace(f"Using Wine prefix: {prefix}")\n'
    '\n'
    '    # winetricks finds wine and wineserver on PATH. For Heroic games they are the\n'
    "    # runner's own, and a downloaded runner is a generic Linux binary that NixOS\n"
    '    # can only start inside an FHS environment (steam-run).\n'
    '    launcher: list[str] = []\n'
    '    runner = _heroic_runner_bin(prefix)\n'
    '    if runner is not None:\n'
    '        env["PATH"] = f"{runner}:{env.get(\'PATH\', \'\')}"\n'
    '        env["WINE"] = str(runner / "wine")\n'
    '        env["WINESERVER"] = str(runner / "wineserver")\n'
    '        steam_run = shutil.which("steam-run")\n'
    '        if steam_run and not str(runner).startswith("/nix/store/"):\n'
    '            launcher = [steam_run]\n'
    '            logger.debug("Running winetricks inside steam-run")\n',
)

sub(
    "        proc = subprocess.Popen(\n            cmd,\n            stdout=subprocess.PIPE,",
    "        proc = subprocess.Popen(\n            launcher + cmd,\n            stdout=subprocess.PIPE,",
)

path.write_text(s)
