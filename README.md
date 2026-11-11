# Tokoro OS

A JDM-themed, adaptive gaming distro built on **Bazzite (Fedora Atomic)** with
[BlueBuild](https://bluebuild.org/), signed with cosign and published to GitHub
Container Registry.

Version **1.2.08 (Supra Mk3)** — two image variants:

| Variant | Image | Notes |
| --- | --- | --- |
| AMD / Intel | `ghcr.io/bhattiabdullah1959-wq/tokoro-os` | Mesa drivers from Bazzite |
| NVIDIA | `ghcr.io/bhattiabdullah1959-wq/tokoro-os-nvidia` | Proprietary driver stack from Bazzite |

Both are built by `.github/workflows/build.yml`, signed with the `signing`
module, and tagged `latest`, `1.2.08`, `1.2`, `1.2-supra-mk3`.

## Install

> [!WARNING]
> Rebasing replaces your current OS. Back up first, and try this on a spare
> machine or VM until you have booted it yourself.

```bash
# 1. Rebase to the unsigned image so the signing policy is installed
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/bhattiabdullah1959-wq/tokoro-os:latest
sudo systemctl reboot

# 2. Then rebase to the signed image
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/bhattiabdullah1959-wq/tokoro-os:latest
sudo systemctl reboot

# 3. Verify the signature at any time
cosign verify --key cosign.pub ghcr.io/bhattiabdullah1959-wq/tokoro-os:latest
```

NVIDIA machines use `tokoro-os-nvidia` in the same commands.

## What is in the image

### Core system
- NVIDIA and AMD/Intel variants, GPU support inherited from Bazzite (always on).
- Lean by default: nothing extra autostarted; `tokoro lean` lists a curated set of
  optional services you can switch off.
- Release naming: plain semver (`1.2.08`) with car codenames (`1.2 Supra Mk3`).
- `os-release`, `/etc/issue`, the console banner and `tokoro version` all report
  Tokoro OS.

### Five-tier performance system
`ultra-performance`, `performance`, `balanced`, `quality`, `ultra-quality`.

Each tier sets the power profile, CPU energy preference, KWin animation speed,
blur/effects, tearing policy, wallpaper and sound theme, and picks the local AI
model size. Hardware is detected on first boot and a tier recommended; you can
override it, and the Plasma applet then shows a passive warning icon (no popup).
Details: [docs/tiers.md](docs/tiers.md).

### Work/Gaming toggle
`tokoro mode toggle` (or `Meta+Shift+G`, see `tokoro mode install-shortcut`)
switches power profile, compositor settings, Acer mode and the KIRA smart-home
scene in one step.

### First-boot wizard
`tokoro wizard` (also offered automatically once) detects hardware, picks a tier,
toggles features, and installs the app selection — defaults are **Zen,
Vencord (Vesktop), Elisa, SKLauncher and MCA Selector**, each swappable (Chrome
instead of Zen, Strawberry or Amberol instead of Elisa, Prism instead of
SKLauncher, and so on). Every app is installed as a user flatpak, so the music
player works the same on both images.

### Signature features
- **Live wallpaper support** via KDE's video/shader wallpaper plugins, plus five
  tier wallpapers under `/usr/share/tokoro/wallpapers/`.
- **Local on-device AI**, fully skippable, five models named by engine
  displacement: Tokoro 0.6 (Cappuccino), 2 (S14), 3 (3000GT), 4.8 (LFA),
  5 (Century). The tier picks the model size. Details: [docs/ai.md](docs/ai.md).
- **AI-explained file-safety warnings**: `tokoro fileguard <file>` and a Dolphin
  right-click action. Static checks always run; AI explanation requires the AI.
- **Optional Bluetooth smart home (KIRA)** on the top two tiers:
  `tokoro smarthome scene gaming`.
- **Built-in benchmark with gaming mode**: `tokoro bench run`,
  `tokoro bench play <game>`, and a compatibility dataset with green / yellow /
  orange / red ratings; anti-cheat-locked titles are listed as excluded rather
  than rated. Details: [docs/games.md](docs/games.md).

### Acer Nitro V (laptop only, hardware gated)
80% battery limit, five performance modes, and the Nitro mode key. Desktops never
see any of it. Secure Boot must be off for the limiter; the wizard can only
detect and advise. Details: [docs/acer.md](docs/acer.md).

## Command surface

```
tokoro version            release version and car codename
tokoro doctor             verify branding, banner, tier, AI, Acer state
tokoro status             one-screen health summary (test feature)
tokoro monitor            task manager + storage breakdown (test feature)
tokoro report             diagnostics bundle for a bug report (test feature)
tokoro music              open the configured player (test feature)
tokoro tier show|list|detect|set|reset|status
tokoro mode work|gaming|toggle
tokoro wizard             first-boot wizard
tokoro ai status|models|enable|ask|explain
tokoro fileguard <file>   explain a file before running it
tokoro games list|info|excluded|stats|validate|import
tokoro bench run|play <game>
tokoro smarthome scene <work|gaming>
tokoro acer detect|status|battery limit on|off|modes|mode|next|learn
tokoro lean list|disable <unit>
```

## Repository layout

```
recipes/            recipe.yml (AMD/Intel), recipe-nvidia.yml
files/scripts/      build-time scripts, run in numeric order
files/system/       copied to / in the image (runtime tools, units, assets)
docs/               architecture, tiers, banner, AI, Acer, games, release, testing
tests/              fixture-based test suite (no root, no hardware)
```

## Development

```bash
bash tests/run-tests.sh
```

The suite validates both recipes against the published BlueBuild JSON schemas,
checks release consistency, and exercises hardware detection, the tier engine,
the banner rewrite, the wizard plan, the game dataset and Acer gating against
fixtures. See [docs/testing.md](docs/testing.md).

## Status — verified vs not

| Area | State |
| --- | --- |
| Recipes, build workflow, signing config | In repo; validated against BlueBuild schemas |
| Tier engine, detector, wizard plan, banner rewrite | Covered by tests against fixtures |
| Image build and VM boot | **Not run here** — needs the GitHub build and a VM boot |
| Terminal banner on a booted image | Logic tested; rendering **not confirmed** — run `tokoro doctor` |
| KDE settings / Plasma applet | Written; **not verified on a live Plasma session** |
| Acer battery limiter, modes, Nitro key | Wired and gated; **not tested on real hardware** |
| Sound themes | Theme skeletons inherit `freedesktop`; no custom audio assets yet |
| Game dataset | Curated seed (100+ titles), not the full top 1000; `tokoro games import` extends it |
| Local AI | Off by default, so setup downloads nothing. The runtime downloads on first opt-in and abilities shrink with the tier |

## License

See [LICENSE](LICENSE). Image signing key: [cosign.pub](cosign.pub).
