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
// Angular radius of the sun, radians (0.2665 degrees). The disc is small but not
// sub-pixel -- at 1080p with a 70 deg vertical field of view it is about 8 px
// across -- so it is resolved and its profile matters.
const float SUN_ANGULAR_RADIUS_RAD = 0.00465;
// cos(theta) for that radius, from the small-angle form 1 - theta^2 / 2.
const float SUN_DISC_EDGE_COS = 1.0 - 0.5 * SUN_ANGULAR_RADIUS_RAD * SUN_ANGULAR_RADIUS_RAD;

// Normalised distance from the disc centre to the limb: 0 at the centre, 1 at the
// limb. Uses the same small-angle identity, so it needs no acos -- the ratio of
// the two squared angles is the squared radius ratio.
float sunDiscRadius(float cosAngle)
{
    return sqrt(max(0.0, (1.0 - cosAngle) / (1.0 - SUN_DISC_EDGE_COS)));
}

// Limb darkening, normalised to 1 at the disc centre.
//
// Power-law model from
// http://www.physics.hmc.edu/faculty/esin/a101/limbdarkening.pdf:
//     I(mu) / I(1) = 1 - u * (1 - mu^a)
// with the per-wavelength a tabulated for 680 / 550 / 440 nm. u is 1 in this fit
// (the model allows u != 1). Evaluated on mu = cos(angle between the line of
// sight and the local surface normal), which for the projected disc is
// sqrt(1 - rho^2).
//
// The coefficients are per-wavelength while this pack's RGB channels are Rec.709
// primaries, so the match is approximate -- but the effect that matters comes
// through: a is larger in blue, so the limb loses blue faster than red and a low
// sun reddens.
//
// The limb reaches zero at mu = 0, so the disc fades out instead of ending on a
// hard radius.

const float LIMB_DARKENING_INTENSE = 1.5;

vec3 sunDiscLimbDarkening(float rho)
{
    const vec3 u = vec3(1.0);                        // some models have u != 1
    const vec3 a = vec3(0.397, 0.503, 0.652) * LIMB_DARKENING_INTENSE;  // 680 / 550 / 440 nm

    float mu = sqrt(max(0.0, 1.0 - rho * rho));

    return 1.0 - u * (1.0 - pow(vec3(mu), a));
}

// Radiance factor of the solar disc: 0 outside, and inside it the limb-darkening
// profile.
//
// There is deliberately no antialiasing ramp here. Two reasons:
//   - the profile already reaches zero at the limb, so a coverage ramp centred on
//     rho = 1 can only dim the last pixel ring, never soften outward;
//   - the disc is written at ~625 units, which is 150-400x display white after
//     the exposure, so every factor in [0, 1] lands inside the clipped region.
//     A multiplicative ramp cannot bring an overexposed edge below white: the
//     pixel stops being white only once the coverage is under 1/400.
// The edge of the sun is therefore hard, exactly as it is in a photograph. What
// softens it here is the bloom chain, which is the physically right mechanism.
vec3 sunDiscMask(float cosAngle)
{
    float rho = sunDiscRadius(cosAngle);

    // Everything outside the disc returns before the profile. Only a handful of
    // pixels per frame pass this test, and it is coherent across a warp.
    if (rho >= 1.0)
    {
        return vec3(0.0);
    }

    return sunDiscLimbDarkening(rho);
}

vec3 sunDiscMask(float cosAngle, float edgeWidth)
{
    float rho = sunDiscRadius(cosAngle);

    if (rho >= 1.0)
    {
        return vec3(0.0);
    }

    float AA = smoothstep(1.0, 1.0 - edgeWidth, rho);

    return sunDiscLimbDarkening(rho) * AA;
}

// Radiance of the solar disc, cd/m². Solar irradiance divided by the disc solid
// angle (Omega = 6.8e-5 sr) gives 1.9e7 W/m^2/sr; weighted by the luminous
// efficacy of sunlight (~100 lm/W) this is about 1.6e9 cd/m².
//
// This is the value that lighting maths should use. It must never be written to
// a buffer: 8e6 units is 122x the 65504 ceiling of a half float.
const float SUN_DISC_RADIANCE_NITS = 1.6e9;
const float SUN_DISC_RADIANCE      = SUN_DISC_RADIANCE_NITS / NITS_PER_UNIT;

// Fraction of that radiance actually written to a buffer when the disc itself is
// drawn. 1/8 puts it at 1.0e4 units, inside a half float with ~6x headroom; the
// physical 8.0e4 is 1.2x the 65504 ceiling and would overflow to inf. Visually
// ~free: 1.0e4 units is ~10^4 times display white, so the disc clips to the same
// white and still dominates both the sky and the bloom.
const float SUN_DISC_RENDER_SCALE    = 1.0 / 8.0;
const float SUN_DISC_RENDER_RADIANCE = SUN_DISC_RADIANCE * SUN_DISC_RENDER_SCALE;

// ── Sky-view LUT layout ─────────────────────────────────────
// The lowest SKYVIEW_GROUND_FRACTION of the V axis holds the below-horizon half.
const float SKYVIEW_GROUND_FRACTION = 0.125;

#endif
