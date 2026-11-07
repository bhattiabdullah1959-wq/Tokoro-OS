# Acer Nitro V support (laptop only)

All Acer support is gated by one predicate: DMI says `Acer` **and** a battery
exists. Desktops and non-Acer laptops see nothing — commands exit 1, the
systemd unit's `ExecCondition` skips, and the wizard never offers the options.

```bash
tokoro acer detect     # exit 0 only on an Acer laptop
tokoro acer status     # model, battery limit, mode, Secure Boot
```

## Battery limiter (80%)

The image enables `tokoro-acer-battery.service`, which runs
`tokoro acer battery limit on` at boot. It writes:

1. `/sys/bus/platform/drivers/acer-wmi-battery/health_mode = 1`, or
2. `charge_control_end_threshold = 80` if the kernel exposes that instead.

**Secure Boot must be off.** The limiter depends on the `acer-wmi-battery`
driver, which is not signed for Secure Boot enforcement. The wizard can only
*detect* the state (`/sys/firmware/efi/efivars/SecureBoot-*`, `mokutil` fallback)
and advise; changing it is a BIOS action.

## Five performance modes

`quiet`, `balanced`, `performance`, `turbo`, `nitro`.

The kernel's `platform_profile` interface only exposes a few real values, so each
logical mode maps to the closest available profile; `power-profiles-daemon` is set
in parallel. Exact fan curves and power limits remain firmware behaviour:

```bash
tokoro acer modes        # mapping table with the active mode marked
tokoro acer mode turbo
tokoro acer next         # cycle (this is what the mode key runs)
```

## The mode key

Acer Nitro keyboards differ per revision, so the image ships **no guessed scan
code**. Instead:

```bash
sudo tokoro acer learn    # press the Nitro key when prompted
```

This records the pressed key in `/etc/udev/hwdb.d/90-tokoro-acer-key.hwdb`
remapped to `KEY_PROG1`, reloads systemd-hwdb, and the shipped udev rule starts
`tokoro-acer-cycle.service` on each press. The handler is debounced with
`flock`, so key repeat cannot spin through the mode list.

## Tier interaction

`tokoro tier set` also sets the Acer mode from the tier (turbo, performance,
balanced, balanced, quiet from lowest to highest tier). Gaming mode uses the
tier's mode as well.

## Not yet tested on hardware

These files are wired into the image and covered by gating tests, but no Acer
Nitro V was available for this work. Verify on the laptop with
`tokoro acer status`, `tokoro acer modes`, and one `tokoro acer learn` run.
