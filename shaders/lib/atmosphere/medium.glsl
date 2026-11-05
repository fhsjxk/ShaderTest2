// Density profiles and extinction coefficients
//
// Depends only on constants. Distances km, coefficients 1/km.

#ifndef ATMOSPHERE_MEDIUM
#define ATMOSPHERE_MEDIUM

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"

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

    // Exponential density profiles around the two scale heights.
    float aerosolDensity   = exp(-h / AEROSOL_HEIGHT_SCALE_KM);

    aerosolDensity = 1.0670 * exp(-h / 1.039) + 0.0103 * exp(-h / 11.426);

    aerosolDensity *= 0.5;

    float molecularDensity = exp(-h / MOLECULAR_HEIGHT_SCALE_KM);

    aerosolAbsorption   = AEROSOL_ABSORPTION_BASE * aerosolDensity;
    aerosolScattering   = AEROSOL_SCATTERING_BASE * aerosolDensity;
    molecularScattering = RAYLEIGH_SCATTERING_BASE * molecularDensity;

    // Ozone: a tent around the peak altitude, plus the broadband absorption tail.
    float ozoneDensity = max(1.0 - abs(h - OZONE_PEAK_ALTITUDE_KM) / OZONE_HALF_THICKNESS_KM, 0.0);
    molecularAbsorption = OZONE_ABSORPTION_BASE * ozoneDensity;
    //molecularAbsorption += OZONE_TAIL_SCALE * exp(-OZONE_TAIL_DECAY * pow(h + 1.0, OZONE_TAIL_EXPONENT));

    extinction = aerosolAbsorption + aerosolScattering + molecularAbsorption + molecularScattering;
}

#endif
