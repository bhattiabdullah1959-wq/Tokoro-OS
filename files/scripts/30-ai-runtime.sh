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

dest=/usr/libexec/tokoro/ollama
marker=/usr/share/tokoro/ai/RUNTIME_MISSING
archive=/tmp/ollama-runtime

# This whole component is optional, so every failure path ends here: record why
# the runtime is absent and finish successfully instead of failing the image.
give_up() {
  echo "WARN: $1" >&2
  printf 'image built without the Tokoro AI runtime (%s)\n' "$1" >"$marker"
  echo "::endgroup::"
  rm -f "$archive" "$archive".zst
  exit 0
}

echo "::group::Tokoro AI runtime (Ollama ${OLLAMA_VERSION})"
install -d -m 0755 /usr/share/tokoro/ai "$dest"

# Upstream publishes .tgz, .tar.gz or .tar.zst depending on the release, so probe
# the plain asset names rather than globbing: a glob also matches the -rocm and
# -mlx variants, which are not a base runtime.
asset=""
for candidate in "ollama-linux-${OLLAMA_ARCH}.tgz" \
  "ollama-linux-${OLLAMA_ARCH}.tar.gz" \
  "ollama-linux-${OLLAMA_ARCH}.tar.zst"; do
  if curl --fail --location --silent --head --max-time 20 \
    --output /dev/null "${base}/${candidate}"; then
    asset="$candidate"
    break
  fi
done
if [[ -z "$asset" ]]; then
  give_up "no Linux asset published for Ollama v${OLLAMA_VERSION}"
fi
echo "asset: ${asset}"

if ! curl --fail --location --retry 3 --retry-delay 2 --connect-timeout 20 \
  --output "$archive" "${base}/${asset}"; then
  give_up "could not download ${base}/${asset}"
fi

case "$asset" in
  *.zst)
    if command -v unzstd >/dev/null 2>&1; then
      unzstd -c "$archive" | tar -xf - -C "$dest" || give_up "could not extract ${asset}"
    elif tar --zstd -xf "$archive" -C "$dest" 2>/dev/null; then
      :
    else
      give_up "could not extract ${asset}: no zstd support in the image"
    fi
    ;;
  *)
    tar -xzf "$archive" -C "$dest" || give_up "could not extract ${asset}"
    ;;
esac
rm -f "$archive"

if [[ ! -x "$dest/bin/ollama" ]]; then
  give_up "archive ${asset} did not contain bin/ollama"
fi

# Stable wrapper so services never depend on the internal layout.
install -d -m 0755 /usr/libexec/tokoro/ollama/bin
ln -sfn "$dest/bin/ollama" /usr/bin/tokoro-ollama

rm -f "$marker"
"$dest/bin/ollama" --version || echo "WARN: ollama --version failed at build time" >&2

echo "installed $( "$dest/bin/ollama" --version 2>/dev/null | head -n1 || echo ollama )"
echo "::endgroup::"
