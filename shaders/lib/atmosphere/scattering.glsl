// Multiple scattering approximation and the inscattering integral
//
// Atmosphere model split by responsibility. Dependencies are one-way:
//   constants -> {geometry, phase, medium} -> transmittance -> scattering
// `scene` and `skyview` only depend on constants.
//
// Units: distances km, coefficients 1/km, radiance scene-linear unitless.
// See constants.glsl for the provenance of every physical number.

#ifndef ATMOSPHERE_SCATTERING
#define ATMOSPHERE_SCATTERING

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"
#include "/lib/atmosphere/geometry.glsl"
#include "/lib/atmosphere/phase.glsl"
#include "/lib/atmosphere/medium.glsl"
#include "/lib/atmosphere/transmittance.glsl"

// ═══ Multiple scattering ════════════════════════════════════

// Cheap approximation: ground bounce through the transmittance LUT plus an
// isotropic term that brightens with solar elevation.
const float MULTI_SCATTER_SCALE   = 0.01;
const float MULTI_SCATTER_ROLLOFF = 5.0;
const float MULTI_SCATTER_DECAY   = 17.92;

#ifdef ENABLE_SPECTRAL
const vec4 MULTI_SCATTER_TINT = vec4(0.217, 0.347, 0.594, 1.0);
#else
const vec3 MULTI_SCATTER_TINT = vec3(0.2, 0.35, 1.0);
#endif

vec34 multiScattering(sampler2D transmitLUT, float cosTheta, float normalizedAlt, float r)
{
    #ifndef MULTISCATTERING
    return vec34(0.0);
    #else
    float solidAngle = 2.0 * PI * (1.0 - sqrt(max(0.0, r * r - PLANET_RADIUS * PLANET_RADIUS)) / r);
    vec34 transToGround = transmittanceFromLUT(transmitLUT, PLANET_RADIUS, cosTheta);
    vec34 transGroundToSample = transmittanceFromLUT(transmitLUT, PLANET_RADIUS, 1.0)
                              / transmittanceFromLUT(transmitLUT, PLANET_RADIUS + normalizedAlt * ATMOSPHERE_THICKNESS, 1.0);

    vec34 groundRadiance = (INV_4PI * solidAngle) *
                           (GROUND_ALBEDO / PI) *
                           transToGround * transGroundToSample *
                           max(0.0, cosTheta);

    vec34 approxMulti = MULTI_SCATTER_SCALE * MULTI_SCATTER_TINT
                      / (1.0 + MULTI_SCATTER_ROLLOFF * exp(-MULTI_SCATTER_DECAY * cosTheta));

    return groundRadiance + approxMulti;
    #endif
}

// ═══ Inscattering ═══════════════════════════════════════════

vec34 computeInscattering(sampler2D transmitLUT, vec3 sunDirection, vec3 rayDirection, float altitude)
{
    vec3 rayOrigin = vec3(0.0, PLANET_RADIUS + altitude, 0.0);
    vec3 sunDirN = normalize(sunDirection);

    float cosTheta = dot(rayDirection, sunDirN);

    float atmosphereDist = raySphereIntersect(rayOrigin, rayDirection, ATMOSPHERE_RADIUS);
    float groundDist = raySphereIntersect(rayOrigin, rayDirection, PLANET_RADIUS);

    float rayLength = 0.0;
    bool inside = (length(rayOrigin) <= ATMOSPHERE_RADIUS);

    if (inside)
    {
        rayLength = (groundDist > 0.0) ? groundDist : atmosphereDist;
    }
    else if (atmosphereDist > 0.0)
    {
        rayOrigin += rayDirection * (atmosphereDist + 1e-4);
        float secondDist = raySphereIntersect(rayOrigin, rayDirection, ATMOSPHERE_RADIUS);
        rayLength = (groundDist > 0.0) ? (groundDist - atmosphereDist) : secondDist;
    }

    if (rayLength <= 0.0) return vec34(0.0);

    float dt = rayLength / float(INSCATTERING_STEPS);

    vec34 L = vec34(0.0);
    vec34 T = vec34(1.0);

    float rayleighPhaseVal = rayleighPhase(-cosTheta);
    float hazePhaseVal     = hazePhase(-cosTheta);

    for (int i = 0; i < INSCATTERING_STEPS; ++i)
    {
        float t = (float(i) + 0.5) * dt;
        vec3 p = rayOrigin + rayDirection * t;

        float r = length(p);
        float h = r - PLANET_RADIUS;
        float normalizedH = h / ATMOSPHERE_THICKNESS;

        float sunCosTheta = dot(p / r, sunDirN);

        vec34 aerosolAbsorption, aerosolScattering, molecularAbsorption, molecularScattering, ext;
        getAtmosphereCoefficients(h, aerosolAbsorption, aerosolScattering,
                                  molecularAbsorption, molecularScattering, ext);

        vec34 transToSun = transmittanceFromLUT(transmitLUT, r, sunCosTheta);

        vec34 singleScatter = (molecularScattering * rayleighPhaseVal
                             + aerosolScattering * hazePhaseVal) * transToSun;
        vec34 multiScatter  = multiScattering(transmitLUT, sunCosTheta, normalizedH, r)
                            * (molecularScattering + aerosolScattering);

        vec34 source = SUN_RADIANCE * (singleScatter + multiScatter);

        // Analytic integration of a constant source over the step.
        vec34 stepT = exp(-ext * dt);
        vec34 integrated = (source - source * stepT) / max(ext, vec34(1e-6));

        L += T * integrated;
        T *= stepT;
    }

    return L;
}

#endif
