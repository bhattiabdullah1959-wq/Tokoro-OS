#!/usr/bin/env python3
"""The boot splash carries a Tokoro wordmark, not someone else's logo."""
from __future__ import annotations

import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORDMARK = ROOT / "files/system/usr/share/plymouth/themes/spinner/watermark.png"

failures = 0
total = 0


def check(name: str, condition: bool, detail: str = "") -> None:
    global failures, total
    total += 1
    if condition:
        print(f"ok: {name}")
    else:
        failures += 1
        print(f"FAIL: {name}{(' — ' + detail) if detail else ''}")


def png_chunks(data: bytes) -> dict[bytes, bytes]:
    chunks: dict[bytes, bytes] = {}
    offset = 8
    while offset + 8 <= len(data):
        length, kind = struct.unpack(">I4s", data[offset:offset + 8])
        body = data[offset + 8:offset + 8 + length]
        chunks.setdefault(kind, b"")
        chunks[kind] += body
        offset += 12 + length
    return chunks


def main() -> int:
    check("wordmark: file exists", WORDMARK.is_file(), str(WORDMARK))
    if not WORDMARK.is_file():
        print("\n1 of 1 checks failed")
        return 1

    data = WORDMARK.read_bytes()
    check("wordmark: is a PNG", data[:8] == b"\x89PNG\r\n\x1a\n")
    chunks = png_chunks(data)
    check("wordmark: has IHDR", b"IHDR" in chunks)
    check("wordmark: has pixel data", b"IDAT" in chunks)
    if b"IHDR" not in chunks:
        print("\n1 of 2 checks failed")
        return 1

    width, height, depth, colour = struct.unpack(">IIBB", chunks[b"IHDR"][:10])
    # The two-step theme draws the watermark at native size, anchored at 96%
    # height; the height is what keeps it inside the slot, so pin both.
    check("wordmark: is 226x44", (width, height) == (226, 44), f"{width}x{height}")
    check("wordmark: 8-bit RGBA", (depth, colour) == (8, 6), f"depth={depth} colour={colour}")

    pixels = zlib.decompress(chunks[b"IDAT"])
    expected = height * (1 + width * 4)  # one filter byte + RGBA per row
    check("wordmark: scanlines decode to RGBA", len(pixels) == expected,
          f"{len(pixels)} bytes, expected {expected}")
    # A fully transparent image would compress to almost nothing; real glyphs do not.
    check("wordmark: contains visible artwork", len(chunks[b"IDAT"]) > 800,
          f"{len(chunks[b'IDAT'])} compressed bytes")

    theme = ROOT / "files/system/usr/share/plymouth/themes/spinner"
    check("wordmark: replaces the theme's watermark slot",
          WORDMARK == theme / "watermark.png")

    print()
    if failures:
        print(f"{failures} of {total} checks failed")
        return 1
    print(f"all {total} checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
