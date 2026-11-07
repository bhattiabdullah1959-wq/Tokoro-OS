#!/usr/bin/env bash
# shellcheck shell=bash
# Tokoro OS shared shell library. Source it, do not execute it.
#
# Every path can be overridden with an environment variable so the test suite can
# exercise the runtime against fixtures without root or a real Tokoro install.

if [[ -n "${TOKORO_LIB_LOADED:-}" ]]; then
  return 0
fi
TOKORO_LIB_LOADED=1

: "${TOKORO_ETC:=/etc/tokoro}"
: "${TOKORO_SHARE:=/usr/share/tokoro}"
: "${TOKORO_STATE:=/var/lib/tokoro}"
: "${TOKORO_EXEC:=/usr/libexec/tokoro}"
: "${TOKORO_STATE_FILE:=$TOKORO_ETC/tier.conf}"
: "${TOKORO_USER_CONFIG:=${XDG_CONFIG_HOME:-$HOME/.config}/tokoro}"

TOKORO_TIERS=(ultra-performance performance balanced quality ultra-quality)

# --- logging -----------------------------------------------------------------
tokoro_info() { printf '%s\n' "$*"; }
tokoro_warn() { printf 'tokoro: warning: %s\n' "$*" >&2; }
tokoro_die() {
  printf 'tokoro: error: %s\n' "$*" >&2
  exit 1
}

tokoro_have() { command -v "$1" >/dev/null 2>&1; }
tokoro_is_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]]; }
tokoro_require_root() {
  tokoro_is_root || tokoro_die "this action needs root (prefix the command with sudo)"
}

# --- tiers -------------------------------------------------------------------
tokoro_tier_index() {
  local t=$1 i
  for i in "${!TOKORO_TIERS[@]}"; do
    if [[ "${TOKORO_TIERS[$i]}" == "$t" ]]; then
      printf '%s' "$((i + 1))"
      return 0
    fi
  done
  return 1
}

tokoro_tier_valid() { tokoro_tier_index "$1" >/dev/null 2>&1; }

tokoro_tier_from_index() {
  local i=$1
  [[ $i -ge 1 && $i -le ${#TOKORO_TIERS[@]} ]] || return 1
  printf '%s' "${TOKORO_TIERS[$((i - 1))]}"
}

tokoro_tier_label() {
  case "$1" in
    ultra-performance) printf 'Ultra Performance' ;;
    performance) printf 'Performance' ;;
    balanced) printf 'Balanced' ;;
    quality) printf 'Quality' ;;
    ultra-quality) printf 'Ultra Quality' ;;
    *) printf '%s' "$1" ;;
  esac
}

tokoro_tier_conf() { printf '%s/tiers/%s.conf' "$TOKORO_SHARE" "$1"; }

# Loads TIER_* variables for the given tier.
tokoro_tier_load() {
  local tier=$1 f
  tokoro_tier_valid "$tier" || tokoro_die "unknown tier: $tier"
  f=$(tokoro_tier_conf "$tier")
  [[ -r "$f" ]] || tokoro_die "missing tier config: $f"
  # shellcheck disable=SC1090
  . "$f"
}

tokoro_release_get() {
  local key=$1 json=$TOKORO_SHARE/release.json
  [[ -r "$json" ]] || return 1
  python3 - "$json" "$key" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
value = data
for part in sys.argv[2].split("."):
    if not isinstance(value, dict) or part not in value:
        sys.exit(1)
    value = value[part]
print(value)
PY
}

tokoro_version() { tokoro_release_get version 2>/dev/null || printf 'unknown'; }

