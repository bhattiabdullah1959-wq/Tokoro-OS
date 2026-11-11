#!/usr/bin/env python3
"""tokoro-monitor reports component usage and a colour-coded storage breakdown."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MONITOR = ROOT / "files/system/usr/libexec/tokoro/tokoro-monitor"

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


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def build_fixture(root: Path) -> None:
    # 8 cores: 100 busy jiffies vs 300 idle each, so usage is ~25%.
    lines = ["cpu  800 0 0 2400 0 0 0 0 0 0"]
    for core in range(8):
        lines.append(f"cpu{core} 100 0 0 300 0 0 0 0 0 0")
    write(root / "proc/stat", "\n".join(lines) + "\n")
    write(root / "proc/loadavg", "0.42 0.51 0.63 2/531 9876\n")
    cpuinfo = ["processor\t: 0", "model name\t: Tokoro Test CPU", "cpu cores\t: 8"]
    for thread in range(1, 16):
        cpuinfo.append(f"processor\t: {thread}")
    write(root / "proc/cpuinfo", "\n".join(cpuinfo) + "\n")
    write(root / "proc/meminfo",
          "MemTotal:       16777216 kB\n"
          "MemFree:         2097152 kB\n"
          "MemAvailable:    8388608 kB\n"
          "Buffers:          524288 kB\n"
          "Cached:          4194304 kB\n"
          "SwapTotal:       8388608 kB\n"
          "SwapFree:        7340032 kB\n")
    # A real GPU-shaped sysfs card: 8 GiB total, 2 GiB used.
    device = root / "sys/class/drm/card0/device"
    write(device / "vendor", "0x1002\n")
    write(device / "mem_info_vram_total", str(8 * 1024 ** 3))
    write(device / "mem_info_vram_used", str(2 * 1024 ** 3))


def build_scan(target: Path) -> dict[str, int]:
    sizes = {
        "holiday.png": 1000,
        "clip.mp4": 2000,
        "song.flac": 500,
        "notes.txt": 100,
        "backup.zip": 300,
        "firmware.bin": 50,
    }
    for name, size in sizes.items():
        path = target / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"\0" * size)
    (target / "sub").mkdir()
    (target / "sub" / "more.jpg").write_bytes(b"\0" * 400)
    # A symlink must be ignored, not followed.
    os.symlink(target / "holiday.png", target / "link.png")
    return sizes


def main() -> int:
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        build_fixture(tmp)
        scan_dir = tmp / "media"
        scan_dir.mkdir()
        build_scan(scan_dir)

        env = os.environ.copy()
        env["PYTHONPATH"] = ""
        base = [sys.executable, str(MONITOR), "--root", str(tmp),
                "--scan", str(scan_dir), "--top", "5"]

        # --- JSON snapshot ----------------------------------------------------
        result = subprocess.run([*base, "--json"], capture_output=True,
                                text=True, timeout=120, env=env)
        check("monitor: --json exits 0", result.returncode == 0, result.stderr.strip())
        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError as err:
            data = {}
            check("monitor: emits JSON", False, f"{err}: {result.stdout[:200]}")
        else:
            check("monitor: emits JSON", True)

        check("monitor: marked as a test feature", data.get("test_feature") is True)
        cpu = data.get("cpu", {})
        check("monitor: reads the CPU model", cpu.get("model") == "Tokoro Test CPU")
        check("monitor: counts cores", cpu.get("cores") == 8, str(cpu.get("cores")))
        check("monitor: counts threads", cpu.get("threads") == 16, str(cpu.get("threads")))
        check("monitor: CPU usage is plausible",
              isinstance(cpu.get("usage"), (int, float)) and 0 <= cpu["usage"] <= 100,
              str(cpu.get("usage")))
        check("monitor: per-core list matches core count",
              len(cpu.get("per_core", [])) == 8, str(cpu.get("per_core")))
        check("monitor: reads load average", cpu.get("load", [])[:3] == ["0.42", "0.51", "0.63"])

        mem = data.get("memory", {})
        check("monitor: RAM total in GB", mem.get("total_gb") == 16.0, str(mem.get("total_gb")))
        check("monitor: RAM used in GB", mem.get("used_gb") == 8.0, str(mem.get("used_gb")))
        check("monitor: RAM percentage", mem.get("percent") == 50.0, str(mem.get("percent")))
        check("monitor: swap total", mem.get("swap_total_gb") == 8.0)
        check("monitor: swap used", mem.get("swap_used_gb") == 1.0, str(mem.get("swap_used_gb")))

        gpu = (data.get("gpus") or [{}])[0]
        check("monitor: detects the GPU vendor", gpu.get("vendor") == "AMD", str(gpu))
        check("monitor: VRAM total", gpu.get("vram_total_mb") == 8192)
        check("monitor: VRAM used", gpu.get("vram_used_mb") == 2048)

        storage = data.get("storage", {})
        check("monitor: reports disk total", storage.get("total_gb", 0) > 0)
        check("monitor: reports disk free", storage.get("free_gb", 0) > 0)
        check("monitor: disk used + free <= total",
              storage.get("used_gb", 0) + storage.get("free_gb", 1)
              <= storage.get("total_gb", 0) + 0.2)

        breakdown = {entry["key"]: entry for entry in storage.get("breakdown", [])}
        expected = {"photos": 1400, "videos": 2000, "audio": 500,
                    "documents": 100, "archives": 300, "other": 50}
        for key, size in expected.items():
            actual = breakdown.get(key, {}).get("bytes")
            check(f"monitor: {key} bytes", actual == size, str(actual))
        check("monitor: every category present",
              set(breakdown) == set(expected), str(sorted(breakdown)))
        total_scanned = sum(entry["bytes"] for entry in breakdown.values())
        check("monitor: breakdown covers the scanned bytes",
              total_scanned == storage.get("bytes_scanned"), str(total_scanned))
        check("monitor: shares sum to ~100",
              abs(sum(entry["share"] for entry in breakdown.values()) - 100.0) < 0.5)
        check("monitor: symlinks are not followed",
              breakdown.get("photos", {}).get("bytes") == 1400)
        check("monitor: scan is marked complete", storage.get("scan_complete") is True)
        check("monitor: processes key exists", "processes" in data)

        # --- human output -----------------------------------------------------
        human = subprocess.run([*base, "--no-color"], capture_output=True,
                               text=True, timeout=120, env=env)
        check("monitor: human output exits 0", human.returncode == 0, human.stderr.strip())
        for label in ("CPU", "RAM", "GPU", "Disk", "Photos", "Videos", "Music",
                      "Files", "Archives", "Other"):
            check(f"monitor: shows {label}", label in human.stdout)
        check("monitor: shows free space", "free" in human.stdout.lower())
        check("monitor: no ANSI codes with --no-color", "\033[" not in human.stdout)

        # --- guard rails ------------------------------------------------------
        bad_interval = subprocess.run([*base, "--interval", "0"], capture_output=True,
                                      text=True, timeout=60, env=env)
        check("monitor: rejects a zero interval", bad_interval.returncode != 0)

        no_scan = subprocess.run([*base, "--json", "--no-scan"], capture_output=True,
                                 text=True, timeout=60, env=env)
        check("monitor: --no-scan still works", no_scan.returncode == 0
              and json.loads(no_scan.stdout)["storage"]["breakdown"] == [])

    print()
    if failures:
        print(f"{failures} of {total} checks failed")
        return 1
    print(f"all {total} checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
