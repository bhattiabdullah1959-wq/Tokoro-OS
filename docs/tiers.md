# The five-tier performance system

| Tier | Car | Power | Animations | Blur | Tearing | AI model |
| --- | --- | --- | --- | --- | --- | --- |
| `ultra-performance` | Honda Civic Type R EK9 | performance | off (0) | off | yes | Tokoro 0.6 |
| `performance` | Nissan Skyline GT-R R34 | performance | 1 | off | yes | Tokoro 2 |
| `balanced` | Toyota AE86 | balanced | 3 | off | no | Tokoro 3 |
| `quality` | Mazda RX-7 FD3S | balanced | 5 | on | no | Tokoro 4.8 |
| `ultra-quality` | Lexus LS400 | balanced | 7 | on | no | Tokoro 5 |

Each tier owns a wallpaper (`/usr/share/tokoro/wallpapers/tokoro-<tier>.svg`) and
a sound theme (`/usr/share/sounds/tokoro-<tier>/`).

## Detection

`tokoro-detect-hardware` reads sysfs and DMI and scores the machine 0-100:

| Component | Maximum | Basis |
| --- | --- | --- |
| GPU | 55 | VRAM (integrated GPU scores 16) |
| CPU | 25 | physical cores |
| RAM | 20 | `MemTotal` |

Thresholds: `<20` ultra-performance, `<40` performance, `<60` balanced, `<80`
quality, else ultra-quality. The full breakdown is available with
`tokoro-detect-hardware --explain`, and a test fixture covers three profiles.

Sampling of the mapping:

| Machine | Score | Tier |
| --- | --- | --- |
| 4-core iGPU laptop, 8 GB RAM | 28 | performance |
| 8-core + 8 GB dGPU, 16 GB RAM | 63 | quality |
| 16-core + 16 GB dGPU, 32 GB RAM | 93 | ultra-quality |

## Overriding

You can pick any tier. When the chosen tier is above the hardware
recommendation:

- `/etc/tokoro/tier.conf` records `TOKORO_OVERRIDE=1`
- `~/.config/tokoro/tier.json` records `above_recommendation: true`
- the Plasma applet shows a warning icon

There is deliberately **no popup**. `tokoro tier show` prints the same warning in
text. `tokoro tier reset` returns to the recommendation, and
`tokoro tier detect --save` refreshes it after a hardware change.

## Commands

```
tokoro tier show          current tier, car, recommendation, warning
tokoro tier list          all five tiers and their cars
tokoro tier detect        hardware detection, human readable
tokoro tier detect --save store the new recommendation
tokoro tier set quality   switch tier (root prompt via pkexec)
tokoro tier reset         back to the recommendation
tokoro tier status --json machine readable state
```
