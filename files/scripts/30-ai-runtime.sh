#!/usr/bin/env bash
# Prepares the AI runtime directories. The runtime itself is NOT downloaded here:
# it is fetched the first time the user turns AI on (`tokoro ai enable`), so
# declining AI during setup downloads nothing at all.
set -euo pipefail

printf '::notice::tokoro-build: %s starting\n' "${0##*/}" >&2
trap 'printf "::error::tokoro-build: %s failed at line %s (rc=%s)\n" "${0##*/}" "${LINENO}" "$?" >&2' ERR

echo "::group::Tokoro AI runtime"
install -d -m 0755 /usr/share/tokoro/ai

if [[ -x /usr/bin/tokoro-ollama ]]; then
  # Images built before 1.2.08 baked the runtime in; keep reporting that.
  echo "baked runtime present: /usr/bin/tokoro-ollama"
else
  echo "runtime is installed on demand (tokoro ai enable); no download at build time"
fi
echo "::endgroup::"
