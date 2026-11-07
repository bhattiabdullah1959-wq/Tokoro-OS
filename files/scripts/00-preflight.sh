#!/usr/bin/env bash
# Build-time preflight. Verifies assumptions before anything is modified so a
# broken base image fails loudly instead of producing a half-branded system.
set -euo pipefail

echo "::group::Tokoro OS preflight"

fail=0
require() {
  if [[ ! -e "$1" ]]; then
    echo "ERROR: expected base image path missing: $1" >&2
    fail=1
  else
    echo "ok: $1"
  fi
}

require /usr/share/ublue-os
require /usr/lib/os-release
require /usr/bin/kwriteconfig6

for cmd in python3 jq curl; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "ok: $cmd"
  else
    echo "ERROR: required build tool missing: $cmd" >&2
    fail=1
  fi
done

# The runtime is written in bash + python3 stdlib only; bail out early if the
# base stops shipping a usable interpreter.
if ! python3 -c 'import json, sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'; then
  echo "ERROR: python3 >= 3.9 is required" >&2
  fail=1
fi

mkdir -p /etc/tokoro /var/lib/tokoro /usr/share/tokoro
chmod 0755 /etc/tokoro /var/lib/tokoro /usr/share/tokoro

if [[ "$fail" -ne 0 ]]; then
  echo "preflight failed" >&2
  exit 1
fi

echo "preflight passed"
echo "::endgroup::"
