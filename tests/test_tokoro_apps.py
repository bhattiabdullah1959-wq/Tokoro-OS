#!/usr/bin/env python3
"""System Overview app list, resource colours, app actions and startup apps."""
from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "files/system/usr/libexec/tokoro/tokoro-apps"

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


def stat_line(pid: int, comm: str, state: str = "S", ppid: int = 1,
              utime: int = 0, stime: int = 0) -> str:
    fields = [state, str(ppid), "0", "0", "0", "0", "0", "0", "0", "0", "0",
              str(utime), str(stime)]
    return f"{pid} ({comm}) " + " ".join(fields) + " 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0\n"


def add_process(root: Path, pid: int, comm: str, kb: int, uid: int,
                command: str, executable: str, state: str = "S") -> None:
    directory = root / "proc" / str(pid)
    write(directory / "stat", stat_line(pid, comm, state=state))
    write(directory / "status",
          f"Name:\t{comm}\nUid:\t{uid}\t{uid}\t{uid}\t{uid}\nVmRSS:\t{kb} kB\n")
    (directory / "cmdline").write_bytes(command.encode() .replace(b" ", b"\0") + b"\0")
    link = directory / "exe"
    if not link.exists():
        try:
            os.symlink(executable, link)
        except OSError:
            pass


def run(args: list[str], homepage: str = "") -> subprocess.CompletedProcess:
    env = os.environ.copy()
    if homepage:
        env["HOME"] = homepage
    return subprocess.run([sys.executable, str(TOOL), *args], env=env,
                          capture_output=True, text=True, timeout=60)


