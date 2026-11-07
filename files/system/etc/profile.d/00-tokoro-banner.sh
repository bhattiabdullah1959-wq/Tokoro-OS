# Tokoro OS banner for interactive shells. Set TOKORO_NO_BANNER=1 to silence.
if [ -z "${TOKORO_NO_BANNER:-}" ] && [ -n "${PS1:-}" ] && [ -x /usr/bin/tokoro ]; then
    if [ -z "${TOKORO_BANNER_SHOWN:-}" ]; then
        TOKORO_BANNER_SHOWN=1
        export TOKORO_BANNER_SHOWN
        /usr/bin/tokoro banner 2>/dev/null || true
    fi
fi
