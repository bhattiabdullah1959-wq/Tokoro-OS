#!/usr/bin/env bash
# The banner script against a Bazzite-shaped fixture tree.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT=$ROOT/files/scripts/20-terminal-banner.sh
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/usr/share/ublue-os/motd" "$TMP/etc/tokoro" \
  "$TMP/usr/share/fish/vendor_conf.d"
cp "$ROOT/files/system/etc/tokoro/motd.md" "$TMP/etc/tokoro/motd.md"
printf 'Existing login notice\n' >"$TMP/etc/motd"
cat >"$TMP/usr/share/ublue-os/motd/template.md" <<'EOF'
# Welcome to Bazzite

Bazzite is a gaming-focused Fedora Atomic image.

- [Website](https://bazzite.gg/)
- [Discord](https://discord.gg/ublue)
- [Upstream](https://github.com/ublue-os)
EOF

failures=0
check() {
  local name=$1
  shift
  if "$@" >"$TMP/log" 2>&1; then
    printf '  ok   %s\n' "$name"
  else
    printf '  FAIL %s\n' "$name"
    sed 's/^/       /' "$TMP/log"
    failures=$((failures + 1))
  fi
}

template=$TMP/usr/share/ublue-os/motd/template.md

run_once() { TOKORO_ROOT=$TMP bash "$SCRIPT"; }
check "script runs cleanly" run_once

headline_rewritten() { grep -q '^# Welcome to Tokoro OS' "$template"; }
check "headline rewritten" headline_rewritten

# The Tokoro block credits Bazzite as the base distro on purpose; what must not
# survive is upstream branding and broken links.
no_upstream_branding() {
  ! grep -qE 'bazzite\.gg|Welcome to Bazzite|Bazzite is a|discord\.gg/ublue|github\.com/ublue-os' "$template"
}
check "no upstream branding remains" no_upstream_branding

tokoro_block_present() { grep -q '^# Tokoro OS' "$template"; }
check "Tokoro block present" tokoro_block_present

motd_drop_in() { [[ -f $TMP/etc/motd.d/00-tokoro-motd ]]; }
check "motd.d drop-in installed" motd_drop_in

profile_hook() { [[ -x $TMP/etc/profile.d/00-tokoro-banner.sh || -f $TMP/etc/profile.d/00-tokoro-banner.sh ]]; }
check "profile hook installed" profile_hook

motd_appended() { grep -q 'TOKORO-BANNER' "$TMP/etc/motd"; }
check "/etc/motd carries the banner" motd_appended

fish_greeting() { [[ -f $TMP/usr/share/fish/vendor_conf.d/00-tokoro.fish ]]; }
check "fish greeting neutralised" fish_greeting

idempotent() {
  TOKORO_ROOT=$TMP bash "$SCRIPT" || return 1
  [[ $(grep -c 'TOKORO-BANNER' "$TMP/etc/motd") -eq 1 ]] || return 1
  # The prepended block must not stack up either.
  [[ $(grep -c '^# Welcome to Tokoro OS' "$template") -eq 1 ]] || return 1
}
check "re-running is idempotent" idempotent

backup_kept() { [[ -f ${template}.tokoro-orig ]]; }
check "upstream template backed up" backup_kept

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi
