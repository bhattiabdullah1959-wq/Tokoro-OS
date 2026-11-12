# Tokoro OS documentation

| Document | What it covers |
| --- | --- |
| [architecture.md](architecture.md) | Image composition, repo layout, state files, command surface |
| [tiers.md](tiers.md) | The five tiers, detection scoring, override warning |
| [banner.md](banner.md) | Terminal banner: what is patched and how to verify it |
| [ai.md](ai.md) | Local AI runtime, the five models, file-safety explanations |
| [acer.md](acer.md) | Acer Nitro V battery limiter, five modes, mode key |
| [games.md](games.md) | Compatibility dataset, ratings, expanding to 1000 titles |
| [release.md](release.md) | Semver + car tags, version bump procedure |
| [testing.md](testing.md) | What the test suite proves and what needs real hardware |
| [music.md](music.md) | Now-playing panel widget: MPRIS, level bars, local library |
| [experimental.md](experimental.md) | Test features: `tokoro status`, `monitor`, `report`, `music`, `now`, `library`, `levels` |

## The short version

Tokoro OS is a BlueBuild image layered on Bazzite (Fedora Atomic). The image
ships branded identity, five performance tiers, a first-boot wizard, an optional
on-device AI, a compatibility/benchmark suite, and hardware-gated Acer laptop
support. Every runtime tool is bash or Python stdlib, and nothing phones home.

Two image variants are built from this repository:

- `ghcr.io/bhattiabdullah1959-wq/tokoro-os` — AMD / Intel
- `ghcr.io/bhattiabdullah1959-wq/tokoro-os-nvidia` — NVIDIA

Both are signed with cosign using `cosign.pub` in the repository root.
