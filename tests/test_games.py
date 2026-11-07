#!/usr/bin/env python3
"""Game dataset integrity and CLI behaviour."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAMES = ROOT / "files/system/usr/libexec/tokoro/tokoro-games"
DATASET = ROOT / "files/system/usr/share/tokoro/games/games.json"
RATINGS = {"green", "yellow", "orange", "red"}
WEIGHTS = {"light", "medium", "heavy"}


def run(*args: str) -> subprocess.CompletedProcess:
    env = dict(os.environ)
    env["TOKORO_SHARE"] = str(ROOT / "files/system/usr/share/tokoro")
    env["TOKORO_EXEC"] = str(ROOT / "files/system/usr/libexec/tokoro")
    env["XDG_DATA_HOME"] = "/tmp/tokoro-test-data"
    return subprocess.run([sys.executable, str(GAMES), *args],
                          capture_output=True, text=True, env=env, timeout=60)


def main() -> int:
    failures = 0
    data = json.loads(DATASET.read_text(encoding="utf-8"))
    games = data["games"]

    checks = [
        ("schema version", data.get("schema") == 1),
        ("dataset has a useful seed size", len(games) >= 100),
        ("unique ids", len({g["id"] for g in games}) == len(games)),
        ("valid ratings", all(g["rating"] in RATINGS for g in games)),
        ("valid weights", all(g["weight"] in WEIGHTS for g in games)),
        ("every game has a name", all(g.get("name") for g in games)),
        ("excluded games are named", len(data.get("excluded", [])) >= 10),
    ]
    excluded_names = {entry["name"].lower() for entry in data.get("excluded", [])}
    for blocked in ("valorant", "fortnite", "apex legends", "destiny 2"):
        checks.append((f"{blocked} excluded", blocked in excluded_names))

    for name, ok in checks:
        if ok:
            print(f"ok: {name}")
        else:
            print(f"FAIL: {name}")
            failures += 1

    validate = run("validate")
    if validate.returncode == 0:
        print(f"ok: validate -> {validate.stdout.strip()}")
    else:
        print(f"FAIL: validate -> {validate.stdout}{validate.stderr}")
        failures += 1

    info = run("info", "Elden Ring")
    if info.returncode == 0 and "rating" in info.stdout and "fps" in info.stdout:
        print("ok: info shows rating and tier expectation")
    else:
        print(f"FAIL: info output unexpected: {info.stdout}{info.stderr}")
        failures += 1

    excluded = run("excluded")
    if excluded.returncode == 0 and "Valorant" in excluded.stdout:
        print("ok: excluded list renders")
    else:
        print("FAIL: excluded list")
        failures += 1

    stats = run("stats")
    if stats.returncode == 0 and "games rated" in stats.stdout:
        print("ok: stats renders")
    else:
        print("FAIL: stats")
        failures += 1

    # Dependency-free sanity: the ratings table is documented, not invented.
    if set(data.get("ratings", {})) == RATINGS:
        print("ok: ratings legend complete")
    else:
        print("FAIL: ratings legend incomplete")
        failures += 1

    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
