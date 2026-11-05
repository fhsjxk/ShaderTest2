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
const float ATMOSPHERE_THICKNESS_KM = 70.0;
const float ATMOSPHERE_RADIUS_KM    = PLANET_RADIUS_KM + ATMOSPHERE_THICKNESS_KM;

// ── Minecraft space -> atmosphere space ─────────────────────
// Minecraft's Y axis is in blocks, the model is in km. 1 block = 0.02 km keeps
// the horizon at the height the vanilla sky has, which makes the world megascale:
// sea level is 0 km and a 100-block hill is 2 km. Everything that mixes blocks
// with the atmosphere -- altitudes and view distances alike -- must use this.
const float MC_SEA_LEVEL    = 64.0;
const float KM_PER_BLOCK    = 0.005; //这是一个大气比例缩放，而非km每方块，每方块总是是1m，将其与FOG_DISTANCE_SCALE统一成一个参数
const float MIN_ALTITUDE_KM = 0.001;

float altitudeFromEyePosition(float eyePosition)
{
    return max((eyePosition - MC_SEA_LEVEL) * KM_PER_BLOCK, MIN_ALTITUDE_KM);
}

// Camera height, shared by every consumer of the atmosphere. `eyeAltitude` is
// Iris's camera Y in blocks; nothing in the model reads it directly, everything
// goes through altitudeFromEyePosition(), so the fog, the sky and the sun disc
// cannot end up at three different heights.
uniform float eyeAltitude;

float cameraAltitudeKm()
{
    return altitudeFromEyePosition(eyeAltitude);
}

float cameraRadiusKm()
{
    return PLANET_RADIUS_KM + cameraAltitudeKm();
}

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

const float MOLECULAR_HEIGHT_SCALE_KM = 8.5;
const float AEROSOL_HEIGHT_SCALE_KM   = 1.2;

const float OZONE_PEAK_ALTITUDE_KM  = 22.35;
const float OZONE_HALF_THICKNESS_KM = 35.66 * 0.5;

#else

// Physical: computed from spectrum, but RGB pipeline introduces inaccuracies.
// Artistic: adjusted from physical to better match ground truth.

#define PHYSICAL_PARAM

#ifdef PHYSICAL_PARAM
const vec3 SUN_IRRADIANCE = vec3(1.0999, 0.9762, 0.9421) * SUN_ILLUMINANCE_LUX / NITS_PER_UNIT;

const vec3 RAYLEIGH_SCATTERING_BASE = vec3(5.8283e-03, 1.1973e-02, 2.7963e-2);

// The blue coefficient comes out of the sRGB matrix fit as -1.10e-7 m^-1, which is
// a fitting artefact (ozone cannot amplify blue). Clamped to 0 so the extinction
// stays monotone; the true blue value is ~1e-9, far below anything visible.
const vec3 OZONE_ABSORPTION_BASE = vec3(2.3043e-03, 1.4997e-03, 0.0);

const vec3 AEROSOL_SCATTERING_BASE = vec3(6.3834e-02, 7.0709e-02, 8.0580e-02);
const vec3 AEROSOL_ABSORPTION_BASE = vec3(2.6559e-03, 3.1177e-03, 3.8365e-03);

const vec3 GROUND_ALBEDO = vec3(10.0, 40.0, 100.0) / 255.0;

const vec3 RAYLEIGH_MULTISCATTER_TINT = vec3(0.2, 0.35, 1.0);

const float MOLECULAR_HEIGHT_SCALE_KM = 8.455;
const float AEROSOL_HEIGHT_SCALE_KM   = 1.2;

const float OZONE_PEAK_ALTITUDE_KM  = 22.38;
const float OZONE_HALF_THICKNESS_KM = 35.38 * 0.5;

// ── Aerosol optics from the OPAC fit ────────────────────────
// One preset, four AOD bins. The preset is the "mine" mixture at RH 50 %; the
// bins are spaced geometrically so linear interpolation between neighbours stays
// within ~3 % of a direct Monte Carlo evaluation inside the range.
//
// AOD(550 nm) = AEROSOL_DENSITY_MULT * AEROSOL_HEIGHT_STRETCH * AEROSOL_AOD_PRESET
//
// i.e. the density multiplier scales the whole column and the stretch scales the
// scale height, so the two together decide how much aerosol the ray sees.
const float AEROSOL_AOD_PRESET = 0.09079376247147974;

const float AEROSOL_AOD_BIN_0 = 0.04539688123573986;
const float AEROSOL_AOD_BIN_1 = 0.12322609416475905;
const float AEROSOL_AOD_BIN_2 = 0.33448708082500478;
const float AEROSOL_AOD_BIN_3 = 0.90793762471479722;

// Energy gain standing in for aerosol-vs-aerosol multiple scattering:
// k = total scattered / single scattered, per AOD bin. Applied once to the whole
// single-scattering integral, which is why the phase table below carries no gain
// of its own.
const vec3 AEROSOL_GAIN_BIN_0 = vec3(1.05946, 1.04929, 1.05100);
const vec3 AEROSOL_GAIN_BIN_1 = vec3(1.13592, 1.13687, 1.14091);
const vec3 AEROSOL_GAIN_BIN_2 = vec3(1.37675, 1.37091, 1.36936);
const vec3 AEROSOL_GAIN_BIN_3 = vec3(2.13430, 2.17047, 2.13308);

// Two-term Mie profile: a dense boundary layer over a thin free-troposphere
// background. The amplitudes are divided out so that rho(0) = 1, which is what
// keeps the column AOD equal to the fitted value.
const float AEROSOL_MIE_AMP_FAST   = 1.0557;
const float AEROSOL_MIE_SCALE_FAST = 1.029;
const float AEROSOL_MIE_AMP_SLOW   = 0.0154;
const float AEROSOL_MIE_SCALE_SLOW = 10.258;

float aerosolAOD550()
{
    return AEROSOL_DENSITY_MULT * AEROSOL_HEIGHT_STRETCH * AEROSOL_AOD_PRESET;
}

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

// ── Density profiles ────────────────────────────────────────
// Scale heights, km. US Standard Atmosphere: 8.5 km molecular, 1.2 km aerosol.
const float MOLECULAR_HEIGHT_SCALE_KM = 8.5;
const float AEROSOL_HEIGHT_SCALE_KM   = 1.2;

// Ozone tent, km: peak altitude and half thickness of the layer.
const float OZONE_PEAK_ALTITUDE_KM  = 22.35;
const float OZONE_HALF_THICKNESS_KM = 35.66 * 0.5;

#endif

#endif

// Broadband absorption tail below the ozone peak, fitted to a measured profile.
// Marked as tuned because the source data set was never recorded.
// Mistake
// const float OZONE_TAIL_SCALE    = 1e-3;
// const float OZONE_TAIL_DECAY    = 0.07771971;
// const float OZONE_TAIL_EXPONENT = 1.16364243;

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
