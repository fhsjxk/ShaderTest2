#ifndef OPTIONS
#define OPTIONS

// ── POST ─────────────────────────────────────────────────────
// Vignette strength multiplier; the falloff shape is fixed in final.glsl.
#define VIGNETTE_AMOUNT 0.5 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
// Overall bloom gain applied when the chain is added back in final.glsl.
#define BLOOM_STRENGTH 1.0 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.20 1.40 1.60 1.80 2.00]
#define BLOOM_MIN_STRENGTH 0.05
// Pixels at or above this display-referred value bloom. The chain runs after the
// exposure, so 1.0 = display white and 3.0 = three stops over.
#define BLOOM_THRESHOLD 3.0 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
// Soft-threshold width, as a fraction of BLOOM_THRESHOLD. It defines the lower
// bound of the ramp: threshold * (1 - SMOOTH). 0 = hard cut-off, 1 = everything
// below the threshold still contributes with a linear-ish ramp.
#define BLOOM_THRESHOLD_SMOOTH 0.8 // [0.00 0.05 0.10 0.20 0.30 0.40 0.45 0.50 0.60 0.70 0.80 0.90 1.00]
// Upsample kernel scale. 1.0 = the tent covers one source texel per tap, which
// tops out at roughly half a screen of reach; 2.0 doubles the reach so a light
// on one edge bleeds to the opposite edge.
#define BLOOM_SPREAD 2.0 // [1.0 1.25 1.5 1.75 2.0 2.5 3.0 4.0]
#define GAMMA 2.2 // [2.2]

// ── ATMOSPHERE ───────────────────────────────────────────────
// Physical quantities live in lib/atmosphere/constants.glsl (solar illuminance,
// scattering coefficients, ground albedo). Nothing to tune here: the scene
// brightness is normalised by the auto-exposure, not by an atmosphere gain.

//#define ENABLE_SPECTRAL
#define MULTISCATTERING

// ── DEBUG ────────────────────────────────────────────────────
//#define DEBUG_VIEW

#endif