# --- system state (/etc/tokoro/tier.conf) ------------------------------------
# The file is plain shell assignments and is sourced below.
tokoro_state_load() {
  TOKORO_TIER=""
  TOKORO_RECOMMENDED=""
  TOKORO_OVERRIDE=0
  TOKORO_SET_AT=""
  TOKORO_SET_BY=""
  if [[ -r "$TOKORO_STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    . "$TOKORO_STATE_FILE"
    # Exported because every tool sources this state file in its own process.
    export TOKORO_TIER TOKORO_RECOMMENDED TOKORO_OVERRIDE TOKORO_SET_AT TOKORO_SET_BY
    return 0
  fi
  return 1
}

tokoro_state_save() {
  tokoro_require_root
  install -d -m 0755 "$TOKORO_ETC"
  local tmp
  tmp=$(mktemp)
  {
    printf '# Tokoro OS tier state - written by tokoro-tier, do not edit by hand.\n'
    printf 'TOKORO_TIER=%q\n' "${TOKORO_TIER:-}"
    printf 'TOKORO_RECOMMENDED=%q\n' "${TOKORO_RECOMMENDED:-}"
    printf 'TOKORO_OVERRIDE=%q\n' "${TOKORO_OVERRIDE:-0}"
    printf 'TOKORO_SET_AT=%q\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'TOKORO_SET_BY=%q\n' "${TOKORO_SET_BY:-cli}"
  } >"$tmp"
  install -m 0644 "$tmp" "$TOKORO_STATE_FILE"
  rm -f "$tmp"
}

tokoro_current_tier() {
  tokoro_state_load || true
  if [[ -n "${TOKORO_TIER:-}" ]]; then
    printf '%s' "$TOKORO_TIER"
    return 0
  fi
  printf 'balanced'
}

tokoro_recommended_tier() {
  tokoro_state_load || true
  if [[ -n "${TOKORO_RECOMMENDED:-}" ]]; then
    printf '%s' "$TOKORO_RECOMMENDED"
    return 0
  fi
  printf ''
}

tokoro_is_overridden() {
  tokoro_state_load || true
  [[ "${TOKORO_OVERRIDE:-0}" == "1" ]]
}

# True when the current tier is above the hardware recommendation.
tokoro_is_above_recommendation() {
  local cur rec
  cur=$(tokoro_current_tier)
  rec=$(tokoro_recommended_tier)
  [[ -n "$rec" ]] || return 1
  [[ "$(tokoro_tier_index "$cur")" -gt "$(tokoro_tier_index "$rec")" ]]
}

# --- per-user state for the Plasma applet and tokoro doctor -------------------
tokoro_user_state_path() { printf '%s/tier.json' "$TOKORO_USER_CONFIG"; }

tokoro_user_state_write() {
  local tier=$1 rec=${2:-} override=${3:-$(tokoro_is_overridden && echo 1 || echo 0)} mode=${4:-}
  local path
  path=$(tokoro_user_state_path)
  install -d -m 0755 "$(dirname "$path")"
  [[ -n "$mode" ]] || mode=$(cat "$TOKORO_USER_CONFIG/mode" 2>/dev/null || printf 'work')
  python3 - "$path" "$tier" "$rec" "$override" "$mode" <<'PY'
import json, sys, datetime
path, tier, rec, override, mode = sys.argv[1:6]
warning = bool(rec and tier)
order = ["ultra-performance", "performance", "balanced", "quality", "ultra-quality"]
try:
    warning = bool(rec) and order.index(tier) > order.index(rec)
except ValueError:
    warning = False
data = {
    "tier": tier,
    "recommended": rec or None,
    "overridden": override == "1",
    "above_recommendation": warning,
    "mode": mode,
    "updated": datetime.datetime.now(datetime.timezone.utc)
        .replace(microsecond=0).isoformat().replace("+00:00", "Z"),
}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY
}

# --- KDE helpers -------------------------------------------------------------
tokoro_kwrite() {
  local file=$1 group=$2 key=$3 value=$4
  if tokoro_have kwriteconfig6; then
    kwriteconfig6 --file "$file" --group "$group" --key "$key" "$value"
  elif tokoro_have kwriteconfig5; then
    kwriteconfig5 --file "$file" --group "$group" --key "$key" "$value"
  else
    tokoro_warn "kwriteconfig not found; cannot set $group/$key"
    return 127
  fi
}

tokoro_kwin_reconfigure() {
  if tokoro_have qdbus6; then
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 && return 0
  fi
  if tokoro_have qdbus; then
    qdbus org.kde.KWin /KWin reconfigure >/dev/null 2>&1 && return 0
  fi
  return 1
}

# --- privilege escalation ----------------------------------------------------
# Runs a Tokoro command as root, preferring pkexec so interactive users get a
# graphical prompt (the wizard relies on this).
tokoro_as_root() {
  if tokoro_is_root; then
    "$@"
    return
  fi
  if tokoro_have pkexec; then
    pkexec "$@"
  else
    tokoro_die "root is required and pkexec is unavailable: $*"
  fi
}
