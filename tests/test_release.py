#!/usr/bin/env python3
"""Version, codename and asset consistency across the repository."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
RECIPES = ["recipes/recipe.yml", "recipes/recipe-nvidia.yml"]
TIERS = ["ultra-performance", "performance", "balanced", "quality", "ultra-quality"]


def main() -> int:
    errors: list[str] = []
    release = json.loads(
        (ROOT / "files/system/usr/share/tokoro/release.json").read_text(encoding="utf-8"))

    for key in ("version", "series", "codename", "codename_slug", "tag_prefix"):
        if not release.get(key):
            errors.append(f"release.json missing {key}")

    version = release["version"]
    if not re_semver(version):
        errors.append(f"version {version!r} is not plain semver (expected e.g. 1.2.08)")

    for recipe in RECIPES:
        path = ROOT / recipe
        if not path.exists():
            errors.append(f"missing {recipe}")
            continue
        document = yaml.safe_load(path.read_text(encoding="utf-8"))
        tags = [str(tag) for tag in document.get("alt-tags", [])]
        for required in ("latest", version, release["series"], release["tag_prefix"]):
            if required not in tags:
                errors.append(f"{recipe}: alt-tags missing {required!r}")

        modules = document.get("modules", [])
        types = [module.get("type") for module in modules]
        if types and types[-1] != "signing":
            errors.append(f"{recipe}: signing must be the last module")
        if "files" not in types:
            errors.append(f"{recipe}: no files module (files/system would not be copied)")

        files_module = next((m for m in modules if m.get("type") == "files"), {})
        sources = [entry.get("source") for entry in files_module.get("files", [])]
        if "system" not in sources:
            errors.append(f"{recipe}: files module must copy source: system")

        os_release = next(
            (m.get("properties", {}) for m in modules if m.get("type") == "os-release"), {})
        if os_release.get("NAME") != "Tokoro OS":
            errors.append(f"{recipe}: os-release NAME must be 'Tokoro OS'")
        if version not in str(os_release.get("PRETTY_NAME", "")):
            errors.append(f"{recipe}: PRETTY_NAME does not contain {version}")
        if os_release.get("VERSION_CODENAME") != release["codename_slug"]:
            errors.append(f"{recipe}: VERSION_CODENAME must be {release['codename_slug']}")

        for module in modules:
            if module.get("type") != "script":
                continue
            for script in module.get("scripts", []):
                if not (ROOT / "files/scripts" / script).exists():
                    errors.append(f"{recipe}: script not found: files/scripts/{script}")

        labels = document.get("labels", {})
        if labels.get("org.opencontainers.image.version") != version:
            errors.append(f"{recipe}: image version label does not match {version}")

    # Tier assets referenced by the tier configs must exist.
    for tier in TIERS:
        conf = ROOT / f"files/system/usr/share/tokoro/tiers/{tier}.conf"
        if not conf.exists():
            errors.append(f"missing tier config {conf.relative_to(ROOT)}")
            continue
        text = conf.read_text(encoding="utf-8")
        wallpaper = ROOT / f"files/system/usr/share/tokoro/wallpapers/tokoro-{tier}.svg"
        sound = ROOT / f"files/system/usr/share/sounds/tokoro-{tier}/index.theme"
        if not wallpaper.exists():
            errors.append(f"{tier}: wallpaper missing")
        if not sound.exists():
            errors.append(f"{tier}: sound theme missing")
        if f"tokoro-{tier}.svg" not in text:
            errors.append(f"{tier}: conf does not reference its wallpaper")
        if release.get("tiers", {}).get(tier, {}).get("car", "") not in text + \
                json.dumps(release.get("tiers", {})):
            errors.append(f"{tier}: car name not recorded in release.json")

    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return 1
    print(f"ok: {version} ({release['codename']}) consistent across {len(RECIPES)} recipes")
    return 0


def re_semver(version: str) -> bool:
    parts = version.split(".")
    return len(parts) == 3 and all(part.isdigit() for part in parts)


if __name__ == "__main__":
    sys.exit(main())
