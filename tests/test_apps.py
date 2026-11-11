#!/usr/bin/env python3
"""Every app slot in apps.json is complete and installable.

A slot that points at a flatpak id that does not exist, or a default that is not
one of its options, fails silently at first boot: the user picks "Music" and
nothing appears. This checks the data, not the download.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPS = ROOT / "files/system/usr/share/tokoro/wizard/apps.json"
SLUG = re.compile(r"^[a-z0-9][a-z0-9-]*$")
FLATPAK = re.compile(r"^[A-Za-z][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+)+$")
REPO = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")

REQUIRED_SLOTS = {"browser", "chat", "music", "launcher", "world_tools"}


def main() -> int:
    data = json.loads(APPS.read_text(encoding="utf-8"))
    slots = data.get("slots", {})
    failures: list[str] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        if ok:
            print(f"ok: {name}")
        else:
            print(f"FAIL: {name}{(' — ' + detail) if detail else ''}")
            failures.append(name)

    check("schema is 1", data.get("schema") == 1, str(data.get("schema")))
    check("all required slots present", REQUIRED_SLOTS <= set(slots),
          f"missing {sorted(REQUIRED_SLOTS - set(slots))}")

    seen_flatpaks: dict[str, str] = {}
    for slot, spec in slots.items():
        options = spec.get("options") or []
        ids = [option.get("id") for option in options]
        check(f"{slot}: labelled", bool(spec.get("label")))
        check(f"{slot}: has options", len(options) >= 2, f"{len(options)} option(s)")
        check(f"{slot}: default is one of its options", spec.get("default") in ids,
              f"default {spec.get('default')!r} not in {ids}")
        check(f"{slot}: option ids unique", len(ids) == len(set(ids)), str(ids))

        for option in options:
            oid = str(option.get("id", ""))
            where = f"{slot}/{oid}"
            check(f"{where}: slug", bool(SLUG.match(oid)), oid)
            check(f"{where}: has a name", bool(option.get("name")))
            kind = option.get("kind")
            check(f"{where}: known kind", kind in {"flatpak", "manual", "github_jar"}, str(kind))
            if kind == "flatpak":
                app_id = str(option.get("flatpak", ""))
                check(f"{where}: flatpak id", bool(FLATPAK.match(app_id)), app_id)
                check(f"{where}: flatpak id unique", app_id not in seen_flatpaks,
                      f"also used by {seen_flatpaks.get(app_id)}")
                seen_flatpaks[app_id] = where
            elif kind == "github_jar":
                check(f"{where}: github repo", bool(REPO.match(str(option.get("repo", "")))),
                      str(option.get("repo")))
                check(f"{where}: asset suffix",
                      str(option.get("asset_suffix", "")).startswith("."),
                      str(option.get("asset_suffix")))
            elif kind == "manual":
                check(f"{where}: homepage",
                      str(option.get("homepage", "")).startswith("https://"),
                      str(option.get("homepage")))

    # The music slot is what the user asked for: a working local player first.
    music = slots.get("music", {})
    music_ids = [option.get("id") for option in music.get("options", [])]
    default = music.get("default")
    default_option = next((o for o in music.get("options", []) if o.get("id") == default), {})
    check("music: default exists", default in music_ids, str(default))
    check("music: default is a flatpak", default_option.get("kind") == "flatpak",
          str(default_option.get("kind")))
    check("music: local players offered",
          {"elisa", "strawberry", "amberol"} <= set(music_ids), str(music_ids))
    check("music: local default is a KDE app", default == "elisa", str(default))
    check("music: streaming is not the default", default != "spotify", str(default))

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
