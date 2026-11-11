#!/usr/bin/env python3
"""The wizard's non-interactive plan, including tier gating."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WIZARD = ROOT / "files/system/usr/libexec/tokoro/tokoro-wizard"
SHARE = ROOT / "files/system/usr/share/tokoro"
EXEC = ROOT / "files/system/usr/libexec/tokoro"


def plan_for(answers: dict, tmp: Path) -> dict:
    answers_path = tmp / "answers.json"
    answers_path.write_text(json.dumps(answers), encoding="utf-8")
    env = dict(os.environ)
    env.update({
        "TOKORO_SHARE": str(SHARE),
        "TOKORO_EXEC": str(EXEC),
        "TOKORO_ETC": str(tmp / "etc"),
        "TOKORO_STATE_FILE": str(tmp / "etc/tier.conf"),
        "TOKORO_USER_CONFIG": str(tmp / "config"),
        "XDG_STATE_HOME": str(tmp / "state"),
    })
    result = subprocess.run(
        [sys.executable, str(WIZARD), "--dry-run", "--cli",
         "--answers", str(answers_path), "--state-dir", str(tmp / "state")],
        capture_output=True, text=True, env=env, timeout=120)
    if result.returncode != 0:
        raise AssertionError(f"wizard failed ({result.returncode}):\n{result.stdout}\n{result.stderr}")
    marker = "\n{\n"
    index = result.stdout.rindex(marker)
    return json.loads(result.stdout[index + 1:])


def main() -> int:
    failures = 0

    with tempfile.TemporaryDirectory() as raw:
        tmp = Path(raw)
        plan = plan_for({
            "tier": "balanced",
            "ai": True,
            "smart_home": True,  # must be gated off: balanced is below quality
            "acer_battery_limit": True,
            "apps": {"browser": "chrome", "music": "strawberry"},
        }, tmp)
        checks = [
            ("tier honoured", plan["tier"] == "balanced"),
            ("smart home gated off below Quality", plan["features"]["smart_home"] is False),
            ("AI plan recorded", plan["features"]["ai"] is True),
            ("browser swap honoured", plan["apps"]["browser"] == "chrome"),
            ("untouched slots use defaults", plan["apps"]["chat"] == "vencord"),
            ("music swap honoured", plan["apps"]["music"] == "strawberry"),
            ("AI model defaults to auto", plan["ai_model"] == "auto"),
            ("hardware block present", isinstance(plan["hardware"].get("score"), int)),
        ]
        for name, ok in checks:
            if ok:
                print(f"ok: {name}")
            else:
                print(f"FAIL: {name} (plan: {json.dumps(plan)})")
                failures += 1

    with tempfile.TemporaryDirectory() as raw:
        tmp = Path(raw)
        plan = plan_for({
            "tier": "ultra-quality",
            "ai": False,
            "smart_home": True,
            "apps": {"launcher": "prism", "world_tools": "mca-selector"},
        }, tmp)
        checks = [
            ("smart home allowed on Ultra Quality", plan["features"]["smart_home"] is True),
            ("AI can be declined", plan["features"]["ai"] is False),
            ("launcher swap honoured", plan["apps"]["launcher"] == "prism"),
            ("music falls back to the local default", plan["apps"]["music"] == "elisa"),
            ("world tool default", plan["apps"]["world_tools"] == "mca-selector"),
        ]
        for name, ok in checks:
            if ok:
                print(f"ok: {name}")
            else:
                print(f"FAIL: {name} (plan: {json.dumps(plan)})")
                failures += 1

    # AI is opt-in: an answer file that never mentions it must leave it off, so
    # setup downloads no runtime.
    with tempfile.TemporaryDirectory() as raw:
        tmp = Path(raw)
        plan = plan_for({"tier": "quality"}, tmp)
        checks = [
            ("AI is opt-in (off unless asked)", plan["features"]["ai"] is False),
            ("AI model stays auto when AI is off", plan["ai_model"] == "auto"),
        ]
        for name, ok in checks:
            if ok:
                print(f"ok: {name}")
            else:
                print(f"FAIL: {name} (plan: {json.dumps(plan)})")
                failures += 1

    # A dry run must not write system state: no plan file, no tier state.
    with tempfile.TemporaryDirectory() as raw:
        tmp = Path(raw)
        plan_for({"tier": "balanced"}, tmp)
        written = sorted(p.name for p in (tmp / "state").rglob("*") if p.is_file()) \
            if (tmp / "state").exists() else []
        checks = [
            ("dry run writes no plan file", not (tmp / "state/firstboot-plan.json").exists()),
            ("dry run leaves the state dir empty", written == []),
            ("dry run writes no tier state", not (tmp / "etc/tier.conf").exists()),
        ]
        for name, ok in checks:
            if ok:
                print(f"ok: {name}")
            else:
                print(f"FAIL: {name} (wrote: {written})")
                failures += 1

    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
