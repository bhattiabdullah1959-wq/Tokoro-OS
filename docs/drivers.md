# Drivers and firmware

Tokoro cannot ship a driver for hardware it has never seen, so the OS tells you
what is missing instead of guessing.

```bash
tokoro drivers scan            # what has no driver, what firmware needs updating
tokoro drivers scan --notify   # same, plus a desktop notification
tokoro drivers scan --json     # for scripts and the settings applet
```

The scan is read-only and always exits `0`; it reports, it never installs. It
checks four things:

| Check | Source | Fix it suggests |
| --- | --- | --- |
| PCI devices with no `Kernel driver in use` | `lspci -k` | layer the driver with `rpm-ostree`, or use the matching image |
| Kernel firmware failures this boot | `journalctl -k -b` | install the vendor firmware package |
| Pending firmware updates | `fwupdmgr get-updates` | `fwupdmgr update` |
| NVIDIA GPU without the `nvidia` module | `lspci`, `lsmod` | use `tokoro-os-nvidia`, or layer `akmod-nvidia` |

The Plasma applet exposes the same scan as **Scan for missing drivers**, so the
check lives next to the tier buttons that change the performance mode.

Scanning is independent of the performance tier: any tier may scan, and the
result is the same. What the tier changes is how much the local assistant is
allowed to do on its own (see [ai.md](ai.md)).
