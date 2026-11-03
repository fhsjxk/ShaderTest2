// Bridge between the Minecraft scene and the atmosphere model
//
// Atmosphere model split by responsibility. Dependencies are one-way:
//   constants -> {geometry, phase, medium} -> transmittance -> scattering
// `scene` and `skyview` only depend on constants.
//
// Units: distances km, coefficients 1/km, radiance scene-linear unitless.
// See constants.glsl for the provenance of every physical number.

#ifndef ATMOSPHERE_SCENE
#define ATMOSPHERE_SCENE

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"

// ═══ Scene glue ═════════════════════════════════════════════
// Minecraft's Y axis is in blocks; the atmosphere model is in km. 1 block =
// 0.02 km keeps the horizon at the height it has with the vanilla sky.
const float MC_SEA_LEVEL    = 64.0;
const float KM_PER_BLOCK    = 0.02;
const float MIN_ALTITUDE_KM = 0.001;

float altitudeFromEyePosition(float eyePosition)
{
    return max((eyePosition - MC_SEA_LEVEL) * KM_PER_BLOCK, MIN_ALTITUDE_KM);
}

// The sun disc is far smaller than a pixel, so it is faked by a very tight
// smoothstep scaled up by SUN_DISC_RADIANCE to keep the integrated energy.
// Fade bounds are the cosines of ~0.33° and ~0.26°; step() keeps the disc from
// bleeding outside the sun's angular radius.
const float SUN_DISC_FADE_START   = 0.999983;
const float SUN_DISC_FADE_END     = 1.00005;
const float SUN_DISC_EDGE_COS     = 0.9999893;
const float SUN_DISC_MIN_FRACTION = 0.02;
const float SUN_DISC_RADIANCE     = 1000.0;

float sunDiscMask(float cosAngle)
{
    float disc = smoothstep(SUN_DISC_FADE_START, SUN_DISC_FADE_END, cosAngle);
    return (disc * (1.0 - SUN_DISC_MIN_FRACTION) + SUN_DISC_MIN_FRACTION) * step(SUN_DISC_EDGE_COS, cosAngle);
}

#endif
