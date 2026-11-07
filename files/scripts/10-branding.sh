#!/usr/bin/env bash
# Tokoro OS branding pass. Everything here is defensive: a missing upstream file
# must never fail the build, because branding paths move between Bazzite releases.
set -euo pipefail

printf '::notice::tokoro-build: %s starting\n' "${0##*/}" >&2
trap 'printf "::error::tokoro-build: %s failed at line %s (rc=%s)\n" "${0##*/}" "${LINENO}" "$?" >&2' ERR

echo "::group::Tokoro OS branding"

# --- Ensure runtime directories exist -----------------------------------------
install -d -m 0755 /etc/tokoro /var/lib/tokoro /usr/share/tokoro

# --- Version metadata readable without jq ------------------------------------
release_json=/usr/share/tokoro/release.json
if [[ -f "$release_json" ]]; then
  version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$release_json")
  codename=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["codename"])' "$release_json")
  printf 'TOKORO_VERSION=%s\nTOKORO_CODENAME=%s\n' "$version" "$codename" >/etc/tokoro/version
else
  echo "WARN: $release_json missing, version metadata not written" >&2
fi

# --- Strip Bazzite references from desktop surfaces --------------------------
# Only touch files we know how to rewrite; unknown files are left alone.
if [[ -f /usr/share/applications/org.bazzite.hello.desktop ]]; then
  sed -i 's/^Name=.*/Name=Tokoro OS Welcome/' /usr/share/applications/org.bazzite.hello.desktop || true
fi

# ujust recipe list: hide upstream recipes we do not support.
if [[ -f /usr/share/ublue-os/justfile ]]; then
  sed -i 's/^# Tokoro OS.*//' /usr/share/ublue-os/justfile || true
fi

# --- Tokoro wallpapers + sound themes are installed by the files module ------
for f in /usr/share/tokoro/wallpapers/tokoro-*.svg; do
  [[ -e "$f" ]] || {
    echo "WARN: no tier wallpapers found" >&2
    break
  }
done

# --- KDE defaults for new users ----------------------------------------------
install -d -m 0755 /etc/xdg
if command -v kwriteconfig6 >/dev/null 2>&1; then
  # Make the Tokoro wallpaper set discoverable in System Settings.
  install -d -m 0755 /usr/share/wallpapers
  for tier in ultra-performance performance balanced quality ultra-quality; do
    src="/usr/share/tokoro/wallpapers/tokoro-$tier.svg"
    [[ -f "$src" ]] || continue
    dst="/usr/share/wallpapers/Tokoro-$tier"
    install -d -m 0755 "$dst"
    install -m 0644 "$src" "$dst/contents/images/2560x1440.svg" 2>/dev/null ||
      install -m 0644 "$src" "$dst/contents/images/1920x1080.svg" 2>/dev/null ||
      true
  done
fi

# --- Branded KDE splash screen (optional, only if we ship the asset) ---------
if [[ -f /usr/share/tokoro/branding/splash.png ]]; then
  install -D -m 0644 /usr/share/tokoro/branding/splash.png \
    /usr/share/plasma/look-and-feel/org.tokoro.desktop/contents/splash/images/splash.png || true
fi

echo "branding applied: ${version:-unknown} (${codename:-unknown})"
echo "::endgroup::"
