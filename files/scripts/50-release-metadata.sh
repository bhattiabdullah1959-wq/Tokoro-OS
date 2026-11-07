#!/usr/bin/env bash
# Writes the release metadata that runtime tools and `tokoro version` read.
set -euo pipefail

echo "::group::Release metadata"

release=/usr/share/tokoro/release.json
[[ -f "$release" ]] || {
  echo "ERROR: $release missing" >&2
  exit 1
}

version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$release")
codename=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["codename"])' "$release")
series=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["series"])' "$release")

install -d -m 0755 /etc/tokoro
printf 'TOKORO_VERSION=%s\nTOKORO_SERIES=%s\nTOKORO_CODENAME=%s\n' \
  "$version" "$series" "$codename" >/etc/tokoro/version
install -m 0644 "$release" /etc/tokoro/release.json

# Text console / tty login banner.
cat >/etc/issue <<EOF
Tokoro OS $version ($codename) \\n \\l
EOF

# `fastfetch` style one-liner used by tokoro banner/doctor.
{
  printf 'version=%s\n' "$version"
  printf 'series=%s\n' "$series"
  printf 'codename=%s\n' "$codename"
} >/etc/tokoro/release.env

echo "release metadata: $version ($codename)"
echo "::endgroup::"
