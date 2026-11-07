#!/usr/bin/env python3
"""Validate both recipes against the published BlueBuild JSON schemas."""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urljoin

import yaml

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://schema.blue-build.org/"
RECIPES = ["recipes/recipe.yml", "recipes/recipe-nvidia.yml"]


def fetch(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def collect_refs(node, found: set[str]) -> None:
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "$ref" and isinstance(value, str):
                found.add(value)
            else:
                collect_refs(value, found)
    elif isinstance(node, list):
        for item in node:
            collect_refs(item, found)


def main() -> int:
    try:
        from jsonschema import Draft202012Validator, RefResolver
    except ImportError:
        print("SKIP: jsonschema is not installed (pip install jsonschema)")
        return 0

    try:
        store: dict[str, dict] = {}
        pending = ["recipe-v1.json"]
        while pending:
            path = pending.pop()
            url = urljoin(BASE, path)
            if url in store:
                continue
            document = fetch(url)
            store[url] = document
            refs: set[str] = set()
            collect_refs(document, refs)
            for ref in refs:
                target = urljoin(url, ref)
                if target.startswith(BASE) and target not in store:
                    pending.append(target[len(BASE):])
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(f"SKIP: cannot reach schema.blue-build.org ({exc})")
        return 0
    except json.JSONDecodeError as exc:
        print(f"FAIL: schema site returned invalid JSON ({exc})")
        return 1

    schema_url = urljoin(BASE, "recipe-v1.json")
    resolver = RefResolver(base_uri=schema_url, referrer=store[schema_url], store=store)
    validator = Draft202012Validator(store[schema_url], resolver=resolver)

    problems = 0
    for recipe in RECIPES:
        path = ROOT / recipe
        if not path.exists():
            print(f"FAIL: missing {recipe}")
            problems += 1
            continue
        with open(path, encoding="utf-8") as fh:
            document = yaml.safe_load(fh)
        errors = sorted(validator.iter_errors(document), key=lambda e: list(e.path))
        if errors:
            problems += len(errors)
            for error in errors:
                location = "/".join(str(part) for part in error.path) or "<root>"
                print(f"FAIL: {recipe}: {location}: {error.message}")
        else:
            print(f"ok: {recipe} validates")

    return 0 if problems == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
