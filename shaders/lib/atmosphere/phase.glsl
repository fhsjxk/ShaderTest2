// Scattering phase functions
//
// Atmosphere model split by responsibility. Dependencies are one-way:
//   constants -> {geometry, phase, medium} -> transmittance -> scattering
// `scene` and `skyview` only depend on constants.
//
// Units: distances km, coefficients 1/km, radiance scene-linear unitless.
// See constants.glsl for the provenance of every physical number.

#ifndef ATMOSPHERE_PHASE
#define ATMOSPHERE_PHASE

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"

// ═══ Phase functions ════════════════════════════════════════

// Henyey-Greenstein, normalised over the sphere. g > 0 is forward scattering.
float hgPhase(float cosTheta, float g)
{
    float g2 = g * g;
    float denom = 1.0 + g2 + 2.0 * g * cosTheta;
    return INV_4PI * (1.0 - g2) / (denom * sqrt(denom));
}

// Haze phase: four HG lobes weighted so the result stays energy normalised
// (weights sum to 1), then gained by ATMOSPHERE_HAZE_GAIN. The multi-lobe shape
// reproduces the wide aerosol forward peak plus the soft back-scatter of the
// reference tuning; a single lobe cannot fit both ends of the curve.
const float HAZE_G0 = 0.62;
const float HAZE_G1 = 0.82;
const float HAZE_G2 = 0.93;
const float HAZE_G3 = 0.97;

const float HAZE_W0 = 0.650;
const float HAZE_W1 = 0.210;
const float HAZE_W2 = 0.112;
const float HAZE_W3 = 0.028;

float hazePhase(float cosTheta)
{
    float lobe = HAZE_W0 * hgPhase(cosTheta, HAZE_G0)
               + HAZE_W1 * hgPhase(cosTheta, HAZE_G1)
               + HAZE_W2 * hgPhase(cosTheta, HAZE_G2)
               + HAZE_W3 * hgPhase(cosTheta, HAZE_G3);
    return lobe * ATMOSPHERE_HAZE_GAIN;
}

// Rayleigh phase biased towards the anti-solar side so the horizon does not
// wash out. The first term is a hand-shaped lobe, the second the analytic
// Rayleigh phase; RAYLEIGH_ANALYTIC_MIX is the visual blend between them and is
// not an energy-conserving parameter.
const float RAYLEIGH_ANALYTIC_MIX = 0.8;

float rayleighPhase(float cosTheta)
{
    float shaped   = (1.0 / PI / 4.0) * 0.4 * -cosTheta + (1.0 / PI / 4.0) * 1.12;
    float analytic = (3.0 / (16.0 * PI)) * (1.0 + cosTheta * cosTheta);
    return mix(shaped, analytic, RAYLEIGH_ANALYTIC_MIX);
}

#endif
