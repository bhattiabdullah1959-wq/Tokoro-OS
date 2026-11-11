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
