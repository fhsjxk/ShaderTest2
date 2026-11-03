#ifndef LIGHTING_TUNING
#define LIGHTING_TUNING

// Lighting model tuning. Every value here is a look-development constant, not a
// physical quantity; keep them together so the whole look can be adjusted in
// one place and so the pass files stay pure implementation.

#include "/lib/prelude.glsl"

// Stands in for the multiple scattering this single-bounce model cannot
// resolve; it also lifts the fake GI on shadowed surfaces.
const float SUN_SCATTER_GAIN    = 2.5;
const float FAKE_GI_STRENGTH    = 0.05;

const vec3  AMBIENT_SKY_TINT    = vec3(0.5, 0.65, 1.0);
const float AMBIENT_GAIN        = 0.75;

const float LOCAL_LIGHT_EXP     = 3.0;
const vec3  LOCAL_LIGHT_TINT    = vec3(1.0, 0.6, 0.2);

const float MASTER_GAIN         = 0.6;

const float SPECULAR_ROUGHNESS  = 0.75;
const float SPECULAR_F0         = 0.03;
const float SPECULAR_F0_GRAZING = 0.15;
const float SPECULAR_GAIN       = 0.3;

// ── Auto exposure ───────────────────────────────────────────
// The measure pass stores log2(luma) with a centre weight; the adapt pass takes
// their weighted mean and turns it into a multiplier.
const int   EXPOSURE_MEASURE_TAPS    = 4;      // taps per axis inside one block
const int   EXPOSURE_USE_LOG         = 1;      // 1: log2 average (perceptual), 0: sqrt
const float EXPOSURE_EPS             = 1e-4;
const float EXPOSURE_CENTER_FALLOFF  = 2.0;    // 0 = uniform, larger = centre biased
const float EXPOSURE_KEY             = 0.35;   // target multiplier at luma 1.0
const float EXPOSURE_CURVE           = 0.7;    // luma compression before the key
const float EXPOSURE_ADAPT_SPEED     = 2.0;    // 1/s, time constant of the adaptation
const float EXPOSURE_MIN             = 0.05;   // clamp on the multiplier
const float EXPOSURE_MAX             = 20.0;
const float EXPOSURE_INITIAL         = 1.0;    // seed value for the first frame

#endif
