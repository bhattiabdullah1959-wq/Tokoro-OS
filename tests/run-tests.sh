#!/usr/bin/env bash
# Tokoro OS test suite. No root, no hardware, no Tokoro install required.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SHARE=$ROOT/files/system/usr/share/tokoro
EXEC=$ROOT/files/system/usr/libexec/tokoro
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export TOKORO_SHARE=$SHARE
export TOKORO_EXEC=$EXEC
export TOKORO_ETC=$TMP/etc
export TOKORO_STATE=$TMP/state
export TOKORO_STATE_FILE=$TMP/etc/tier.conf
export TOKORO_USER_CONFIG=$TMP/home/.config/tokoro
export HOME=$TMP/home
export XDG_CONFIG_HOME=$TMP/home/.config
export XDG_STATE_HOME=$TMP/home/.local/state
export XDG_DATA_HOME=$TMP/home/.local/share
mkdir -p "$TOKORO_ETC" "$TOKORO_STATE" "$HOME"

failures=0
total=0

run() {
  local name=$1
  shift
  total=$((total + 1))
  local out=$TMP/out.log
  if "$@" >"$out" 2>&1; then
    printf '  ok   %s\n' "$name"
  else
    printf '  FAIL %s\n' "$name"
    sed 's/^/       /' "$out"
    failures=$((failures + 1))
  fi
}

section() { printf '\n%s\n' "$*"; }

section "Syntax"
for script in "$ROOT"/files/scripts/*.sh \
  "$ROOT"/files/system/usr/bin/tokoro \
  "$ROOT"/files/system/usr/libexec/tokoro/*; do
  [[ -f "$script" ]] || continue
  case "$script" in
    *.py) continue ;;
  esac
  if head -n1 "$script" | grep -qE '^(#!.*bin/(ba)?sh|#!/usr/bin/env bash|# shellcheck shell=bash)'; then
    run "bash -n $(basename "$script")" bash -n "$script"
  fi
done

# Python tools have no .py extension in the image; find them by shebang so a new
# tool cannot be forgotten here.
for py in "$ROOT"/files/system/usr/libexec/tokoro/*; do
  [[ -f "$py" ]] || continue
  head -n1 "$py" | grep -q '^#!/usr/bin/env python3' || continue
  run "py_compile $(basename "$py")" python3 -m py_compile "$py"
done

if command -v shellcheck >/dev/null 2>&1; then
  section "shellcheck"
  # Every bash tool, discovered rather than listed: a new script is linted the
  # moment it lands.
  for script in "$ROOT"/files/scripts/*.sh \
    "$ROOT"/files/system/usr/bin/tokoro \
    "$ROOT"/files/system/usr/libexec/tokoro/*; do
    [[ -f "$script" ]] || continue
    head -n1 "$script" |
      grep -qE '^(#!.*bin/(ba)?sh|#!/usr/bin/env bash|# shellcheck shell=bash)' || continue
    run "shellcheck $(basename "$script")" \
      shellcheck -x -S warning "$script"
  done
else
  printf '\n(shellcheck not installed; skipping static shell analysis)\n'
fi

section "JSON"
while IFS= read -r json; do
  run "jq . $(basename "$json")" jq . "$json"
done < <(find "$ROOT/files" -name '*.json' | sort)

section "Image definitions"
run "recipe schema validation" python3 "$ROOT/tests/validate_recipes.py"
run "release metadata" python3 "$ROOT/tests/test_release.py"

section "Hardware detection"
run "detect: fixture tiers" python3 "$ROOT/tests/test_detect.py"

section "Tier engine"
run "tier: state + warning" bash "$ROOT/tests/test_tier.sh"

section "Banner"
run "banner: fixture tree" bash "$ROOT/tests/test_banner.sh"
run "splash: tokoro wordmark" python3 "$ROOT/tests/test_watermark.py"

section "App selection"
run "apps: slot definitions" python3 "$ROOT/tests/test_apps.py"

section "Wizard"
run "wizard: dry-run plan" python3 "$ROOT/tests/test_wizard.py"

section "Local AI"
run "ai: capabilities and refusals" bash "$ROOT/tests/test_ai_caps.sh"

section "Games + benchmark"
run "games: dataset" python3 "$ROOT/tests/test_games.py"
run "bench: score and persistence" python3 "$ROOT/tests/test_bench.py"

section "Acer gating"
run "acer: hardware gate" bash "$ROOT/tests/test_acer.sh"

section "Test features"
run "feature: status/report/music" python3 "$ROOT/tests/test_features.py"
run "feature: monitor" python3 "$ROOT/tests/test_monitor.py"
run "feature: apps + startup" python3 "$ROOT/tests/test_tokoro_apps.py"
run "feature: media helpers" python3 "$ROOT/tests/test_media.py"

printf '\n%s\n' "----------------------------------------"
if [[ "$failures" -eq 0 ]]; then
  printf 'all %d checks passed\n' "$total"
  exit 0
fi
printf '%d of %d checks failed\n' "$failures" "$total"
exit 1
