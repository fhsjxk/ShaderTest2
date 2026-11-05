// Density profiles and extinction coefficients
//
// Depends only on constants. Distances km, coefficients 1/km.

#ifndef ATMOSPHERE_MEDIUM
#define ATMOSPHERE_MEDIUM

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"

// Normalised aerosol density at altitude `h` km. The reference set (PHYSICAL_PARAM)
// uses the two-term OPAC fit; the tuned set keeps the single exponential.
#ifdef PHYSICAL_PARAM
float aerosolDensityProfile(float h)
{
    return (AEROSOL_MIE_AMP_FAST * exp(-h / AEROSOL_MIE_SCALE_FAST)
          + AEROSOL_MIE_AMP_SLOW * exp(-h / AEROSOL_MIE_SCALE_SLOW))
         / (AEROSOL_MIE_AMP_FAST + AEROSOL_MIE_AMP_SLOW) * 0.3;
}
#else
float aerosolDensityProfile(float h)
{
    return exp(-h / AEROSOL_HEIGHT_SCALE_KM);
}
#endif

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

    // AEROSOL_DENSITY_MULT scales the column, AEROSOL_HEIGHT_STRETCH stretches the
    // profile (rho(z/s)), so together they give AOD = mult * stretch * preset.
    float aerosolDensity   = AEROSOL_DENSITY_MULT
                           * aerosolDensityProfile(h / AEROSOL_HEIGHT_STRETCH);
    float molecularDensity = exp(-h / MOLECULAR_HEIGHT_SCALE_KM);

    aerosolAbsorption   = AEROSOL_ABSORPTION_BASE * aerosolDensity;
    aerosolScattering   = AEROSOL_SCATTERING_BASE * aerosolDensity;
    molecularScattering = RAYLEIGH_SCATTERING_BASE * molecularDensity;

    // Ozone: a tent around the peak altitude.
    float ozoneDensity = max(1.0 - abs(h - OZONE_PEAK_ALTITUDE_KM) / OZONE_HALF_THICKNESS_KM, 0.0);
    molecularAbsorption = OZONE_ABSORPTION_BASE * ozoneDensity;

    // Extinction keeps the full aerosol contribution even while building the
    // multiple-scattering transfer LUT: that LUT only drops aerosol *scattering*
    // (it is Rayleigh-only), but the aerosol still attenuates the light it passes
    // through.
    extinction = aerosolAbsorption + aerosolScattering + molecularAbsorption + molecularScattering;

    #ifdef MULTISCAT_BUILD
    // Rayleigh-only transfer function. Aerosol multiple scattering is accounted
    // for separately by the fitted gain factor, so including it here would count
    // it twice.
    aerosolScattering = vec34(0.0);
    #endif
}

#endif
