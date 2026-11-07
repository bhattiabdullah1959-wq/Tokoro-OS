#!/usr/bin/env bash
# AI capability gating: the assistant loses abilities as the tier drops.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
EXEC=$ROOT/files/system/usr/libexec/tokoro
SHARE=$ROOT/files/system/usr/share/tokoro
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export TOKORO_ETC=$TMP/etc
export TOKORO_STATE=$TMP/state
export TOKORO_STATE_FILE=$TMP/etc/tier.conf
export TOKORO_USER_CONFIG=$TMP/config
export TOKORO_SHARE=$SHARE
export TOKORO_EXEC=$EXEC
export HOME=$TMP/home
mkdir -p "$TOKORO_ETC" "$TOKORO_STATE" "$HOME"

set_tier() { # tier recommendation
  printf 'TOKORO_TIER=%s\nTOKORO_RECOMMENDED=%s\nTOKORO_OVERRIDE=0\n' "$1" "$2" >"$TOKORO_STATE_FILE"
}

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

set_tier ultra-performance ultra-performance
low_files() { ! "$EXEC/tokoro-ai" permits files; }
check "ultra-performance may not read files" low_files
low_apps() { ! "$EXEC/tokoro-ai" permits apps; }
check "ultra-performance may not open apps" low_apps
low_screen() { ! "$EXEC/tokoro-ai" permits screen; }
check "ultra-performance may not see the screen" low_screen

set_tier performance performance
perf_apps() { "$EXEC/tokoro-ai" permits apps; }
check "performance may open apps" perf_apps
perf_files() { ! "$EXEC/tokoro-ai" permits files; }
check "performance may not read files" perf_files

set_tier balanced balanced
bal_files() { "$EXEC/tokoro-ai" permits files; }
check "balanced may read files" bal_files
bal_updates() { ! "$EXEC/tokoro-ai" permits updates; }
check "balanced may not download updates" bal_updates

set_tier quality quality
qual_screen() { "$EXEC/tokoro-ai" permits screen; }
check "quality may see the screen" qual_screen
qual_updates() { ! "$EXEC/tokoro-ai" permits updates; }
check "quality may not download updates" qual_updates

set_tier ultra-quality ultra-quality
top_everything() {
  local cap
  for cap in files updates apps screen; do
    "$EXEC/tokoro-ai" permits "$cap" || return 1
  done
}
check "ultra-quality keeps every ability" top_everything

caps_json() {
  "$EXEC/tokoro-ai" capabilities --json | python3 -c '
import json, sys
data = json.load(sys.stdin)
assert data["tier"] == "ultra-quality", data
assert set(data["allowed"]) == {"files", "updates", "apps", "screen"}, data
assert data["capabilities"]["updates"]["min_tier"] == "ultra-quality", data
assert data["capabilities"]["files"]["allowed"] is True, data
'
}
check "capability matrix is machine readable" caps_json

# Refusals must come before any privileged or network work.
refuses_open() {
  set_tier ultra-performance ultra-performance
  ! "$EXEC/tokoro-ai" open firefox
}
check "opening apps is refused below its tier" refuses_open

refuses_update() {
  set_tier balanced balanced
  ! "$EXEC/tokoro-ai" update
}
check "update downloads are refused below their tier" refuses_update

refuses_screen() {
  set_tier quality quality
  local screenshot=$TMP/should-not-exist.png
  ! "$EXEC/tokoro-ai" see "what is this" 2>"$TMP/see.log"
  ! test -e "$screenshot"
}
check "screen capture needs the top tier (and AI on)" refuses_screen

runtime_missing() {
  local out rc
  out=$("$EXEC/tokoro-ai-runtime" status 2>&1)
  rc=$?
  [[ $rc -eq 1 ]] && printf '%s' "$out" | grep -q missing
}
check "runtime reports missing before it is downloaded" runtime_missing

# Status must agree with the matrix and never claim a runtime it lacks.
status_agrees() {
  set_tier balanced balanced
  "$EXEC/tokoro-ai" status --json | python3 -c '
import json, sys
data = json.load(sys.stdin)
assert data["tier"] == "balanced", data
assert data["runtime"] == "missing", data
assert data["enabled"] is False, data
assert data["capabilities"] == ["files", "apps"], data
'
}
check "status reports tier, abilities and a missing runtime" status_agrees

# Tier changes above the recommendation warn (exit 3) but are never refused.
check_above() {
  set_tier quality balanced
  local rc
  "$EXEC/tokoro-tier" check quality >"$TMP/check.log" 2>&1
  rc=$?
  [[ $rc -eq 3 ]] && grep -q 'warning' "$TMP/check.log"
}
check "tier check flags an override as a warning" check_above

check_within() {
  set_tier balanced balanced
  "$EXEC/tokoro-tier" check balanced
}
check "tier check passes within the recommendation" check_within

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi
