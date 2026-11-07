# Local AI

Tokoro AI runs entirely on the machine. The runtime is Ollama and it binds to
`127.0.0.1:11435` only: nothing leaves the box.

## Nothing is downloaded until you say yes

The image ships the service, the CLI and the model definitions, but **not** the
runtime. That keeps the default install small and means declining AI during
setup downloads nothing at all.

- The first-boot wizard asks once, with the box **off by default**.
- Turning the assistant on later (settings applet, or `tokoro ai enable`)
  downloads the pinned runtime into `/var/lib/tokoro/ai/runtime` (~1 GB, once)
  and starts `tokoro-ai.service`.
- Turning it off stops the service and keeps the runtime and models, so turning
  it back on later needs no new download.

```bash
tokoro ai status        # enabled? runtime installed? API reachable? abilities?
tokoro ai enable        # download the runtime if missing, start it, fetch the model
tokoro ai enable --reboot   # same, then reboot when it is ready
tokoro ai disable       # stop it and remember the choice
```

The runtime lives in `/var/lib/tokoro` rather than `/usr`, because `/usr` is
immutable on an rpm-ostree system and must survive image updates.

`30-ai-runtime.sh` therefore only prepares directories at build time. If the
download fails on a user's machine, `tokoro ai status` and `tokoro doctor` say so
instead of pretending the feature works.

## The five models

| Model | Car | Base | Download | Minimum RAM |
| --- | --- | --- | --- | --- |
| Tokoro 0.6 | Suzuki Cappuccino | `qwen2.5:0.5b` | 0.4 GB | 4 GB |
| Tokoro 2 | Nissan Silvia S14 | `qwen2.5:1.5b` | 1.0 GB | 8 GB |
| Tokoro 3 | Mitsubishi 3000GT | `llama3.2:3b` | 2.0 GB | 12 GB |
| Tokoro 4.8 | Lexus LFA | `qwen2.5:7b` | 4.7 GB | 16 GB |
| Tokoro 5 | Toyota Century | `qwen2.5:14b` | 9.0 GB | 24 GB |

The names are engine displacements, not sizes. The tier picks the default model
(see [tiers.md](tiers.md)), and `tokoro ai model <id>` overrides it.

## Abilities follow the tier

A slower machine means a smaller model, so the assistant also keeps fewer
abilities. The matrix lives in `/usr/share/tokoro/ai/capabilities.json` and is
enforced by the CLI before anything is read, opened or downloaded.

| Tier | read files | open apps | see the screen | download updates |
| --- | --- | --- | --- | --- |
| `ultra-performance` | no | no | no | no |
| `performance` | no | yes | no | no |
| `balanced` | yes | yes | no | no |
| `quality` | yes | yes | yes | no |
| `ultra-quality` | yes | yes | yes | yes |

```bash
tokoro ai capabilities          # human readable, current tier
tokoro ai capabilities --json   # for the applet and scripts
tokoro ai permits screen        # exit 0 allowed, 1 not (no output)
```

Refused commands explain the minimum tier instead of failing silently:

```
$ tokoro ai see
tokoro: seeing your screen is not available in the balanced tier; it starts at
quality. Change tier with: tokoro tier set quality
```

| Command | Ability | What it does |
| --- | --- | --- |
| `tokoro ai ask "..."` | always | one-shot answer from the tier's model |
| `tokoro ai read <file>` | `files` | summarise a file you name |
| `tokoro ai open <app>` | `apps` | launch an installed application |
| `tokoro ai see ["..."]` | `screen` | screenshot, then answer about it |
| `tokoro ai update [--check]` | `updates` | stage system updates with `rpm-ostree` |

`tokoro ai see` captures a single full-screen frame with `spectacle` (or `grim`),
sends it to the local model and deletes the file afterwards. Nothing is uploaded.

## File-safety warnings

`tokoro fileguard <file>` is also exposed in Dolphin as *Explain this file
(Tokoro AI)*. It stays available on every tier because it is a safety feature
about one file the user already picked: the `files` ability gates the assistant
reading files on its own, not a warning you asked for.

Static checks always run: ELF/script detection, setuid, world-writable,
extension-vs-magic mismatch (disguised files), and risky shell patterns
(`rm -rf /`, `dd of=/dev/sda`, `curl | sh`, reverse shells, credential file
overwrites, and similar).

Exit codes: `0` safe, `10` caution, `20` dangerous.

When AI is enabled, the local model appends a three-line plain-language
explanation. When it is off, the static result stands on its own.
