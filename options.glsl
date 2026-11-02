#ifndef OPTIONS
#define OPTIONS

// ── POST ─────────────────────────────────────────────────────
// Vignette strength multiplier; the falloff shape is fixed in composite_final.
#define VIGNETTE_AMOUNT 0.5 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define BLOOM_THRESHOLD 1.0 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define BLOOM_KNEE 0.95 // [0.01 0.02 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50]
#define BLOOM_MIN 0.45 // [0.01 0.02 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50]
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
