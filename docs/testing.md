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
| `test_apps.py` | Every app slot is complete: default is one of its options, flatpak ids are well formed and unique, manual options have a homepage, and the music slot defaults to a local player |
| `test_wizard.py` | The wizard's `--dry-run --answers` plan is correct, including tier gating of smart home and that a dry run writes nothing |
| `test_games.py` | Dataset validates: unique ids, allowed ratings/weights, expected exclusions |
| `test_bench.py` | Benchmark scoring maps a synthetic machine to a tier and persists the result |
| `test_features.py` | The test features against a fixture install: `status` JSON, `report` archive contents and permissions, `music` list/refusal/swap |
| `test_media.py` | The music widget's helpers: MPRIS metadata parsing from Spotify-shaped `busctl` output, library indexing/cache, and level bars (simulated and `--available` agreement with cava) |
| `test_monitor.py` | System Overview's terminal view on a synthetic machine: CPU/RAM/GPU/disk numbers, the colour-coded file breakdown (including that symlinks are not followed), `--no-scan`, and rejection of a zero interval |
| `test_tokoro_apps.py` | The apps backend: kernel threads and other users' processes are skipped, green/yellow/red classes follow memory share, close/minimise/restore act only on your own processes (and refuse init), the KWin script is driven through D-Bus (never SIGSTOP, and a clean failure without a window manager), and startup entries list, disable and restore |
| `test_acer.sh` | Acer detection passes on an Acer laptop fixture and fails on Dell/desktop fixtures |
| `test_ai_caps.sh` | Each tier keeps exactly its documented AI abilities; refused commands fail before doing work; a missing runtime is reported missing; an above-recommendation tier is a warning (exit 3), never a refusal |

Plus `bash -n` on every shell script, `py_compile` on every Python tool, and
`shellcheck` when installed.

## What it cannot prove

- The image builds and boots. That requires the CI build and a VM boot.
- Rendering of the Plasma applets (no Plasma session here; the System Overview
  widget's tabs, menus and toggles are exercised only through their backend).
- KDE settings actually applying (no KWin here).
- Acer hardware behaviour, the Nitro key scan code, or the battery limiter.
- AI answers, screen capture or app launch (no runtime/model download here).
- The runtime download itself (`tokoro ai enable` needs ~1 GB of network).

Each of those is listed in the root README's status table and should be checked
on hardware with `tokoro doctor`.
