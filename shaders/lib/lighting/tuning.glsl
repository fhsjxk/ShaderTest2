// Lighting and exposure tuning
//
// Everything here is a physical quantity in the pack's colour unit
// (1 unit = NITS_PER_UNIT = 200 cd/m², see lib/utility/units.glsl), or a
// dimensionless ratio. Nothing is an arbitrary brightness gain: scene brightness
// comes from the light sources below and is normalised by the auto-exposure, not
// by a per-term multiplier.

#ifndef LIGHTING_TUNING
#define LIGHTING_TUNING

#include "/lib/prelude.glsl"

// ── Light sources, as illuminance on the receiving surface ──
// Sunlight comes from SUN_ILLUMINANCE_LUX in the atmosphere constants and is
// attenuated by the transmittance LUT; only these two sources live here.

// Clear-sky horizontal illuminance at midday, lux (10-20 klx on a clear day).
const float SKY_ILLUMINANCE_LUX = 20000.0;

// Illuminance from one full-strength block light, lux. A hand-held flame is of
// the order of 20 lux at close range; Minecraft's lightmap is used as the
// fraction of that.
const float BLOCK_LIGHT_ILLUMINANCE_LUX = 20.0;

// ── Surface ─────────────────────────────────────────────────
// Placeholder material: there is no roughness/metalness input yet, so every
// surface uses the same dielectric parameters.
const float SURFACE_ROUGHNESS = 0.75;
const vec3  SURFACE_F0        = vec3(0.04);   // dielectric reflectance (~4%)
const float SURFACE_F90       = 0.3;

// ── Fake GI (medium quality) ────────────────────────────────
// Stands in for the light a real GI solution would bounce from the surroundings
// onto shadowed, sky-starved geometry. Not physical: it adds irradiance in
// proportion to how much sky and sun the surface is missing.
// Higher quality tiers replace this with a physical method, so these two values
// only describe the cheap path.
//
// FAKE_GI_GAIN is the amplitude; FAKE_GI_SATURATION is how much of that gain is
// expressed as a saturation lift on the surface albedo, standing in for colour
// bleeding from the surroundings.
const float FAKE_GI_GAIN       = 1.0;
const float FAKE_GI_SATURATION = 0.05;

// ── Auto exposure ───────────────────────────────────────────
// The measure pass writes log2(luma) per screen block plus a centre weight; the
// adapt pass takes their weighted geometric mean and turns it into one
// multiplier that maps colour units to display-referred values. Both passes
// hard-code the log encoding: the producer and the consumer must agree, so it is
// not a setting. Degenerate values are guarded with the global EPS.

// The reference scene the unit scale is calibrated for: a clear morning, looking
// level across a grassy plain with some trees and hills. This is that frame's
// geometric-mean luma in colour units -- exactly what the measure pass produces
// for it, not something derivable from the other constants. Read it back out of
// RT_LUM after large lighting changes; at the current tuning it is ~0.35.
const float EXPOSURE_REFERENCE_LUMA = 0.15;

// Gain applied to the reference scene. 1.0 leaves it alone.
const float EXPOSURE_TARGET = 1.0;

// How far the exposure compensates for the scene differing from the reference:
//
//   exposure = TARGET * (REFERENCE_LUMA / averageLuma)^STRENGTH
//
//   0 -> exposure == TARGET for every frame: no adaptation at all, the reference
//        scene is untouched but a cave stays black.
//   1 -> every frame is normalised so its average lands on TARGET * REFERENCE_LUMA.
//
// TARGET is the reference scene's gain, so the reference frame comes out at
// exposure 1 for any STRENGTH as long as TARGET is 1.
const float EXPOSURE_ADAPT_STRENGTH = 0.5;

// Exponential adaptation rate, 1/s. Time constant is 1/rate (0.67 s at 1.5).
const float EXPOSURE_ADAPT_RATE = 1.5;

// Centre weighting: weight = exp(-r2 * value) with r2 the squared UV distance
// from the centre (0 at centre, 0.5 at a corner), so a corner keeps
// exp(-0.5 * value) = 0.223 of the centre's vote at the default 3.0.
const float EXPOSURE_CENTER_FALLOFF = 8.0;

// Clamp on the multiplier: -10 / +10 stops around the reference scene.
const float EXPOSURE_MIN = 0.05;
const float EXPOSURE_MAX = 10.0;

#endif
