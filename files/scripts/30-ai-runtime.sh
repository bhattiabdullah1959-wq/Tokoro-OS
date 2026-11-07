#!/usr/bin/env bash
# Installs the local AI runtime (Ollama) used by Tokoro AI.
#
# The runtime is optional at the image level: if the download fails we leave a
# marker so `tokoro ai status` can explain the image was built without it,
# instead of shipping a silently broken feature.
set -euo pipefail

printf '::notice::tokoro-build: %s starting\n' "${0##*/}" >&2
trap 'printf "::error::tokoro-build: %s failed at line %s (rc=%s)\n" "${0##*/}" "${LINENO}" "$?" >&2' ERR

OLLAMA_VERSION="${OLLAMA_VERSION:-0.40.15}"
OLLAMA_ARCH="${OLLAMA_ARCH:-amd64}"
base="https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}"
assets_page="https://github.com/ollama/ollama/releases/expanded_assets/v${OLLAMA_VERSION}"

# Asset names have changed between releases, so discover the right one from the
# release page instead of hard-coding it. Fall back to the historical name.
#
# Discovery is best-effort and this whole script is optional, so no step in it
# may fail the build: grep exits 1 when nothing matches, and `head -n1` closing
# the pipe early makes the pipeline die of SIGPIPE under `pipefail`.
asset=""
assets_file=/tmp/ollama-assets.html
curl -fsSL --max-time 30 "$assets_page" --output "$assets_file" 2>/dev/null || true
if [[ -s "$assets_file" ]]; then
  asset=$(grep -oE "ollama-linux-${OLLAMA_ARCH}[A-Za-z0-9_.-]*\.(tgz|tar\.gz)" "$assets_file" |
    sort -u | head -n1 || true)
fi
rm -f "$assets_file"
if [[ -z "$asset" ]]; then
  echo "WARN: could not discover a Linux asset for Ollama v${OLLAMA_VERSION}" >&2
  asset="ollama-linux-${OLLAMA_ARCH}.tgz"
fi
echo "asset: ${asset}"
dest=/usr/libexec/tokoro/ollama
marker=/usr/share/tokoro/ai/RUNTIME_MISSING

echo "::group::Tokoro AI runtime (Ollama ${OLLAMA_VERSION})"
install -d -m 0755 /usr/share/tokoro/ai "$dest"

if ! curl --fail --location --retry 3 --retry-delay 2 --connect-timeout 20 \
  --output /tmp/ollama.tgz "${base}/${asset}"; then
  echo "WARN: could not download ${base}/${asset}" >&2
  printf 'image built without the Tokoro AI runtime (%s unavailable)\n' "$asset" >"$marker"
  echo "::endgroup::"
  exit 0
fi

if ! tar -xzf /tmp/ollama.tgz -C "$dest"; then
  echo "WARN: ${asset} could not be extracted" >&2
  printf 'image built with an unusable Tokoro AI runtime archive (%s)\n' "$asset" >"$marker"
  echo "::endgroup::"
  rm -f /tmp/ollama.tgz
  exit 0
fi
rm -f /tmp/ollama.tgz

if [[ ! -x "$dest/bin/ollama" ]]; then
  echo "WARN: tarball did not contain bin/ollama" >&2
  printf 'image built with a broken Tokoro AI runtime archive\n' >"$marker"
  echo "::endgroup::"
  exit 0
fi

# Stable wrapper so services never depend on the internal layout.
install -d -m 0755 /usr/libexec/tokoro/ollama/bin
ln -sfn "$dest/bin/ollama" /usr/bin/tokoro-ollama

rm -f "$marker"
"$dest/bin/ollama" --version || echo "WARN: ollama --version failed at build time" >&2

echo "installed $( "$dest/bin/ollama" --version 2>/dev/null | head -n1 || echo ollama )"
echo "::endgroup::"
