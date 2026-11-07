#!/usr/bin/env bash
# Acer Nitro support: make sure the shipped unit files, udev rules and helper
# binaries are consistent. Runtime gating happens in tokoro-acer, so this script
# is safe on every image variant and every desktop.
set -euo pipefail

echo "::group::Acer Nitro support"

fail=0
check() {
  if [[ -e "$1" ]]; then
    echo "ok: $1"
  else
    echo "WARN: missing $1" >&2
    fail=1
  fi
}

check /usr/libexec/tokoro/tokoro-acer
check /usr/libexec/tokoro/tokoro-acer-learn
check /etc/systemd/system/tokoro-acer-battery.service
check /etc/udev/rules.d/90-tokoro-acer-key.rules

for exe in /usr/libexec/tokoro/tokoro-acer \
  /usr/libexec/tokoro/tokoro-acer-learn \
  /usr/libexec/tokoro/tokoro-acer-cycle; do
  [[ -e "$exe" ]] && chmod 0755 "$exe"
done

# The service is enabled image-wide but gated by ExecCondition=tokoro-acer detect,
# which returns 1 on anything that is not an Acer laptop.
if [[ -f /etc/systemd/system/tokoro-acer-battery.service ]]; then
  grep -q 'ExecCondition=/usr/libexec/tokoro/tokoro-acer detect' \
    /etc/systemd/system/tokoro-acer-battery.service ||
    { echo "ERROR: battery unit lost its hardware gate" >&2; fail=1; }
fi

if [[ "$fail" -ne 0 ]]; then
  echo "acer support incomplete" >&2
  exit 1
fi
echo "::endgroup::"
