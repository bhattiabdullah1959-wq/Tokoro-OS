#!/usr/bin/env bash
# Tier engine: lookup, state parsing, warning logic and input validation.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
EXEC=$ROOT/files/system/usr/libexec/tokoro
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export TOKORO_ETC=$TMP/etc
export TOKORO_STATE=$TMP/state
export TOKORO_STATE_FILE=$TMP/etc/tier.conf
export TOKORO_USER_CONFIG=$TMP/home/.config/tokoro
export TOKORO_SHARE=$ROOT/files/system/usr/share/tokoro
export TOKORO_EXEC=$EXEC
export HOME=$TMP/home
mkdir -p "$TOKORO_ETC" "$TOKORO_STATE" "$HOME"

cat >"$TOKORO_STATE_FILE" <<'EOF'
TOKORO_TIER=quality
TOKORO_RECOMMENDED=balanced
TOKORO_OVERRIDE=1
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

above_reported() {
  "$EXEC/tokoro-tier" show | grep -q 'above hardware recommendation'
}
check "show reports the override warning" above_reported

json_state() {
  "$EXEC/tokoro-tier" status | python3 -c '
import json, sys
state = json.load(sys.stdin)
assert state["tier"] == "quality", state
assert state["recommended"] == "balanced", state
assert state["above_recommendation"] is True, state
assert state["overridden"] is True, state
'
}
check "status --json carries tier, recommendation and warning" json_state

five_tiers() {
  [[ $("$EXEC/tokoro-tier" list | wc -l) -eq 5 ]]
}
check "list prints five tiers" five_tiers

invalid_rejected() {
  ! "$EXEC/tokoro-tier" set turbo >/dev/null 2>&1
}
check "invalid tier is rejected" invalid_rejected

lib_helpers() {
  # shellcheck source=/dev/null
  . "$EXEC/tokoro-lib.sh"
  [[ "$(tokoro_tier_index balanced)" -eq 3 ]] || return 1
  [[ "$(tokoro_tier_index ultra-performance)" -eq 1 ]] || return 1
  [[ "$(tokoro_tier_from_index 5)" == "ultra-quality" ]] || return 1
  tokoro_tier_valid quality || return 1
  ! tokoro_tier_valid turbo || return 1
  [[ "$(tokoro_tier_label ultra-quality)" == "Ultra Quality" ]] || return 1
}
check "library tier helpers" lib_helpers

conf_complete() {
  local tier
  for tier in ultra-performance performance balanced quality ultra-quality; do
    [[ -r "$TOKORO_SHARE/tiers/$tier.conf" ]] || return 1
    # shellcheck source=/dev/null
    ( . "$TOKORO_SHARE/tiers/$tier.conf"
      [[ -n "$TIER_ANIM" && -n "$TIER_POWER" && -n "$TIER_AI" && -n "$TIER_WALLPAPER" ]] ) || return 1
  done
}
check "every tier config defines its settings" conf_complete

# Tier results feed the applet state file written by tokoro-tier-watch.
watch_state() {
  "$EXEC/tokoro-tier-watch" || return 1
  [[ -r "$TOKORO_USER_CONFIG/tier.json" ]] || return 1
  python3 -c '
import json, sys
state = json.load(open(sys.argv[1]))
assert state["tier"] == "quality", state
assert state["above_recommendation"] is True, state
' "$TOKORO_USER_CONFIG/tier.json"
}
check "applet state reflects the warning" watch_state

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi
