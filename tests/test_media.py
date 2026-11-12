#!/usr/bin/env python3
"""The music widget's helpers work without a player, a session bus or hardware."""
from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXEC = ROOT / "files/system/usr/libexec/tokoro"

failures = 0
total = 0


def check(name: str, condition: bool, detail: str = "") -> None:
    global failures, total
    total += 1
    if condition:
        print(f"ok: {name}")
    else:
        failures += 1
        print(f"FAIL: {name}{(' — ' + detail) if detail else ''}")


def load(name: str, filename: str):
    loader = importlib.machinery.SourceFileLoader(name, str(EXEC / filename))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


META = (
    'a{sv} 5 "mpris:trackid" o "/com/spotify/track/abc" '
    '"mpris:length" x 215000000 '
    '"mpris:artUrl" s "https://i.scdn.co/image/abc" '
    '"xesam:album" s "Discovery" '
    '"xesam:artist" as 1 "Daft Punk"'
)

META_WITH_TITLE = (
    'a{sv} 4 "xesam:title" s "One More Time" '
    '"xesam:artist" as 2 "Daft Punk" "Romanthony" '
    '"mpris:length" x 320000000 '
    '"xesam:album" s "Discovery"'
)


def main() -> int:
    # --- MPRIS parsing --------------------------------------------------------
    now = load("tokoro_nowplaying", "tokoro-nowplaying")

    check("nowplaying: tokenizes quoted strings", now.tokenize('s "hello world"')
          == [("word", "s"), ("str", "hello world")])
    check("nowplaying: tokenizes escapes", now.tokenize('s "a\\"b"')[1][1] == 'a"b')
    check("nowplaying: reads the string property", now.text_property('s "Playing"') == "Playing")
    check("nowplaying: reads a numeric property", now.number_property("x 12345678") == 12345678.0)
    check("nowplaying: converts microseconds to seconds", now.duration_seconds(215000000) == 215.0)

    meta = now.parse_metadata(META)
    check("nowplaying: parses trackid", meta.get("mpris:trackid") == "/com/spotify/track/abc")
    check("nowplaying: parses length", meta.get("mpris:length") == 215000000)
    check("nowplaying: parses album", meta.get("xesam:album") == "Discovery")
    check("nowplaying: parses artist list", meta.get("xesam:artist") == ["Daft Punk"],
          str(meta.get("xesam:artist")))
    check("nowplaying: parses art url",
          meta.get("mpris:artUrl") == "https://i.scdn.co/image/abc")

    titled = now.parse_metadata(META_WITH_TITLE)
    check("nowplaying: parses title", titled.get("xesam:title") == "One More Time")
    check("nowplaying: parses multiple artists",
          titled.get("xesam:artist") == ["Daft Punk", "Romanthony"],
          str(titled.get("xesam:artist")))
    check("nowplaying: empty metadata is empty", now.parse_metadata("a{sv} 0") == {})
    check("nowplaying: garbage does not raise", isinstance(now.parse_metadata("nonsense"), dict))

    env = os.environ.copy()
    bare = subprocess.run([sys.executable, str(EXEC / "tokoro-nowplaying"), "--json"],
                          capture_output=True, text=True, timeout=30, env=env)
    check("nowplaying: reports no player with exit 2", bare.returncode == 2,
          bare.stderr.strip())
    try:
        payload = json.loads(bare.stdout)
    except json.JSONDecodeError:
        payload = {}
        check("nowplaying: emits JSON without a player", False, bare.stdout[:120])
    else:
        check("nowplaying: emits JSON without a player", True)
    check("nowplaying: defaults to Stopped", payload.get("status") == "Stopped")
    check("nowplaying: marked as a test feature", payload.get("test_feature") is True)

    # --- library --------------------------------------------------------------
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        music = tmp / "music"
        album = music / "Discovery"
        album.mkdir(parents=True)
        (album / "one_more_time.mp3").write_bytes(b"\0" * 100)
        (music / "aerodynamic.flac").write_bytes(b"\0" * 200)
        (music / "notes.txt").write_text("not audio", encoding="utf-8")
        (album / "cover.jpg").write_bytes(b"\0" * 50)

        lib_env = env.copy()
        lib_env["XDG_DATA_HOME"] = str(tmp / "data")
        result = subprocess.run(
            [sys.executable, str(EXEC / "tokoro-library"), "--json", "--refresh",
             "--dir", str(music)],
            capture_output=True, text=True, timeout=60, env=lib_env)
        check("library: exits 0", result.returncode == 0, result.stderr.strip())
        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError as err:
            data = {}
            check("library: emits JSON", False, str(err))
        else:
            check("library: emits JSON", True)
        titles = {track["title"] for track in data.get("tracks", [])}
        check("library: finds both audio files", titles == {"one more time", "aerodynamic"},
              str(sorted(titles)))
        check("library: ignores non-audio files",
              all(track["path"].endswith((".mp3", ".flac")) for track in data.get("tracks", [])))
        by_title = {track["title"]: track for track in data.get("tracks", [])}
        check("library: derives the artist folder",
              by_title.get("one more time", {}).get("artist") == "Discovery")
        check("library: derives the album folder",
              by_title.get("one more time", {}).get("album") == "Discovery")
        check("library: root audio has no artist",
              by_title.get("aerodynamic", {}).get("artist") == "")
        cache = tmp / "data/tokoro/library.json"
        check("library: writes the cache", cache.is_file())
        if cache.is_file():
            check("library: cache is valid JSON",
                  isinstance(json.loads(cache.read_text(encoding="utf-8")), dict))

        # The cache is used when nothing new is requested.
        cached = subprocess.run(
            [sys.executable, str(EXEC / "tokoro-library"), "--json"],
            capture_output=True, text=True, timeout=30, env=lib_env)
        check("library: reuses the cache",
              cached.returncode == 0
              and len(json.loads(cached.stdout).get("tracks", [])) == 2)

    # --- levels ---------------------------------------------------------------
    levels = subprocess.run(
        [sys.executable, str(EXEC / "tokoro-levels"), "--json", "--simulate",
         "--count", "16", "--phase", "0"],
        capture_output=True, text=True, timeout=30, env=env)
    check("levels: exits 0", levels.returncode == 0, levels.stderr.strip())
    try:
        payload = json.loads(levels.stdout)
    except json.JSONDecodeError as err:
        payload = {}
        check("levels: emits JSON", False, str(err))
    else:
        check("levels: emits JSON", True)
    bars = payload.get("bars", [])
    check("levels: returns the requested bar count", len(bars) == 16, str(len(bars)))
    check("levels: bars are in range", all(0 <= value <= 100 for value in bars), str(bars))
    check("levels: simulation is labelled", payload.get("source") == "simulated")
    check("levels: simulation is deterministic", bars == payload.get("bars"))

    available = subprocess.run(
        [sys.executable, str(EXEC / "tokoro-levels"), "--available"],
        capture_output=True, text=True, timeout=30, env=env)
    expected = 0 if shutil.which("cava") else 1
    check("levels: --available matches cava presence", available.returncode == expected,
          f"rc={available.returncode} cava={bool(shutil.which('cava'))}")

    bad = subprocess.run(
        [sys.executable, str(EXEC / "tokoro-levels"), "--json", "--count", "0"],
        capture_output=True, text=True, timeout=30, env=env)
    check("levels: rejects a zero bar count", bad.returncode != 0)

    print()
    if failures:
        print(f"{failures} of {total} checks failed")
        return 1
    print(f"all {total} checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
