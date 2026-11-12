# Test features

These commands are **test features**: they are complete enough to use, but they
are newer than the rest of the command surface, they are deliberately small, and
they are the first things that could change. Nothing else in Tokoro OS depends on
them, so removing one would not affect setup, tiers, the AI or gaming.

Everything here is read-only unless it says otherwise.

## `tokoro status [--json]`

One screen for everything that usually breaks on a fresh install:

```console
$ tokoro status
Tokoro OS 1.2.08 (Supra Mk3)
  tier      : balanced (recommended balanced)
  mode      : work
  AI        : off (nothing downloaded)
  drivers   : clean
  benchmark : 63.4/100
  updates   : none
```

It reads the other tools rather than duplicating their logic, so the numbers
always match `tokoro tier show`, `tokoro ai status` and `tokoro bench run`. The
driver scan is capped at 12 seconds so a slow `fwupd` cannot hang the command,
and `--json` gives the same data for the applet or a script.

## `tokoro monitor [--watch] [--json]`

The task manager. One screen for what the machine is doing right now:

```console
$ tokoro monitor
Tokoro monitor — CPU AMD Ryzen 7 5800H · 8 cores / 16 threads
  load average 0.42 0.51 0.63
  CPU    ███████░░░░░░░░░░░░░░░  34.0%
  cores  █ 34 ░ 12 █ 61 ░  8

  RAM    █████████████░░░░░░░░░   9.4 / 15.5 GB used (61%)
  swap   █░░░░░░░░░░░░░░░░░░░░░   0.2 / 8.0 GB

  GPU    ███░░░░░░░░░░░░░░░░░░░   VRAM 1.8 / 8.0 GB  NVIDIA RTX 4060

  Disk   /home/you  214.0 / 931.0 GB used (23%) · 717.0 GB free
         █████░░░░░░░░░░░░░░░░░

         Photos    ███████░░░░░░░     42.1 GB    19%
         Videos    ██████████████    120.0 GB    56%
         Music     █░░░░░░░░░░░░░      8.2 GB     4%
         Files     ████░░░░░░░░░░     31.0 GB    14%
         Archives  ░░░░░░░░░░░░░░      2.1 GB     1%
         Other     █░░░░░░░░░░░░░     10.6 GB     5%
         scanned 184203 files
```

- **CPU**: model, cores/threads, load average, total utilisation and a per-core
  strip, all from `/proc/stat`.
- **RAM/swap**: used, available and total in GB from `/proc/meminfo`, with usage
  taken as `total - MemAvailable` so page cache is not miscounted.
- **GPU**: `nvidia-smi` where it exists; otherwise AMD/Intel VRAM from sysfs
  (`mem_info_vram_total/_used`). A driver that does not expose VRAM says so
  rather than showing a fake number.
- **Disk**: used, free and total for the scanned path, from the kernel's own
  `statvfs` numbers.
- **Breakdown**: walks the path (home by default) and groups by extension into
  Photos, Videos, Music, Files, Archives and Other, each with its own colour.
  Symlinks are not followed, and the scan stops after `--scan-limit` files
  (200 000 by default) marking itself partial instead of hanging.
- **Processes**: top processes by resident memory with PID, memory and CPU time.

`--watch` redraws every `--interval` seconds (Ctrl+C quits), `--json` gives the
same data, `--no-color` and `NO_COLOR` produce plain text, and `--root` points
`/proc` and `/sys` at a fixture, which is how it is tested.

## Now-playing widget + `tokoro now` / `library` / `levels`

The panel widget **Tokoro Now Playing** has its own page: [music.md](music.md).
It talks to players over MPRIS (Spotify included, no account or API key), shows
level bars from `cava` when that is installed — animated only on the Quality and
Ultra Quality tiers, so lower profiles never start cava — and lists your local
music in a scrollable popup that plays on click. The three helpers behind it are
testable today:

```bash
$ tokoro now
Playing: One More Time — Daft Punk

$ tokoro library
Music library — 412 tracks
  root: /home/you/Music
  Discovery — One More Time
  …

$ tokoro levels --json
{"schema": 1, "test_feature": true, "source": "simulated", "bars": [41, 63, …]}
```

## `tokoro report [--out DIR]`

Writes `tokoro-report-<date>.tar.gz` for a bug report:

```
status.txt       tokoro status
doctor.txt       tokoro doctor (every check, with failures)
tier.txt         tokoro tier show
ai.txt           tokoro ai status
hardware.json    tokoro detect-hardware --json
drivers.json     tokoro drivers scan --json
games.txt        tokoro games stats
firstboot.json   the plan the wizard applied, if it ran
tier.conf        the stored tier state, if it exists
release.json     the image's release metadata
system.txt       hostname, kernel, arch, os-release, rpm-ostree status
```

It contains no file contents and no keys, and it never uploads anything. The
archive is created with `umask 077`, and the command prints the path so you can
inspect it before sharing.

## `tokoro music [--list | --play PATH]`

Opens the player chosen in the wizard, using the same `apps.json` slot the setup
used, so there is exactly one source of truth:

```console
$ tokoro music --list
Music players (configured: elisa)
  elisa      Elisa        missing    <- configured
  strawberry Strawberry   missing
  amberol    Amberol      missing
  lollypop   Lollypop     missing
  spotify    Spotify      missing
```

If the configured player is not installed it prints the exact `flatpak install`
line instead of failing silently, and `--play` passes a file or folder to it.

## Why so small

A distro should not grow commands faster than it can test them. Each of these
has a fixture test in `tests/test_features.py`, runs without root, and depends
only on bash, Python's standard library and the tools already in the image.
