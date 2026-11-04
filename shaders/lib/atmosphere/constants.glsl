// Atmosphere constants
//
// Dependencies are one-way: constants -> {geometry, phase, medium}
// -> transmittance -> scattering; `scene` and `skyview` only use constants.
//
// Units
//   distances      km
//   coefficients   1/km  (m^-1 values from the literature are multiplied by 1000)
//   radiance       NITS_PER_UNIT (see lib/utility/units.glsl)
//   irradiance     same unit, see the note in units.glsl
//
// Sources
//   Scattering and absorption coefficients, scale heights and the ozone profile
//   are the standard atmosphere set used by Bruneton's precomputed atmospheric
//   scattering (https://ebruneton.github.io/precomputed_atmospheric_scattering/).
//   They are given as m^-1 in that reference and converted here.


// 气溶胶常量最终为基准值，最终实际值会随天气变化，暂时不用动，这些值也需要暴露给用户调整
// 目前各种宏的命名比较乱，比如“ENABLE_SPECTRAL”和“PHYSICAL_PARAM”（不仅这个例子）命名规则不统一，需要调整这些，需要可以从命名看出属于哪个部分

#ifndef ATMOSPHERE_CONSTANTS
#define ATMOSPHERE_CONSTANTS

#include "/lib/prelude.glsl"

const int TRANSMITTANCE_STEPS = 32;
const int INSCATTERING_STEPS  = 32;

// ── Planet and shell ────────────────────────────────────────
const float PLANET_RADIUS_KM        = 6371.0;
const float ATMOSPHERE_THICKNESS_KM = 100.0;
const float ATMOSPHERE_RADIUS_KM    = PLANET_RADIUS_KM + ATMOSPHERE_THICKNESS_KM;

#ifdef ENABLE_SPECTRAL
#define vec34 vec4
#else
#define vec34 vec3
#endif

// ── Solar irradiance ────────────────────────────────────────
// Extraterrestrial solar illuminance, lux. The radiometric equivalent is the
// 1361 W/m^2 solar constant; the luminous figure is the same spectrum weighted
// by the photopic curve, which is what matters for a luminance pipeline.
const float SUN_ILLUMINANCE_LUX = 130000.0;

#ifdef ENABLE_SPECTRAL

// NOTE: the 4-band path is not calibrated to physical units yet; its constants
// are the legacy relative values. Only the RGB path (below) is physical.
const vec4 SUN_IRRADIANCE = vec4(1.68, 1.83, 1.99, 1.31);

const vec4 RAYLEIGH_SCATTERING_BASE = vec4(6.605e-3, 1.067e-2, 1.842e-2, 3.156e-2);
const vec4 OZONE_ABSORPTION_BASE    = vec4(3.472e-3, 3.914e-3, 1.349e-3, 11.03e-5) * 0.5;
const vec4 AEROSOL_ABSORPTION_BASE  = vec4(1.0) * 0.0003;
const vec4 AEROSOL_SCATTERING_BASE  = vec4(1.5908, 1.7711, 2.0942, 2.4033) * 0.6 * 0.035;

const vec4 GROUND_ALBEDO = vec4(0.57, 0.45, 0.37, 0.8) * 0.1;

// Spectral tint of the Rayleigh contribution to higher-order scattering,
// normalised to the fourth band.
const vec4 RAYLEIGH_MULTISCATTER_TINT = vec4(0.217, 0.347, 0.594, 1.0);

#else

// Physical: computed from spectrum, but RGB pipeline introduces inaccuracies.
// Artistic: adjusted from physical to better match ground truth.

#ifdef PHYSICAL_PARAM
const vec3 SUN_IRRADIANCE = vec3(1.0999, 0.9762, 0.9421) * SUN_ILLUMINANCE_LUX / NITS_PER_UNIT;

const vec3 RAYLEIGH_SCATTERING_BASE =
    mix(vec3(46.0, 95.0, 233.0), vec3(46.0, 89.0, 207.0), 0.5) / 255.0 * 0.03624;

const vec3 OZONE_ABSORPTION_BASE = vec3(190.0, 170.0, 0.0) / 255.0 * 0.0019;

const vec3 AEROSOL_SCATTERING_BASE = vec3(160.0, 195.0, 255.0) / 255.0 * 0.03;
const vec3 AEROSOL_ABSORPTION_BASE = vec3(1.0) * 0.0003;

const vec3 GROUND_ALBEDO = vec3(10.0, 40.0, 100.0) / 255.0;

const vec3 RAYLEIGH_MULTISCATTER_TINT = vec3(0.2, 0.35, 1.0);

#else
// Solar irradiance in colour units (lux / NITS_PER_UNIT).
const vec3 SUN_IRRADIANCE = vec3(1.0999, 0.9762, 0.9421) * SUN_ILLUMINANCE_LUX / NITS_PER_UNIT;

// ── Tuned coefficient set (RGB rendering) ───────────────────
// These are the authored values this pack has always rendered with; they are
// tuned for the RGB path and are NOT the literature values. Each one is a tint
// (0-255, used without gamma decoding) times a physically-scaled magnitude, so
// the hue is deliberate and the magnitude is roughly right.
// Replacing them with a purely physical set shifts the sky hue noticeably, which
// is why they are kept for the time being (see DESIGN_GOALS.md §6.4).

// Rayleigh: two authored tints blended, normalised to the classic 0.03624.
const vec3 RAYLEIGH_SCATTERING_BASE =
    mix(vec3(46.0, 95.0, 233.0), vec3(46.0, 89.0, 207.0), 0.5) / 255.0 * 0.03624;

// Ozone: warm tint, magnitude ~1.9e-3 /km.
const vec3 OZONE_ABSORPTION_BASE = vec3(152.0, 152.0, 0.0) / 255.0 * 0.0019;

// Aerosol: faintly blue tint, magnitude 0.03 /km.
const vec3 AEROSOL_SCATTERING_BASE = vec3(153.0, 202.0, 255.0) / 255.0 * 0.035;
const vec3 AEROSOL_ABSORPTION_BASE = vec3(1.0) * 0.0005;

// Ground reflectance of the sea surface this pack assumes (blue, ~0.4 in blue).
const vec3 GROUND_ALBEDO = vec3(10.0, 40.0, 100.0) / 255.0;

// Tint of the Rayleigh contribution to higher-order scattering, used by
// multiScattering() where the light has lost its original direction.
const vec3 RAYLEIGH_MULTISCATTER_TINT = vec3(0.2, 0.35, 1.0);

#endif

#endif

// ── Density profiles ────────────────────────────────────────
// Scale heights, km. US Standard Atmosphere: 8.5 km molecular, 1.2 km aerosol.
const float MOLECULAR_HEIGHT_SCALE_KM = 8.5;
const float AEROSOL_HEIGHT_SCALE_KM   = 1.2;

// Ozone tent, km: peak altitude and half thickness of the layer.
const float OZONE_PEAK_ALTITUDE_KM  = 22.35;
const float OZONE_HALF_THICKNESS_KM = 35.66 * 0.5;

// Broadband absorption tail below the ozone peak, fitted to a measured profile.
// Marked as tuned because the source data set was never recorded.
const float OZONE_TAIL_SCALE    = 1e-3;
const float OZONE_TAIL_DECAY    = 0.07771971;
const float OZONE_TAIL_EXPONENT = 1.16364243;

// ── Spectral (4 band) -> linear sRGB ────────────────────────
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
