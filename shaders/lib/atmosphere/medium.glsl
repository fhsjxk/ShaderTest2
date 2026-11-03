// Density profiles and extinction coefficients
//
// Atmosphere model split by responsibility. Dependencies are one-way:
//   constants -> {geometry, phase, medium} -> transmittance -> scattering
// `scene` and `skyview` only depend on constants.
//
// Units: distances km, coefficients 1/km, radiance scene-linear unitless.
// See constants.glsl for the provenance of every physical number.

#ifndef ATMOSPHERE_MEDIUM
#define ATMOSPHERE_MEDIUM

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"

// ═══ Atmospheric coefficients ═══════════════════════════════

// Ozone tent profile, km.
const float OZONE_PEAK_ALTITUDE_KM  = 22.35;
const float OZONE_HALF_THICKNESS_KM = 35.66 * 0.5;

// Broadband absorption tail below the ozone peak. The three numbers come from a
// least-squares fit to a measured profile; the original data set was never
// recorded, so treat them as tuned rather than derived.
const float OZONE_TAIL_SCALE    = 1e-3;
const float OZONE_TAIL_DECAY    = 0.07771971;
const float OZONE_TAIL_EXPONENT = 1.16364243;

void getAtmosphereCoefficients(
    float h,
    out vec34 aerosolAbsorption,
    out vec34 aerosolScattering,
    out vec34 molecularAbsorption,
    out vec34 molecularScattering,
    out vec34 extinction
)
{
    h = max(h, 0.0);

    float aerosolDensity = AEROSOL_BASE_DENSITY * exp(-h / AEROSOL_HEIGHT_SCALE);

    aerosolAbsorption = AEROSOL_ABSORPTION_BASE * aerosolDensity * AEROSOL_TURBIDITY;
    aerosolScattering = AEROSOL_SCATTERING_BASE * aerosolDensity * AEROSOL_TURBIDITY;

    molecularScattering = RAYLEIGH_SCATTERING_BASE * exp(-h / MOLECULAR_HEIGHT_SCALE);

    float ozoneDensity = max(1.0 - abs(h - OZONE_PEAK_ALTITUDE_KM) / OZONE_HALF_THICKNESS_KM, 0.0);
    molecularAbsorption = OZONE_ABSORPTION_BASE * ozoneDensity;
    molecularAbsorption += OZONE_TAIL_SCALE * exp(-OZONE_TAIL_DECAY * pow(h + 1.0, OZONE_TAIL_EXPONENT));

    extinction = aerosolAbsorption + aerosolScattering + molecularAbsorption + molecularScattering;
}

#endif
