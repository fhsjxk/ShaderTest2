#ifndef OPTIONS
#define OPTIONS

// ── POST ─────────────────────────────────────────────────────
// Vignette strength multiplier; the falloff shape is fixed in final.glsl.
#define VIGNETTE_AMOUNT 0.5 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
// How the blurred chain is fed and recombined. These are two different looks,
// not two quality levels:
//
//   0  Soft haze / veiling glare. The whole frame (no threshold) is blurred and
//      the final image is lerped toward it, so highlights give up a little
//      energy and shadows pick some up. Closest to what a lens actually does --
//      scattering redistributes energy rather than adding it -- and reads as
//      slightly hazy and warm, which suits Minecraft.
//   1  Cinematic bloom. Only pixels above BLOOM_THRESHOLD enter, and the result
//      is added, so highlights gain energy. Sharper and more film-like.
//
// BLOOM_STRENGTH means different things per mode: the lerp weight in mode 0, the
// additive gain in mode 1.
//
// The pyramid is a *sum* of BLOOM_LEVELS normalised blurs, so in mode 0 a flat
// area leaves the mix at (1 + STRENGTH * (levels - 1)) times its original value:
// 1.40x at 1080p and 1.45x at 4K, because a level that collapses to 1x1 is
// skipped. That count is resolution dependent, so mode 0's overall brightness
// shifts slightly with window size. See docs/DESIGN_GOALS.md §4.4.
#define BLOOM_MODE 0

// Mode 0: fraction of the blurred sum mixed in. Mode 1: gain on the thresholded
// bloom. In mode 1 the values below ~0.1 are a better starting point.
#define BLOOM_STRENGTH 0.05 // [0.00 0.01 0.02 0.03 0.05 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.20 1.40 1.60 1.80 2.00]
#define BLOOM_MIN_STRENGTH 0.05
// Pixels at or above this display-referred value bloom. The chain runs after the
// exposure, so 1.0 = display white and 3.0 = three stops over.
#define BLOOM_THRESHOLD 5.0 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
// Soft-threshold width, as a fraction of BLOOM_THRESHOLD. It defines the lower
// bound of the ramp: threshold * (1 - SMOOTH). 0 = hard cut-off, 1 = everything
// below the threshold still contributes with a linear-ish ramp.
#define BLOOM_THRESHOLD_SMOOTH 0.7 // [0.00 0.05 0.10 0.20 0.30 0.40 0.45 0.50 0.60 0.70 0.80 0.90 1.00]
// Upsample kernel scale. 1.0 = the tent covers one source texel per tap, which
// tops out at roughly half a screen of reach; 2.0 doubles the reach so a light
// on one edge bleeds to the opposite edge.
#define BLOOM_SPREAD 1.0 // [1.0 1.25 1.5 1.75 2.0 2.5 3.0 4.0]
#define GAMMA 2.2 // [2.2]


// 选项后面的[1.0 1.25 1.5 1.75 2.0 2.5 3.0 4.0]应该允许程序化生成，在构建脚本中添加这个功能，允许选项密度指数级/幂级分布，以及高斯分布、smoothstep分布等

// ── DEV ──────────────────────────────────────────────────────
// Write-side guard level for half-float buffers, see lib/utility/guards.glsl.
//
//   0  off     no guard at all; use when bisecting an artifact
//   1  finite  clamp to the half-float range, NaN passes through   (default)
//   2  full    additionally replace NaN with black
//
// Level 1 exists because the two failures are not equivalent: an overflow is
// invisible where it happens and then poisons every downstream blur and the
// exposure measure, while a NaN *is* the bug and should stay visible.
#define GUARD_LEVEL 1

// ── ATMOSPHERE ───────────────────────────────────────────────
// Physical quantities live in lib/atmosphere/constants.glsl (solar illuminance,
// scattering coefficients, ground albedo). Nothing to tune here: the scene
// brightness is normalised by the auto-exposure, not by an atmosphere gain.

//#define ENABLE_SPECTRAL
#define MULTISCATTERING
// Which multiple-scattering model to use when MULTISCATTERING is enabled.
//   0  cheap analytic two-term approximation (ground bounce + one tuned lobe)
//   1  SEBH20 / Hillaire 2020: 32x32 isotropic transfer LUT built by prepare2
// The LUT costs ~64 single-scattering marches per texel on a 32x32 grid but makes
// the per-sample cost cheaper (one fetch instead of three).
#define MULTISCATTERING_METHOD 1 // [0 1]

// ── Tone mapping ─────────────────────────────────
// Applied in the final pass to the display-referred radiance (scene radiance times
// the auto-exposure).
//   0  ACES, Narkowicz fit -- long filmic shoulder, slightly desaturated highlights
//   1  GT7 (Gran Turismo 7) -- linear up to 0.76, rational shoulder above it,
//      highlights pushed towards white. Brighter at the white point (0.869 vs
//      0.804 at 1.0), so switching may want a lower EXPOSURE_TARGET.
#define TONEMAP_OPERATOR 0 // [0 1]

// ── Aerial perspective (froxel fog) ──────────────
// The stack is 16 slices over a fixed 128 km, squared in depth, and the march runs
// to the end of the medium along the view ray -- the top of the atmosphere or the
// ground, whichever it reaches first (see lib/atmosphere/aerial.glsl). Nothing caps
// the distance any earlier, so the stack is always integrated in full.
//
// How far the fog reaches, relative to the physical atmosphere. 1.0 is the real
// density at the real scale. 2.0 stretches the fog over twice the distance
// (thinner at a given range, clearer vistas), 0.5 packs it into half the range
// (denser haze). This scales the fog's extinction only; the sky keeps the physical
// scale, so at strong values the horizon and the fog can disagree slightly.
//
// Implemented by dividing both the lookup distance and the march cut-off by the
// scale, which is what makes the option stretch the distance axis rather than just
// clip it. The render distance is deliberately not involved, because the pass that
// builds the stack draws no geometry and cannot read `far` reliably.

#define FOG_DISTANCE_SCALE 1.0

// ── DEBUG ────────────────────────────────────────────────────
//#define DEBUG_VIEW

#endif
