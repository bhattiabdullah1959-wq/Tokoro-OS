# Architecture

## Build layers

```
recipes/recipe.yml          tokoro-os image, AMD/Intel (base: bazzite:stable)
recipes/recipe-nvidia.yml   tokoro-os-nvidia image (base: bazzite-nvidia:stable)
files/system/               copied verbatim to / by the files module
files/scripts/              build-time scripts, run in this order
.github/workflows/build.yml builds both recipes, signs with cosign
```

Build scripts run in order and are defensive: a missing upstream file produces a
warning, never a half-branded image.

| Script | Responsibility |
| --- | --- |
| `00-preflight.sh` | Verifies assumptions about the base image and tooling |
| `10-branding.sh` | os-release/version metadata, KDE assets, upstream name cleanup |
| `20-terminal-banner.sh` | Rewrites every banner surface to Tokoro OS |
| `30-ai-runtime.sh` | Prepares AI directories only; the runtime downloads on first opt-in |
| `40-acer-support.sh` | Verifies Acer units/rules/helpers and the hardware gate |
| `50-release-metadata.sh` | `/etc/tokoro/version`, `/etc/issue`, release.json copy |

## Runtime layout

```
/usr/bin/tokoro                      dispatcher for every tool
/usr/libexec/tokoro/tokoro-lib.sh    shared paths, tier + state helpers
/usr/libexec/tokoro/tokoro-detect-hardware   sysfs/DMI scoring (Python)
/usr/libexec/tokoro/tokoro-tier      tier engine (bash)
/usr/libexec/tokoro/tokoro-mode      work/gaming toggle
/usr/libexec/tokoro/tokoro-wizard    first-boot wizard (Python, kdialog/CLI)
/usr/libexec/tokoro/tokoro-ai        local AI control (tier-gated abilities)
/usr/libexec/tokoro/tokoro-ai-runtime  downloads/removes the runtime on demand
/usr/libexec/tokoro/tokoro-ai-serve  service entry point for the runtime
/usr/libexec/tokoro/tokoro-drivers   missing-driver and firmware scan
/usr/libexec/tokoro/tokoro-fileguard file-safety explanations
/usr/libexec/tokoro/tokoro-games     compatibility database CLI
/usr/libexec/tokoro/tokoro-bench     benchmark + gaming mode
/usr/libexec/tokoro/tokoro-smarthome KIRA BLE scenes (tier gated)
/usr/libexec/tokoro/tokoro-acer      Acer Nitro V controls (hardware gated)
/usr/libexec/tokoro/tokoro-doctor    self-check, including the banner
/usr/libexec/tokoro/tokoro-status    one-screen health summary (test feature)
/usr/libexec/tokoro/tokoro-monitor   task manager + storage breakdown (test feature)
/usr/libexec/tokoro/tokoro-report    diagnostics bundle for bug reports (test feature)
/usr/libexec/tokoro/tokoro-music     opens the player chosen during setup (test feature)
/usr/libexec/tokoro/tokoro-nowplaying MPRIS read/control for the widget (test feature)
/usr/libexec/tokoro/tokoro-library   local music index for the widget (test feature)
/usr/libexec/tokoro/tokoro-levels    level bars, real via cava or a pulse (test feature)
/usr/share/plasma/plasmoids/org.tokoro.nowplaying  the music panel widget
/usr/share/tokoro/tiers/*.conf       one file per tier (shell-sourced)
/usr/share/tokoro/release.json       version + car codenames (single source)
/usr/share/tokoro/games/games.json   compatibility dataset
/usr/share/tokoro/ai/models.json     the five AI models and tier mapping
/usr/share/tokoro/ai/capabilities.json  which abilities each tier keeps
```

## State

| Path | Owner | Purpose |
| --- | --- | --- |
| `/etc/tokoro/tier.conf` | root | current tier, recommendation, override flag |
| `/etc/tokoro/features.json` | root | wizard result (features, apps) |
| `/etc/tokoro/ai.json` | root | AI enabled + active model |
| `/var/lib/tokoro/ai/runtime` | root | Ollama, downloaded the first time AI is turned on |
| `/var/lib/tokoro/ai/models` | root | downloaded models (kept when AI is turned off) |
| `~/.config/tokoro/tier.json` | user | applet state, passive warning flag |
| `~/.config/tokoro/mode` | user | `work` or `gaming` |
| `~/.local/state/tokoro/bench/last.json` | user | last benchmark result |

`/etc` persists across atomic updates, so a user's tier choice survives rebases.

## Design rules

- **No silent failure.** Anything optional (AI runtime, Acer support, smart home)
  is gated and reports why it is unavailable.
- **Root only for root's work.** Tier state and power settings go through
  `pkexec`; KDE settings and app installs stay in the user session.
- **Testable without hardware.** Every path and sysfs root can be overridden by
  an environment variable (`TOKORO_*`), which is what `tests/` uses.
