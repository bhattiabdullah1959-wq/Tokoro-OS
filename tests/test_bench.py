#!/usr/bin/env python3
"""The benchmark must produce a bounded, self-consistent score."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BENCH = ROOT / "files/system/usr/libexec/tokoro/tokoro-bench"
TIERS = ["ultra-performance", "performance", "balanced", "quality", "ultra-quality"]


def main() -> int:
    failures = 0
    with tempfile.TemporaryDirectory() as tmp:
        env = dict(os.environ)
        env.update({
            "TOKORO_EXEC": str(ROOT / "files/system/usr/libexec/tokoro"),
            "TOKORO_SHARE": str(ROOT / "files/system/usr/share/tokoro"),
            "TOKORO_STATE_FILE": str(Path(tmp) / "tier.conf"),
            "XDG_STATE_HOME": tmp,
        })
        result = subprocess.run(
            [sys.executable, str(BENCH), "run", "--quick", "--json"],
            capture_output=True, text=True, env=env, timeout=300)
        if result.returncode != 0:
            print(f"FAIL: benchmark exited {result.returncode}\n{result.stdout}\n{result.stderr}")
            return 1
        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError as exc:
            print(f"FAIL: benchmark output is not JSON ({exc})")
            return 1

        checks = [
            ("score within 0-100", 0 <= data.get("score", -1) <= 100),
            ("tier is valid", data.get("can_carry_tier") in TIERS),
            ("cpu measured", data.get("cpu", {}).get("single", 0) > 0),
            ("multi-core at least as fast as single", data["cpu"]["multi"] >= data["cpu"]["single"]),
            ("memory measured", data.get("memory_gbps", 0) > 0),
            ("disk measured even in quick mode", data.get("disk_mbps", 0) > 0),
            ("gpu component bounded", 0 <= data.get("gpu_points", -1) <= 30),
            ("hardware tier reported", data.get("hardware_tier") in TIERS),
        ]
        for name, ok in checks:
            if ok:
                print(f"ok: {name}")
            else:
                print(f"FAIL: {name} -> {json.dumps(data)}")
                failures += 1

        saved = Path(tmp) / "tokoro" / "bench" / "last.json"
        if saved.exists():
            print("ok: result persisted for tokoro doctor")
        else:
            print(f"FAIL: result not saved to {saved}")
            failures += 1

    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
