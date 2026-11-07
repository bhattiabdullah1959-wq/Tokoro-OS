# Terminal banner

The banner work that was written but never confirmed on a booted VM is now both
more defensive and directly verifiable.

## What is patched

`files/scripts/20-terminal-banner.sh` handles every surface Bazzite can show a
banner on:

1. `/usr/share/ublue-os/motd/template.md` — upstream ublue motd template:
   - the `# Welcome to ...` headline becomes `# Welcome to Tokoro OS`
   - upstream community links (`bazzite.gg`, `discord.gg/ublue`,
     `universal-blue.org`, `github.com/ublue-os`) are removed
   - remaining `Bazzite`/`bazzite` product names are rewritten
   - the Tokoro block from `/etc/tokoro/motd.md` is prepended (this block names
     Bazzite once, because it is the base distro)
   - the original is kept as `template.md.tokoro-orig`
2. `/etc/motd.d/00-tokoro-motd` — login/sshd drop-in
3. `/etc/motd` — appended once, tagged `# TOKORO-BANNER` so re-runs are idempotent
4. `/etc/profile.d/00-tokoro-banner.sh` — interactive shells print
   `tokoro banner` once (`TOKORO_NO_BANNER=1` silences it)
5. `/usr/share/fish/vendor_conf.d/00-tokoro.fish` — empties `fish_greeting`
6. `/etc/issue` — written by `50-release-metadata.sh` for tty logins

## Verifying it

On the machine (this is the step that never happened before):

```bash
tokoro doctor            # section "Terminal banner" must be all [ ok ]
tokoro banner            # renders the dynamic banner
TOKORO_NO_BANNER=1 bash  # confirm the banner can be silenced
```

`tokoro doctor` fails if no banner surface exists and fails if the ublue template
still mentions Bazzite.

## Verified here vs not

`tests/test_banner.sh` runs the build script against a fixture tree containing a
real-shaped ublue template and asserts:

- the headline is rewritten
- no upstream branding or dead links survive (`bazzite.gg`, `Welcome to Bazzite`,
  `discord.gg/ublue`, `github.com/ublue-os`)
- the motd.d drop-in is installed
- `/etc/motd` gets exactly one `TOKORO-BANNER` block, even when run twice
- the profile hook and fish config exist

That proves the transformation logic. It does **not** prove the final rendering
on a booted Bazzite image — that requires the VM run and `tokoro doctor`.
