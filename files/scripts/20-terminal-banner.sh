#!/usr/bin/env bash
# Terminal banner for Tokoro OS.
#
# Bazzite shows its banner from two places: the ublue-os motd template (used by
# ublue-motd for SSH/ptys) and, on interactive local shells, packaged profile
# hooks. We rewrite the template in place and install our own motd/profile hook
# so the banner is correct on every surface.
#
# TOKORO_ROOT lets the test suite run this against a fixture tree.
set -euo pipefail

root="${TOKORO_ROOT:-}"
p() { printf '%s%s' "$root" "$1"; }

motd_template="$(p /usr/share/ublue-os/motd/template.md)"
etc_motd="$(p /etc/motd)"
motd_dir="$(p /etc/motd.d)"
profile_hook="$(p /etc/profile.d/00-tokoro-banner.sh)"

log() { printf 'banner: %s\n' "$*"; }

# --- 1. Rewrite the ublue-os motd template -----------------------------------
if [[ -f "$motd_template" ]]; then
  cp "$motd_template" "${motd_template}.tokoro-orig"

  # Drop upstream community links; keep the rest of the template structure.
  sed -i -E \
    -e '/bazzite\.gg/d' \
    -e '/discord\.gg\/ublue/d' \
    -e '/universal-blue\.org/d' \
    -e '/github\.com\/ublue-os/d' \
    "$motd_template"

  # Headline.
  sed -i -E 's/^#+\s*Welcome to .*/# Welcome to Tokoro OS/' "$motd_template"

  # Any remaining product name. Word-boundary sed keeps URLs and package ids
  # (which we already removed above) from being mangled.
  sed -i -E 's/\bBazzite\b/Tokoro OS/g; s/\bbazzite\b/tokoro-os/g' "$motd_template"

  # Put our own block at the very top so it is the first thing seen. The guard
  # keeps repeated builds from stacking copies of the block.
  if grep -q '^# Tokoro OS' "$motd_template"; then
    log "Tokoro block already present in $motd_template"
  else
    tmp="$(mktemp)"
    {
      cat "$(p /etc/tokoro/motd.md)"
      printf '\n'
      cat "$motd_template"
    } >"$tmp"
    install -m 0644 "$tmp" "$motd_template"
    rm -f "$tmp"
    log "patched $motd_template"
  fi
else
  log "no ublue motd template at $motd_template (skipping)"
fi

# --- 2. /etc/motd.d drop-in (sshd, agetty, login) ----------------------------
if [[ -d "$motd_dir" || "$root" != "" ]]; then
  install -d -m 0755 "$motd_dir"
  install -m 0644 "$(p /etc/tokoro/motd.md)" "$motd_dir/00-tokoro-motd"
  log "installed motd.d drop-in"
fi

# --- 3. /etc/motd itself: only if it is a plain file we own the end of --------
if [[ -f "$etc_motd" ]] && [[ ! -L "$etc_motd" ]]; then
  if ! grep -q 'TOKORO-BANNER' "$etc_motd" 2>/dev/null; then
    {
      printf '\n# TOKORO-BANNER\n'
      cat "$(p /etc/tokoro/motd.md)"
    } >>"$etc_motd"
    log "appended banner to /etc/motd"
  fi
fi

# --- 4. Interactive shell hook ------------------------------------------------
install -d -m 0755 "$(dirname "$profile_hook")"
cat >"$profile_hook" <<'HOOK'
# Tokoro OS banner for interactive shells. Set TOKORO_NO_BANNER=1 to silence.
if [ -z "${TOKORO_NO_BANNER:-}" ] && [ -n "${PS1:-}" ] && [ -x /usr/bin/tokoro ]; then
    if [ -z "${TOKORO_BANNER_SHOWN:-}" ]; then
        TOKORO_BANNER_SHOWN=1
        export TOKORO_BANNER_SHOWN
        /usr/bin/tokoro banner 2>/dev/null || true
    fi
fi
HOOK
chmod 0644 "$profile_hook"
log "installed profile hook"

# --- 5. Fish: keep Bazzite's fish greeting from reappearing ------------------
if [[ -f "$(p /usr/share/fish/vendor_conf.d/00-tokoro.fish)" ]]; then
  log "fish config already present"
else
  install -d -m 0755 "$(p /usr/share/fish/vendor_conf.d)"
  printf '%s\n' 'function fish_greeting; end' \
    >"$(p /usr/share/fish/vendor_conf.d/00-tokoro.fish)"
fi

log "done"
