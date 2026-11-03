// Bridge between the Minecraft scene and the atmosphere model
//
// Depends only on constants. Units follow constants.glsl, except the sun disc,
// whose radiance is given in cd/m² and converted here.

#ifndef ATMOSPHERE_SCENE
#define ATMOSPHERE_SCENE

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"

// ── Minecraft space -> atmosphere space ─────────────────────
// Minecraft's Y axis is in blocks, the model is in km. 1 block = 0.02 km keeps
// the horizon at the height the vanilla sky has.
const float MC_SEA_LEVEL    = 64.0;
const float KM_PER_BLOCK    = 0.02;
const float MIN_ALTITUDE_KM = 0.001;

float altitudeFromEyePosition(float eyePosition)
{
    return max((eyePosition - MC_SEA_LEVEL) * KM_PER_BLOCK, MIN_ALTITUDE_KM);
}

// ── Sun disc ────────────────────────────────────────────────
// Angular radius of the sun, radians (0.2665 degrees). The disc is far smaller
// than a pixel, so the mask is a narrow smoothstep over the cosine of the angle
// rather than a resolved disc.
const float SUN_ANGULAR_RADIUS_RAD = 0.00465;
// cos(theta) for that radius, from the small-angle form 1 - theta^2 / 2.
const float SUN_DISC_EDGE_COS = 1.0 - 0.5 * SUN_ANGULAR_RADIUS_RAD * SUN_ANGULAR_RADIUS_RAD;
// Half width of the anti-aliasing ramp, in cosine units (~0.1 degree).
const float SUN_DISC_FADE_HALF_WIDTH = 1.6e-5;

// Radiance of the solar disc, cd/m². Solar irradiance divided by the disc solid
// angle (Omega = 6.8e-5 sr) gives 1.9e7 W/m^2/sr; weighted by the luminous
// efficacy of sunlight (~100 lm/W) this is about 1.6e9 cd/m².
//
// This is the value that lighting maths should use. It must never be written to
// a buffer: 8e6 units is 122x the 65504 ceiling of a half float.
const float SUN_DISC_RADIANCE_NITS = 1.6e9;
const float SUN_DISC_RADIANCE      = SUN_DISC_RADIANCE_NITS / NITS_PER_UNIT;

// Fraction of that radiance actually written to a buffer when the disc itself is
// drawn. 1/256 puts it at 3.1e4 units, inside a half float with ~2x headroom; the
// obvious 1/100 still lands at 8.0e4 and would overflow to inf. Visually ~free:
// 3.1e4 units is ~10^4 times display white, so the disc clips to the same white
// and still dominates both the sky and the bloom.
const float SUN_DISC_RENDER_SCALE    = 1.0 / 128.0;
const float SUN_DISC_RENDER_RADIANCE = SUN_DISC_RADIANCE * SUN_DISC_RENDER_SCALE;

// Weight of the solar disc, 0 outside the disc and 1 inside.
float sunDiscMask(float cosAngle)
{
    return smoothstep(SUN_DISC_EDGE_COS - SUN_DISC_FADE_HALF_WIDTH,
                      SUN_DISC_EDGE_COS + SUN_DISC_FADE_HALF_WIDTH,
                      cosAngle);
}

// ── Sky-view LUT layout ─────────────────────────────────────
// The lowest SKYVIEW_GROUND_FRACTION of the V axis holds the below-horizon half.
const float SKYVIEW_GROUND_FRACTION = 0.125;

#endif
