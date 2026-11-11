#!/usr/bin/env python3
"""The test-feature commands work on a fixture install (no root, no hardware)."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXEC = ROOT / "files/system/usr/libexec/tokoro"
SHARE = ROOT / "files/system/usr/share/tokoro"

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


def fixture_home(tmp: Path) -> dict:
    env = os.environ.copy()
    paths = {
        "TOKORO_ETC": tmp / "etc",
        "TOKORO_STATE": tmp / "state",
        "TOKORO_USER_CONFIG": tmp / "home/.config/tokoro",
        "XDG_STATE_HOME": tmp / "home/.local/state",
        "XDG_CONFIG_HOME": tmp / "home/.config",
    }
    for path in paths.values():
        path.mkdir(parents=True, exist_ok=True)
    env.update({key: str(value) for key, value in paths.items()})
    env.update({
        "TOKORO_EXEC": str(EXEC),
        "TOKORO_SHARE": str(SHARE),
        "TOKORO_STATE_FILE": str(tmp / "etc/tier.conf"),
        "HOME": str(tmp / "home"),
    })
    return env


def run(cmd: list[str], env: dict) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=180)


def main() -> int:
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        env = fixture_home(tmp)
        # A tier state file, exactly like a machine that finished setup.
        (tmp / "etc/tier.conf").write_text(
            'TOKORO_TIER=quality\nTOKORO_RECOMMENDED=balanced\nTOKORO_OVERRIDE=1\n',
            encoding="utf-8")

        # --- status -----------------------------------------------------------
        result = run([str(EXEC / "tokoro-status"), "--json"], env)
        check("status: exits 0", result.returncode == 0, result.stderr.strip())
        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError as err:
            data = {}
            check("status: emits JSON", False, str(err))
        else:
            check("status: emits JSON", True)
        check("status: marked as a test feature", data.get("test_feature") is True)
        check("status: reads the stored tier", data.get("tier") == "quality",
              str(data.get("tier")))
        check("status: reports the recommendation", data.get("recommended") == "balanced")
        check("status: flags above-recommendation", data.get("above_recommendation") is True)
        check("status: AI is off by default", data.get("ai", {}).get("enabled") is False)
        for key in ("mode", "drivers", "benchmark", "updates", "version"):
            check(f"status: has {key}", key in data)

        human = run([str(EXEC / "tokoro-status")], env)
        check("status: human output", human.returncode == 0 and "tier" in human.stdout)

        # A corrupt tier value must not crash it.
        (tmp / "etc/tier.conf").write_text("TOKORO_TIER=banana\n", encoding="utf-8")
        broken = run([str(EXEC / "tokoro-status"), "--json"], env)
        check("status: survives a corrupt tier state", broken.returncode == 0,
              broken.stderr.strip())

        # --- report -----------------------------------------------------------
        out = tmp / "reports"
        report = run([str(EXEC / "tokoro-report"), "--out", str(out)], env)
        check("report: exits 0", report.returncode == 0, report.stderr.strip())
        archives = sorted(out.glob("tokoro-report-*.tar.gz"))
        check("report: writes one archive", len(archives) == 1, str(archives))
        if archives:
            with tarfile.open(archives[0]) as tar:
                members = {name.lstrip("./") for name in tar.getnames()}
            for expected in ("status.txt", "doctor.txt", "tier.txt", "ai.txt",
                             "hardware.json", "release.json", "system.txt"):
                check(f"report: contains {expected}", expected in members)
            # Nothing from the user's home may leak into a shared archive.
            check("report: no home paths", not any(name.startswith("home") for name in members))
            mode = archives[0].stat().st_mode & 0o777
            check("report: archive is private", mode & 0o077 == 0, oct(mode))

        # --- music ------------------------------------------------------------
        listing = run([str(EXEC / "tokoro-music"), "--list"], env)
        check("music: --list exits 0", listing.returncode == 0, listing.stderr.strip())
        for player in ("elisa", "strawberry", "amberol", "lollypop", "spotify"):
            check(f"music: lists {player}", player in listing.stdout)
        check("music: marks the configured default", "configured: elisa" in listing.stdout)

        opened = run([str(EXEC / "tokoro-music")], env)
        check("music: refuses a player that is not installed", opened.returncode == 1,
              opened.stdout.strip())
        check("music: prints the install line",
              "flatpak install --user flathub org.kde.elisa" in opened.stderr,
              opened.stderr.strip())

        # A configured swap must be honoured.
        (tmp / "etc/features.json").write_text(
            json.dumps({"schema": 1, "apps": {"music": "amberol"}}), encoding="utf-8")
        swapped = run([str(EXEC / "tokoro-music")], env)
        check("music: honours the configured swap",
              "io.bassi.Amberol" in swapped.stderr, swapped.stderr.strip())

        # --- usage ------------------------------------------------------------
        for command in ("tokoro-status", "tokoro-report"):
            help_run = run([str(EXEC / command), "--help"], env)
            check(f"{command}: has help", help_run.returncode == 0
                  and "TEST FEATURE" in help_run.stdout)

    print()
    if failures:
        print(f"{failures} of {total} checks failed")
        return 1
    print(f"all {total} checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