def main() -> int:
    uid = os.getuid()
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        fake_root = tmp / "root"
        add_process(fake_root, 100, "firefox", 400 * 1024, uid, "/usr/bin/firefox https://x",
                    "/usr/bin/firefox")
        add_process(fake_root, 101, "code", 80 * 1024, uid, "/usr/bin/code", "/usr/bin/code")
        add_process(fake_root, 102, "mpv", 40 * 1024, uid, "/usr/bin/mpv video.mkv",
                    "/usr/bin/mpv")
        add_process(fake_root, 103, "bash", 10 * 1024, uid, "/usr/bin/bash", "/usr/bin/bash")
        # A kernel thread (no command line) and another user's process.
        add_process(fake_root, 2, "kthreadd", 0, 0, "", "/usr/bin/kthreadd")
        add_process(fake_root, 104, "other", 900 * 1024, uid + 1, "/usr/bin/other",
                    "/usr/bin/other")

        desktop = tmp / "applications"
        write(desktop / "firefox.desktop",
              "[Desktop Entry]\nName=Firefox Web Browser\nExec=/usr/bin/firefox %u\n")
        write(desktop / "code.desktop",
              "[Desktop Entry]\nName=Visual Studio Code\nExec=/usr/bin/code %F\n")

        common = ["--root", str(fake_root), "--uid", str(uid), "--interval", "0",
                  "--desktop-dir", str(desktop)]
        listed = run(["list", "--json", *common])
        check("apps: exits 0", listed.returncode == 0, listed.stderr.strip())
        try:
            payload = json.loads(listed.stdout)
        except json.JSONDecodeError as err:
            payload = {}
            check("apps: emits JSON", False, str(err))
        else:
            check("apps: emits JSON", True)
        apps = {app["executable"]: app for app in payload.get("apps", [])}
        check("apps: marked as a test feature", payload.get("test_feature") is True)
        check("apps: finds the user's processes", set(apps) == {"firefox", "code", "mpv", "bash"},
              str(sorted(apps)))
        check("apps: skips kernel threads", "kthreadd" not in apps)
        check("apps: skips other users", "other" not in apps)
        check("apps: maps the desktop name", apps.get("firefox", {}).get("name")
              == "Firefox Web Browser", str(apps.get("firefox", {}).get("name")))
        check("apps: reports memory", apps.get("firefox", {}).get("rss_mb") == 400.0,
              str(apps.get("firefox", {}).get("rss_mb")))

        # 400/530 MB is 75% of the user's memory, 80/530 is 15%, the rest is small.
        check("apps: the heaviest app is red", apps.get("firefox", {}).get("class") == "red",
              str(apps.get("firefox", {}).get("class")))
        check("apps: a medium app is yellow", apps.get("code", {}).get("class") == "yellow",
              str(apps.get("code", {}).get("class")))
        check("apps: light apps are green", apps.get("mpv", {}).get("class") == "green",
              str(apps.get("mpv", {}).get("class")))
        check("apps: sorted by memory",
              [app["executable"] for app in payload.get("apps", [])][0] == "firefox")

        human = run(["list", *common])
        check("apps: human output names the view", "System Overview" in human.stdout)
        check("apps: human output lists the apps", "Firefox Web Browser" in human.stdout)

        # --- startup ----------------------------------------------------------
        config = tmp / "config"
        etc = tmp / "etc-autostart"
        write(etc / "alpha.desktop", "[Desktop Entry]\nName=Alpha\nExec=/bin/alpha\n")
        write(config / "autostart/beta.desktop",
              "[Desktop Entry]\nName=Beta\nExec=/bin/beta\nHidden=true\n")
        startup_args = ["startup", "--config-home", str(config), "--etc-dir", str(etc)]
        entries = run([*startup_args, "--json"])
        check("startup: exits 0", entries.returncode == 0, entries.stderr.strip())
        states = {entry["id"]: entry for entry in json.loads(entries.stdout or "{}").get("startup", [])}
        check("startup: lists both apps", set(states) == {"alpha", "beta"}, str(sorted(states)))
        check("startup: system entry is on", states.get("alpha", {}).get("enabled") is True)
        check("startup: hidden user entry is off", states.get("beta", {}).get("enabled") is False)

        disabled = run([*startup_args, "disable", "alpha"])
        check("startup: disable exits 0", disabled.returncode == 0, disabled.stderr.strip())
        override = config / "autostart/alpha.desktop"
        check("startup: disable writes a user override", override.is_file())
        check("startup: override hides the app",
              "Hidden=true" in override.read_text(encoding="utf-8") if override.is_file() else False)
        after_off = run([*startup_args, "--json"])
        states = {entry["id"]: entry for entry in json.loads(after_off.stdout).get("startup", [])}
        check("startup: app now reads as off", states.get("alpha", {}).get("enabled") is False)

        enabled = run([*startup_args, "enable", "alpha"])
        check("startup: enable exits 0", enabled.returncode == 0, enabled.stderr.strip())
        check("startup: enable removes the override", not override.exists())
        after_on = run([*startup_args, "--json"])
        states = {entry["id"]: entry for entry in json.loads(after_on.stdout).get("startup", [])}
        check("startup: app is on again", states.get("alpha", {}).get("enabled") is True)

        unknown = run([*startup_args, "disable", "nope"])
        check("startup: refuses an unknown app", unknown.returncode != 0)

        # --- actions ----------------------------------------------------------
        refusing = run(["close", "1"])
        check("close: refuses init", refusing.returncode != 0 and "init" in refusing.stderr,
              refusing.stderr.strip())

        child = subprocess.Popen(["/bin/sleep", "60"])
        try:
            time.sleep(0.2)
            # No Plasma here, so KWin is stubbed: the tool must go through the
            # window manager and never freeze the process.
            stubs = tmp / "kwin-bin"
            stubs.mkdir()
            busctl = stubs / "busctl"
            busctl.write_text(
                "#!/bin/sh\n"
                f'echo "$*" >> {tmp}/busctl.log\n'
                f'case "$*" in *loadScript*) cp "$8" {tmp}/kwin-script.js ;; esac\n'
                "echo 'i 0'\n",
                encoding="utf-8")
            busctl.chmod(0o755)
            kwin_env = dict(os.environ, PATH=f"{stubs}:{os.environ.get('PATH', '')}")

            hidden = subprocess.run([sys.executable, str(TOOL), "background", str(child.pid)],
                                    env=kwin_env, capture_output=True, text=True, timeout=60)
            check("background: exits 0 with a window manager", hidden.returncode == 0,
                  hidden.stderr.strip())
            script = (tmp / "kwin-script.js").read_text(encoding="utf-8") \
                if (tmp / "kwin-script.js").exists() else ""
            check("background: asks KWin to minimise the window",
                  f"const targetPid = {child.pid};" in script
                  and "win.minimized = true" in script, script[:120])
            check("background: does not freeze the process", "SIGSTOP" not in script)
            log = (tmp / "busctl.log").read_text(encoding="utf-8") if (tmp / "busctl.log").exists() else ""
            check("background: drives the KWin scripting interface",
                  "org.kde.kwin.Scripting loadScript" in log and "org.kde.kwin.Script run" in log, log[:160])
            raw = Path(f"/proc/{child.pid}/stat").read_text(encoding="utf-8")
            check("background: process keeps running", raw[raw.rfind(")") + 2] in "SR",
                  raw[raw.rfind(")") + 2])

            (tmp / "kwin-script.js").unlink(missing_ok=True)
            resumed = subprocess.run([sys.executable, str(TOOL), "resume", str(child.pid)],
                                     env=kwin_env, capture_output=True, text=True, timeout=60)
            check("resume: exits 0", resumed.returncode == 0, resumed.stderr.strip())
            script = (tmp / "kwin-script.js").read_text(encoding="utf-8") \
                if (tmp / "kwin-script.js").exists() else ""
            check("resume: asks KWin to restore the window",
                  "win.minimized = false" in script, script[:120])

            # Without a window manager the command must fail clearly, not freeze.
            no_kwin = run(["background", str(child.pid)])
            check("background: fails cleanly without KWin",
                  no_kwin.returncode != 0 and "window manager" in no_kwin.stderr,
                  no_kwin.stderr.strip()[:120])
            raw = Path(f"/proc/{child.pid}/stat").read_text(encoding="utf-8")
            check("background: never frozen as a fallback", raw[raw.rfind(")") + 2] in "SR",
                  raw[raw.rfind(")") + 2])

            closed = run(["close", str(child.pid)])
            check("close: exits 0", closed.returncode == 0, closed.stderr.strip())
            check("close: process is gone", child.poll() is not None
                  or not Path(f"/proc/{child.pid}").exists())
        finally:
            if child.poll() is None:
                child.send_signal(signal.SIGKILL)
                child.wait()

        # `tokoro apps` must route to this tool through the front door.
        routed_env = os.environ.copy()
        routed_env.update({
            "TOKORO_EXEC": str(TOOL.parent),
            "TOKORO_SHARE": str(ROOT / "files/system/usr/share/tokoro"),
            "TOKORO_ETC": str(tmp / "etc"),
            "TOKORO_STATE": str(tmp / "state"),
        })
        routed = subprocess.run(
            ["/bin/bash", str(ROOT / "files/system/usr/bin/tokoro"), "apps", "list",
             "--json", *common],
            env=routed_env, capture_output=True, text=True, timeout=60)
        check("dispatcher: `tokoro apps` routes", routed.returncode == 0
              and '"apps"' in routed.stdout, routed.stderr.strip()[:200])

        help_run = run(["--help"])
        check("apps: has help", help_run.returncode == 0 and "System Overview" in help_run.stdout)

    print()
    if failures:
        print(f"{failures} of {total} checks failed")
        return 1
    print(f"all {total} checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
