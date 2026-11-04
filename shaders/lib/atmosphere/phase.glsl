// Scattering phase functions
//
// All three are normalised to integrate to 1 over the sphere, so a phase value
// times an irradiance gives a radiance without any extra gain factor.

#ifndef ATMOSPHERE_PHASE
#define ATMOSPHERE_PHASE

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"

// Henyey-Greenstein. g > 0 scatters forward, g = 0 is isotropic.
float hgPhase(float cosTheta, float g)
{
    float g2 = g * g;
    float denom = 1.0 + g2 + 2.0 * g * cosTheta;
    return INV_4PI * (1.0 - g2) / (denom * sqrt(denom));
}

// Aerosol phase: four HG lobes mixed into a wide forward peak plus a soft back
// lobe. Measured aerosol phase functions need several lobes to fit both ends of
// the curve, and this hand-tuned mix is what the RGB look was calibrated with.
//
// AEROSOL_PHASE_GAIN is a look-tuning multiplier, not a physical quantity: the！！这玩意临时补偿多重散射用的，看到这里那么修正注释
// nested mix keeps the weights normalised, so the gain lifts the horizon glow
// without changing the shape. It exists only because the RGB tuning depends on it.
const float AEROSOL_PHASE_GAIN = 1.3;

float aerosolPhase(float cosTheta)
{
    return mix(hgPhase(cosTheta, 0.62),
               mix(hgPhase(cosTheta, 0.82),
                   mix(hgPhase(cosTheta, 0.93),
                       hgPhase(cosTheta, 0.97), 0.2), 0.4), 0.35)
           * AEROSOL_PHASE_GAIN;
}

// Rayleigh phase for unpolarised light. The (1 + cos^2) term is the analytic
// form; the depolarisation correction is ~3% and is omitted.
float rayleighPhase(float cosTheta)
{
    return (3.0 / (16.0 * PI)) * (1.0 + cosTheta * cosTheta);
}

#endif
