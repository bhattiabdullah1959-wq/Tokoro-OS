# Testing

```bash
bash tests/run-tests.sh
```

The suite needs `python3`, `jq`, and (if available) `shellcheck`. It runs
entirely against this repository: no root, no Tokoro install, no hardware.

## What is covered

| Test | Proves |
| --- | --- |
| `validate_recipes.py` | Both recipes validate against the published BlueBuild JSON schemas (skipped if offline) |
| `test_release.py` | Version/codename agree across `release.json`, both recipes, and their tags |
| `test_detect.py` | Hardware scoring maps three fixture machines to the expected tiers |
| `test_tier.sh` | Tier lookup, state parsing, above-recommendation detection, invalid tier rejection |
| `test_banner.sh` | The banner script rewrites a real-shaped ublue template and is idempotent |
| `test_wizard.py` | The wizard's `--dry-run --answers` plan is correct, including tier gating of smart home |
| `test_games.py` | Dataset validates: unique ids, allowed ratings/weights, expected exclusions |
| `test_acer.sh` | Acer detection passes on an Acer laptop fixture and fails on Dell/desktop fixtures |

Plus `bash -n` on every shell script, `py_compile` on every Python tool, and
`shellcheck` when installed.

## What it cannot prove

- The image builds and boots. That requires the CI build and a VM boot.
- Rendering of the Plasma applet (no Plasma session here).
- KDE settings actually applying (no KWin here).
- Acer hardware behaviour, the Nitro key scan code, or the battery limiter.
- AI answers (no runtime/model download here).

Each of those is listed in the root README's status table and should be checked
on hardware with `tokoro doctor`.
