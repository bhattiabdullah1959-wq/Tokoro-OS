#!/usr/bin/env python3
"""Hardware detection maps synthetic machines to the expected tiers."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DETECT = ROOT / "files/system/usr/libexec/tokoro/tokoro-detect-hardware"

CASES = [
    {
        "name": "4-core iGPU laptop, 8 GB RAM",
        "cores": 4,
        "ram_gb": 8,
        "vram_gb": 0,
        "vendor": "0x8086",
        "expect": "performance",
    },
    {
        "name": "8-core, 8 GB dGPU, 16 GB RAM",
        "cores": 8,
        "ram_gb": 16,
        "vram_gb": 8,
        "vendor": "0x1002",
        "expect": "quality",
    },
    {
        "name": "16-core, 16 GB dGPU, 32 GB RAM",
        "cores": 16,
        "ram_gb": 32,
        "vram_gb": 16,
        "vendor": "0x10de",
        "expect": "ultra-quality",
    },
]


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def build_fixture(root: Path, case: dict) -> None:
    cpuinfo = [f"processor\t: {i}\n" for i in range(case["cores"])]
    cpuinfo.append(f"cpu cores\t: {case['cores']}\n")
    cpuinfo.append("model name\t: Tokoro Test CPU\n")
    write(root / "proc/cpuinfo", "".join(cpuinfo))
    write(root / "proc/meminfo", f"MemTotal: {case['ram_gb'] * 1024 * 1024} kB\n")
    write(root / "sys/class/drm/card0/device/vendor", case["vendor"] + "\n")
    if case["vram_gb"]:
        write(root / "sys/class/drm/card0/device/mem_info_vram_total",
              str(case["vram_gb"] * 1024**3) + "\n")
    write(root / "sys/class/dmi/id/sys_vendor", "TestVendor\n")
    write(root / "sys/class/dmi/id/product_name", "Test Machine\n")
    write(root / "sys/class/power_supply/BAT0/present", "1\n")


def run(root: Path, *args: str) -> subprocess.CompletedProcess:
    env = dict(os.environ)
    env["TOKORO_ROOT"] = str(root)
    return subprocess.run([sys.executable, str(DETECT), "--root", str(root), *args],
                          capture_output=True, text=True, env=env, timeout=60)


def main() -> int:
    failures = 0
    for case in CASES:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            build_fixture(root, case)
            result = run(root, "--json")
            if result.returncode != 0:
                print(f"FAIL: {case['name']}: detector exited {result.returncode}")
                failures += 1
                continue
            data = json.loads(result.stdout)
            tier = data["recommended_tier"]
            if tier != case["expect"]:
                print(f"FAIL: {case['name']}: expected {case['expect']}, got {tier} "
                      f"(score {data['score']}, breakdown {data['breakdown']})")
                failures += 1
                continue
            if data["is_laptop"] is not True:
                print(f"FAIL: {case['name']}: battery not detected")
                failures += 1
                continue
            print(f"ok: {case['name']} -> {tier} ({data['score']}/100)")

    # A missing DRM tree must still produce a sane answer, not a crash.
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        write(root / "proc/meminfo", "MemTotal: 16777216 kB\n")
        write(root / "proc/cpuinfo", "processor\t: 0\nprocessor\t: 1\n")
        result = run(root, "--tier")
        if result.returncode != 0 or not result.stdout.strip():
            print("FAIL: minimal fixture did not produce a tier")
            failures += 1
        else:
            print(f"ok: minimal fixture -> {result.stdout.strip()}")

    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
