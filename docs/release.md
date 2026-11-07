# Release naming

Versions are plain semver (`1.2.08`) with a car codename on top
(`1.2 Supra Mk3`).

## Single source of truth

`files/system/usr/share/tokoro/release.json` holds the version, series, codename,
car and the per-tier cars. Everything else is derived from it or checked against
it:

| Surface | Source |
| --- | --- |
| `/etc/tokoro/version`, `/etc/issue`, `/etc/tokoro/release.json` | written by `50-release-metadata.sh` |
| `/usr/lib/os-release` `VERSION_ID`, `PRETTY_NAME` | `os-release` module in both recipes |
| OCI tags | `alt-tags` in both recipes |
| `tokoro version` | reads `release.json` |

## Image tags

Both recipes publish:

```
latest
1.2.08
1.2
1.2-supra-mk3
```

`alt-tags` replaces BlueBuild's default latest/timestamp tags, so `latest` is
listed explicitly.

## Bumping a release

1. Edit `release.json`: `version`, `series`, `codename`, `codename_slug`, `car`,
   `released`.
2. Update `alt-tags` in `recipes/recipe.yml` and `recipes/recipe-nvidia.yml`.
3. Update `PRETTY_NAME` / `VERSION` / `VERSION_ID` / `VERSION_CODENAME` in both
   recipes and the banner text in `/etc/tokoro/motd.md`.
4. Run `tests/test_release.py` — it fails if any of these disagree.

The test is the guard: it parses both recipes and `release.json` and compares the
version, series and codename slug.

## Signing

Images are signed with cosign via the `signing` module (last module in each
recipe). Verify with:

```bash
cosign verify --key cosign.pub ghcr.io/bhattiabdullah1959-wq/tokoro-os:1.2.08
```

## Car naming convention

- The **release** codename names the era's hero car (`1.2 Supra Mk3`,
  `1.3 Supra Mk4`).
- The **tiers** have their own permanent cars (Civic Type R, GT-R R34, AE86,
  RX-7 FD, LS400); they do not change per release.
- The **AI models** are named by engine displacement (Cappuccino 0.66, S14 2.0,
  3000GT 3.0, LFA 4.8, Century 5.0).
