# Game compatibility dataset

`/usr/share/tokoro/games/games.json` drives the benchmark's game ratings and the
`tokoro games` browser.

## Ratings

| Rating | Meaning |
| --- | --- |
| `green` | Runs well out of the box |
| `yellow` | Runs, may need tweaks or has minor issues |
| `orange` | Playable but compromised (launcher, performance, features) |
| `red` | Does not currently run |

Anti-cheat locked titles (Valorant, Fortnite, Apex Legends, Destiny 2, PUBG,
Rainbow Six Siege, Call of Duty HQ, Battlefield 2042, EA SPORTS FC, Roblox,
League of Legends) are **not rated**. They live in the `excluded` list with a
reason, so the tool can explain the exclusion instead of pretending a rating
exists.

## Schema

```json
{
  "schema": 1,
  "games": [
    { "id": "1245620", "name": "Elden Ring", "rating": "green",
      "weight": "heavy", "anticheat": "EAC (Proton enabled)", "note": "..." }
  ],
  "excluded": [ { "name": "Valorant", "reason": "..." } ]
}
```

- `id` — Steam AppID, or a slug for non-Steam titles
- `weight` — `light`, `medium`, `heavy`; drives the per-tier frame-rate estimate
- `note` — optional caveat shown by `tokoro games info`

## Current size

The shipped file is a **curated seed dataset** (well over a hundred hand-checked
titles), not the full top 1000. Ratings are ProtonDB-style community consensus
for Bazzite/Proton and will drift as Proton and anti-cheat policies change.

Grow it without touching the image:

```bash
tokoro games import my-dataset.json   # validated, merged as a user overlay
tokoro games validate                 # check the shipped dataset
tokoro games stats                    # counts by rating/weight
tokoro games info "Elden Ring"        # rating + tier expectation
tokoro games excluded                 # what anti-cheat blocks and why
```

The overlay lives at `~/.local/share/tokoro/games-overlay.json` and takes
precedence over the shipped entries, so the dataset can be corrected between
image releases.
