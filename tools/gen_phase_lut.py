"""Turn the COMPA phase LUTs into the raw texture the pack samples.

Source of truth is `realtime_params.json` from the OPAC fitting project
(`PYTest/COMPA`). It holds four phase tables, one per AOD bin, all normalised so
that the integral of p over the sphere equals 4*pi.

The four tables are packed into the four channels of one Nx1 RGBA16F texture, so
a single bilinear fetch returns all four bins and the shader blends them with a
dot product. That is why the texture is RGBA: R = bin 0 .. A = bin 3.

`N` is taken from the JSON rather than hard-coded, and the two other places that
must agree -- the `customTexture.phaseLutTex` line in shaders.properties and
AEROSOL_PHASE_LUT_SIZE in lib/atmosphere/phase.glsl -- are verified afterwards.
A mismatch there does not fail to compile, it silently samples the wrong angle,
so it is checked instead of trusted.

Run from the repository root:

    python tools/gen_phase_lut.py
"""

from __future__ import annotations

import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = Path(r"E:\Users\qwert\Desktop\PYTest\COMPA\outputs\realtime_params.json")
TARGET = ROOT / "shaders" / "textures" / "phase_lut.dat"
PROPERTIES = ROOT / "shaders" / "shaders.properties"
PHASE_GLSL = ROOT / "shaders" / "lib" / "atmosphere" / "phase.glsl"
CONSTANTS_GLSL = ROOT / "shaders" / "lib" / "atmosphere" / "constants.glsl"

BIN_COUNT = 4


def main() -> None:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    phase = data["phase"]
    bins = phase["bins"]
    lut_size = int(phase["meta"]["lut_size"])

    if len(bins) != BIN_COUNT:
        raise SystemExit(f"expected {BIN_COUNT} AOD bins, found {len(bins)}")

    tables = []
    for entry in bins:
        lut = entry["lut"]
        if len(lut) != lut_size:
            raise SystemExit(f"AOD {entry['aod_550']}: expected {lut_size} entries, found {len(lut)}")
        tables.append(lut)

    # Interleaved RGBA, little-endian half floats: texel i holds the four bins'
    # value at the same angle, which is what lets one fetch serve all of them.
    payload = bytearray()
    for i in range(lut_size):
        for channel in range(BIN_COUNT):
            payload += struct.pack("<e", tables[channel][i])

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_bytes(bytes(payload))

    print(f"wrote {TARGET} ({len(payload)} bytes, {lut_size}x1 RGBA16F)")
    print()
    print("AOD bin edges (shaders/lib/atmosphere/constants.glsl):")
    for i, entry in enumerate(bins):
        print(f"  bin {i}: aod = {entry['aod_550']:.17g}")
    print()
    print("Per-channel scattering gain (same file, AEROSOL_GAIN_BIN*):")
    for i, entry in enumerate(bins):
        k = entry["channel"]["k_b"]
        print(f"  bin {i}: vec3({k[0]:.5f}, {k[1]:.5f}, {k[2]:.5f})")
    print()
    print("Sanity: a phase table must average to 1 over the sphere")
    for i, table in enumerate(tables):
        # dOmega = 8*pi*u*du with u = sqrt(0.5*(1-cos)), so the mean is
        # 2 * integral_0^1 p(u) * u du.
        total = 0.0
        for j in range(lut_size - 1):
            u0, u1 = j / (lut_size - 1), (j + 1) / (lut_size - 1)
            total += 0.5 * (table[j] * u0 + table[j + 1] * u1) * (u1 - u0)
        print(f"  bin {i}: mean = {2.0 * total:.4f}")

    # ── the other declarations ──────────────────────────────────
    print()
    problems = []

    props = PROPERTIES.read_text(encoding="utf-8")
    expected_props = f"RGBA16F {lut_size} 1 RGBA HALF_FLOAT"
    if expected_props not in props:
        problems.append(f"shaders.properties: the phaseLutTex line must contain `{expected_props}`")

    glsl = PHASE_GLSL.read_text(encoding="utf-8")
    expected_glsl = f"AEROSOL_PHASE_LUT_SIZE = {lut_size}"
    if expected_glsl not in glsl:
        problems.append(f"lib/atmosphere/phase.glsl: must contain `{expected_glsl}`")

    # The AOD edges and the per-bin gains live in constants.glsl and have to be
    # copied across by hand, so they are checked too: a stale gain scales the
    # whole sky's brightness and nothing would flag it.
    constants = CONSTANTS_GLSL.read_text(encoding="utf-8")

    def vec3_of(name: str) -> list[float] | None:
        m = re.search(rf"{name}\s*=\s*vec3\(([^)]*)\)", constants)
        if not m:
            return None
        return [float(v) for v in m.group(1).split(",")]

    for i, entry in enumerate(bins):
        m = re.search(rf"AEROSOL_AOD_BIN_{i}\s*=\s*([0-9.eE+-]+)", constants)
        if not m or abs(float(m.group(1)) - entry["aod_550"]) > 1e-12:
            problems.append(f"constants.glsl: AEROSOL_AOD_BIN_{i} != {entry['aod_550']:.17g}")

        have = vec3_of(f"AEROSOL_GAIN_BIN_{i}")
        want = entry["channel"]["k_b"]
        if have is None:
            problems.append(f"constants.glsl: AEROSOL_GAIN_BIN_{i} missing")
        elif any(abs(a - b) / max(abs(b), 1e-9) > 1e-4 for a, b in zip(have, want)):
            problems.append(f"constants.glsl: AEROSOL_GAIN_BIN_{i} is {have}, JSON says {[round(v, 5) for v in want]}")

    if problems:
        print("MISMATCH -- the shader would use stale data:")
        for line in problems:
            print("  " + line)
        raise SystemExit(1)

    print(f"declarations agree on N = {lut_size}")
    print("constants.glsl agrees on the AOD edges and all four gains")


if __name__ == "__main__":
    main()
