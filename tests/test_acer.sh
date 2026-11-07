#!/usr/bin/env bash
# Acer support must exist on an Acer laptop and nowhere else.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
EXEC=$ROOT/files/system/usr/libexec/tokoro
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export TOKORO_ETC=$TMP/etc
export TOKORO_STATE=$TMP/state
export TOKORO_EXEC=$EXEC
export TOKORO_SHARE=$ROOT/files/system/usr/share/tokoro
mkdir -p "$TOKORO_ETC" "$TOKORO_STATE"

dmi() { # dir vendor product family
  mkdir -p "$1"
  printf '%s\n' "$2" >"$1/sys_vendor"
  printf '%s\n' "$3" >"$1/product_name"
  printf '%s\n' "$4" >"$1/product_family"
  printf 'x\n' >"$1/board_vendor"
}

battery() { mkdir -p "$1/BAT0"; printf '1\n' >"$1/BAT0/present"; }

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

detect() { # dmi_dir power_supply_dir
  TOKORO_DMI_ROOT=$1 TOKORO_POWER_SUPPLY_ROOT=$2 "$EXEC/tokoro-acer" detect
}

dmi "$TMP/dell" "Dell Inc." "XPS 15 9530" "XPS"
battery "$TMP/ps-laptop"
dmi "$TMP/acer" "Acer" "Nitro V 15 ANV15-51" "Nitro V 15"
dmi "$TMP/acer-desktop" "Acer" "Aspire TC-885" "Aspire TC"
mkdir -p "$TMP/ps-desktop"

acer_laptop() { detect "$TMP/acer" "$TMP/ps-laptop"; }
check "Acer laptop is detected" acer_laptop

dell_laptop() { ! detect "$TMP/dell" "$TMP/ps-laptop"; }
check "Dell laptop is gated off" dell_laptop

acer_without_battery() { ! detect "$TMP/acer-desktop" "$TMP/ps-desktop"; }
check "Acer desktop is gated off" acer_without_battery

unknown_vendor() { ! detect "$TMP/nope" "$TMP/ps-laptop"; }
check "missing DMI is gated off" unknown_vendor

# Every entry point must refuse to act on unsupported hardware.
battery_refused() {
  ! TOKORO_DMI_ROOT=$TMP/dell TOKORO_POWER_SUPPLY_ROOT=$TMP/ps-laptop \
    "$EXEC/tokoro-acer" battery limit on >/dev/null 2>&1
}
check "battery limiter refuses non-Acer hardware" battery_refused

mode_refused() {
  ! TOKORO_DMI_ROOT=$TMP/dell TOKORO_POWER_SUPPLY_ROOT=$TMP/ps-laptop \
    "$EXEC/tokoro-acer" mode turbo >/dev/null 2>&1
}
check "mode changes refuse non-Acer hardware" mode_refused

five_modes() {
  [[ $("$EXEC/tokoro-acer" modes 2>/dev/null | grep -cE '^(quiet|balanced|performance|turbo|nitro)') -ge 4 ]]
}
check "modes table renders the five modes" five_modes

# The systemd unit must keep its gate.
unit_gate() {
  grep -q 'ExecCondition=/usr/libexec/tokoro/tokoro-acer detect' \
    "$ROOT/files/system/etc/systemd/system/tokoro-acer-battery.service"
}
check "battery unit keeps its ExecCondition gate" unit_gate

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi
