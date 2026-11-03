// Atmosphere constants and parameter set
//
// Atmosphere model split by responsibility. Dependencies are one-way:
//   constants -> {geometry, phase, medium} -> transmittance -> scattering
// `scene` and `skyview` only depend on constants.
//
// Units: distances km, coefficients 1/km, radiance scene-linear unitless.
// See constants.glsl for the provenance of every physical number.

#ifndef ATMOSPHERE_CONSTANTS
#define ATMOSPHERE_CONSTANTS

#include "/lib/prelude.glsl"

const int TRANSMITTANCE_STEPS = 32;
const int INSCATTERING_STEPS  = 32;

const float PLANET_RADIUS        = 6371.0;
const float ATMOSPHERE_THICKNESS = 100.0;
const float ATMOSPHERE_RADIUS    = PLANET_RADIUS + ATMOSPHERE_THICKNESS;

#ifdef ENABLE_SPECTRAL
#define vec34 vec4
#else
#define vec34 vec3
#endif

// Authored 0-255 tint → 0..1, used un-decoded (see header).
#define UNIT_TINT(r, g, b) (vec3(r, g, b) / 255.0)

#ifdef ENABLE_SPECTRAL

// Four spectral bands. Radiance is band-integrated, not per-nanometre.
const vec4 SUN_RADIANCE = vec4(1.68, 1.83, 1.99, 1.31);

const vec4 RAYLEIGH_SCATTERING_BASE = vec4(6.605e-3, 1.067e-2, 1.842e-2, 3.156e-2);

const vec4 OZONE_ABSORPTION_BASE    = vec4(3.472e-3, 3.914e-3, 1.349e-3, 11.03e-5) * 0.5;

const vec4 AEROSOL_ABSORPTION_BASE  = vec4(1.0) * 0.0003;
const vec4 AEROSOL_SCATTERING_BASE  = vec4(1.5908, 1.7711, 2.0942, 2.4033) * 0.6 * 0.035;

// Same tint as the RGB path, expressed as the pre-image of rgbFromSpectral.
const vec4 GROUND_ALBEDO = vec4(0.57, 0.45, 0.37, 0.8) * 0.1;

#else

// Scene radiance of the sun disc; ATMOSPHERE_SUN_INTENSITY is the exposure knob.
const vec3 SUN_RADIANCE = UNIT_TINT(225.0, 210.0, 205.0) * ATMOSPHERE_SUN_INTENSITY;

// Rayleigh: two authored tints blended to the hue used by the reference tuning,
// then normalised to the blue channel of the classic 0.03624 baseline.
const vec3 RAYLEIGH_SCATTERING_BASE =
    mix(vec3(46.0, 95.0, 233.0), vec3(46.0, 89.0, 207.0), 0.5) / 255.0 * 0.03624;

const vec3 OZONE_ABSORPTION_BASE = UNIT_TINT(190.0, 170.0, 0.0) * 0.0019;

const vec3 AEROSOL_ABSORPTION_BASE = vec3(1.0) * 0.0003;
const vec3 AEROSOL_SCATTERING_BASE = UNIT_TINT(160.0, 195.0, 255.0) * 0.03;

// Water-like ground, matching the blue haze colour of the reference tuning.
const vec3 GROUND_ALBEDO = UNIT_TINT(10.0, 40.0, 100.0);

#endif

// Scale heights, km — US Standard Atmosphere (8.5 km molecular, ~1.2 km haze).
const float MOLECULAR_HEIGHT_SCALE = 8.5;
const float AEROSOL_HEIGHT_SCALE   = 1.2;
const float AEROSOL_TURBIDITY      = 1.0;
const float AEROSOL_BASE_DENSITY   = 1.0;

// Spectral (4 band) → linear sRGB. The matrix was fitted so that a 4-band sun
// spectrum lands on the expected RGB ratios; the scale is a pure exposure match.
const mat4x3 SPECTRAL_TO_RGB = mat4x3(
    137.672389239975, -8.632904716299537, -1.7181567391931372,
    32.549094028629234, 91.29801417199785, -12.005406444382531,
    -38.91428392614275, 34.31665471469816, 29.89044807197628,
    8.572844237945445, -11.103384660054624, 117.47585277566478
);
const float SPECTRAL_TO_RGB_SCALE = 0.025;

vec3 rgbFromSpectral(vec4 L)
{
    return SPECTRAL_TO_RGB * L * SPECTRAL_TO_RGB_SCALE;
}

#endif
