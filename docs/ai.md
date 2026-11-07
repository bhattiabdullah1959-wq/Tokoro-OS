# Local AI

Tokoro AI runs entirely on the machine. The runtime is Ollama, pinned at build
time and bound to `127.0.0.1:11435`; it never leaves the box and is never enabled
without an explicit opt-in.

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

## Opt-in flow

```bash
tokoro ai status          # enabled? runtime present? API reachable?
tokoro ai models          # the table above, current tier marked
tokoro ai enable          # start the service and fetch the tier's model
tokoro ai ask "explain SELinux permissive mode simply"
tokoro ai disable         # stop and remember the choice
```

`enable` pulls the base model and derives a `tokoro:<id>` model with a fixed
system prompt, so every answer is grounded in the machine ("runs offline, be
concrete, never invent paths").

## File-safety warnings

`tokoro fileguard <file>` is also exposed in Dolphin as *Explain this file
(Tokoro AI)*.

Static checks always run: ELF/script detection, setuid, world-writable,
extension-vs-magic mismatch (disguised files), and risky shell patterns
(`rm -rf /`, `dd of=/dev/sda`, `curl | sh`, reverse shells, credential file
overwrites, and similar).

Exit codes: `0` safe, `10` caution, `20` dangerous.

When AI is enabled, the local model appends a three-line plain-language
explanation. When it is off, the static result stands on its own — which is the
intended behaviour of "AI-explained warnings depend on the AI being enabled".

## Image builds without the runtime

`30-ai-runtime.sh` discovers the Linux asset from the pinned release page. If the
download fails, the image still builds and
`/usr/share/tokoro/ai/RUNTIME_MISSING` explains why. `tokoro doctor` and
`tokoro ai status` both report it, so the feature is never silently broken.
