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

#ifdef PHYSICAL_PARAM

// ── Aerosol phase from the fitted table ─────────────────────
// texture/phase_lut.dat holds four N-entry tables, one per AOD bin, packed into
// R, G, B and A of an Nx1 RGBA16F texture. A single bilinear fetch therefore
// returns all four bins at the requested angle and the blend is a dot product
// with the bin weights.
//
// Each table is normalised so that ∫p dΩ = 4π (the tables are Monte Carlo
// histograms, where that normalisation keeps the mean at 1). This pack's whole
// pipeline uses phase functions normalised to ∫p dΩ = 1, so the fetch is scaled
// by 1/4π on the way out.
uniform sampler2D phaseLutTex;
const int AEROSOL_PHASE_LUT_SIZE = 256;

// Fractional position between the two neighbouring AOD bins, as four weights.
vec4 aerosolPhaseBinWeights()
{
    float aod = aerosolAOD550();

    if (aod <= AEROSOL_AOD_BIN_1)
    {
        float w = clamp((aod - AEROSOL_AOD_BIN_0) / (AEROSOL_AOD_BIN_1 - AEROSOL_AOD_BIN_0), 0.0, 1.0);
        return vec4(1.0 - w, w, 0.0, 0.0);
    }
    if (aod <= AEROSOL_AOD_BIN_2)
    {
        float w = clamp((aod - AEROSOL_AOD_BIN_1) / (AEROSOL_AOD_BIN_2 - AEROSOL_AOD_BIN_1), 0.0, 1.0);
        return vec4(0.0, 1.0 - w, w, 0.0);
    }

    float w = clamp((aod - AEROSOL_AOD_BIN_2) / (AEROSOL_AOD_BIN_3 - AEROSOL_AOD_BIN_2), 0.0, 1.0);
    return vec4(0.0, 0.0, 1.0 - w, w);
}

// Total / single scattering for the aerosol at the current AOD, applied once to
// the finished single-scattering integral. Channels differ by <1 %, but they are
// kept per channel because it costs nothing.
vec34 aerosolScatteringGain()
{
    vec4 w = aerosolPhaseBinWeights();
    #ifdef ENABLE_SPECTRAL
    // The four-band path has no per-band gain table; the red channel's value is
    // within 1 % of the others, so a scalar keeps it usable.
    return vec4(dot(vec4(AEROSOL_GAIN_BIN_0.r, AEROSOL_GAIN_BIN_1.r,
                         AEROSOL_GAIN_BIN_2.r, AEROSOL_GAIN_BIN_3.r), w));
    #else
    return AEROSOL_GAIN_BIN_0 * w.x + AEROSOL_GAIN_BIN_1 * w.y
         + AEROSOL_GAIN_BIN_2 * w.z + AEROSOL_GAIN_BIN_3 * w.w;
    #endif
}

float aerosolPhase(float cosTheta)
{
    #ifdef MULTISCAT_BUILD
    return 0.0;
    #else
    // `cosTheta` follows this pack's convention, which is the cosine between the
    // incoming and the outgoing *propagation* directions -- the opposite sign of
    // the scattering angle that phase tables are usually indexed by. hgPhase()
    // above shows the same thing: with 1 + g^2 + 2g*cosTheta it peaks at
    // cosTheta = -1, i.e. forward scattering. The table, like the OPAC fit it came
    // from, is indexed by scattering angle with index 0 = forward, so the two are
    // mirrored here rather than in the data file.
    //
    // u = 0 at forward scattering, 1 at backward; the square root concentrates the
    // table's resolution on the forward peak, where the phase varies fastest.
    // Texel i sits at u = i / (N - 1), so the sample coordinate is
    // (u*(N-1) + 0.5)/N -- the +0.5 puts it on the texel centres the hardware
    // interpolates between.
    float u = sqrt(clamp(0.5 * (1.0 + clamp(cosTheta, -1.0, 1.0)), 0.0, 1.0));
    float coord = (u * float(AEROSOL_PHASE_LUT_SIZE - 1) + 0.5) / float(AEROSOL_PHASE_LUT_SIZE);
    float pOverFourPi = dot(texture(phaseLutTex, vec2(coord, 0.5)), aerosolPhaseBinWeights());
    return pOverFourPi * INV_4PI;
    #endif
}

#else

// Aerosol phase: four HG lobes mixed into a wide forward peak plus a soft back
// lobe. Measured aerosol phase functions need several lobes to fit both ends of
// the curve, and this hand-tuned mix is what the RGB look was calibrated with.
//
// AEROSOL_PHASE_GAIN is a look-tuning multiplier, not a physical quantity: it
// stands in for the multiple scattering that AEROSOL_PHASE_GAIN was tuned
// against. The nested mix keeps the weights normalised, so the gain lifts the
// horizon glow without changing the shape.
const float AEROSOL_PHASE_GAIN = 1.3;

float aerosolPhase(float cosTheta)
{
    return mix(hgPhase(cosTheta, 0.62),
               mix(hgPhase(cosTheta, 0.82),
                   mix(hgPhase(cosTheta, 0.93),
                       hgPhase(cosTheta, 0.97), 0.2), 0.4), 0.35)
           * AEROSOL_PHASE_GAIN;
}

#endif

// Rayleigh phase for unpolarised light. The (1 + cos^2) term is the analytic
// form; the depolarisation correction is ~3% and is omitted.
float rayleighPhase(float cosTheta)
{
    return (3.0 / (16.0 * PI)) * (1.0 + cosTheta * cosTheta);
}

#endif
