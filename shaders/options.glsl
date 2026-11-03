#ifndef OPTIONS
#define OPTIONS

// ── POST ─────────────────────────────────────────────────────
// Vignette strength multiplier; the falloff shape is fixed in final.glsl.
#define VIGNETTE_AMOUNT 0.5 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
// Pixels at or above this luma are fully included in the bloom chain.
#define BLOOM_THRESHOLD 2.0 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
// Soft-threshold width, as a fraction of BLOOM_THRESHOLD. It defines the lower
// bound of the ramp: threshold * (1 - SMOOTH). 0 = hard cut-off, 1 = everything
// below the threshold still contributes with a linear-ish ramp.
#define BLOOM_THRESHOLD_SMOOTH 0.9 // [0.00 0.05 0.10 0.20 0.30 0.40 0.45 0.50 0.60 0.70 0.80 0.90 1.00]
// Upsample kernel scale. 1.0 = the tent covers one source texel per tap, which
// tops out at roughly half a screen of reach; 2.0 doubles the reach so a light
// on one edge bleeds to the opposite edge.
#define BLOOM_SPREAD 2.0 // [1.0 1.25 1.5 1.75 2.0 2.5 3.0 4.0]
#define BLOOM_STRENGTH 1.0 // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.20 1.40 1.60 1.80 2.00]
#define GAMMA 2.2 // [2.2]

// ── ATMOSPHERE ───────────────────────────────────────────────
// Radiance multiplier applied to the authored sun tint in lib/atmosphere.glsl.
// Purely an exposure match: it has no physical unit.
#define ATMOSPHERE_SUN_INTENSITY 6.5

// Extra gain on the haze phase function, used to keep the horizon glow energy
// roughly unchanged while the lobe weights are tuned.
#define ATMOSPHERE_HAZE_GAIN 1.3

//#define ENABLE_SPECTRAL
#define MULTISCATTERING

// ── DEBUG ────────────────────────────────────────────────────
//#define DEBUG_VIEW

#endif
