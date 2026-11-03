// Transmittance: ray march, LUT generation and LUT lookup
//
// Atmosphere model split by responsibility. Dependencies are one-way:
//   constants -> {geometry, phase, medium} -> transmittance -> scattering
// `scene` and `skyview` only depend on constants.
//
// Units: distances km, coefficients 1/km, radiance scene-linear unitless.
// See constants.glsl for the provenance of every physical number.

#ifndef ATMOSPHERE_TRANSMITTANCE
#define ATMOSPHERE_TRANSMITTANCE

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"
#include "/lib/atmosphere/geometry.glsl"
#include "/lib/atmosphere/medium.glsl"

vec34 transmittanceFromLUT(sampler2D transmitLUT, float r, float mu)
{
    if (rayIntersectsGround(r, mu))
    {
        return vec34(0.0);
    }

    // Bruneton's (r, mu) → (distance, radius) reparameterisation.
    float H = sqrt(ATMOSPHERE_RADIUS * ATMOSPHERE_RADIUS - PLANET_RADIUS * PLANET_RADIUS);
    float rho = sqrt(max(0.0, r * r - PLANET_RADIUS * PLANET_RADIUS));
    float d = distanceToTopAtmosphereBoundary(r, mu);
    float dMin = ATMOSPHERE_RADIUS - r;
    float dMax = rho + H;
    float xm = (d - dMin) / max(dMax - dMin, 1e-6);
    float xr = 1.0 - rho / H;
    vec2 uv = vec2(clamp(xm, 0.0, 1.0), clamp(xr, 0.0, 1.0));
    #ifdef ENABLE_SPECTRAL
    return texture(transmitLUT, uv);
    #else
    return texture(transmitLUT, uv).rgb;
    #endif
}

// ═══ Transmittance ══════════════════════════════════════════

vec34 computeTransmittance(vec3 origin, vec3 rayDirection)
{
    float rayLength = raySphereIntersect(origin, rayDirection, ATMOSPHERE_RADIUS);
    if (rayLength < 0.0) return vec34(1.0);

    float dt = rayLength / float(TRANSMITTANCE_STEPS);
    vec34 opticalDepth = vec34(0.0);

    for (int i = 0; i < TRANSMITTANCE_STEPS; ++i)
    {
        float t = (float(i) + 0.5) * dt;
        vec3 p = origin + rayDirection * t;
        float h = length(p) - PLANET_RADIUS;

        vec34 aerosolAbsorption, aerosolScattering;
        vec34 molecularAbsorption, molecularScattering;
        vec34 extinction;

        getAtmosphereCoefficients(h, aerosolAbsorption, aerosolScattering,
                                  molecularAbsorption, molecularScattering, extinction);

        opticalDepth += extinction * dt;
    }

    return exp(-opticalDepth);
}

vec34 computeTransmittanceLUT(vec2 uv)
{
    // Bruneton inverse: UV → (r, mu)
    float H = sqrt(ATMOSPHERE_RADIUS * ATMOSPHERE_RADIUS - PLANET_RADIUS * PLANET_RADIUS);
    float xr = 1.0 - uv.y;
    float rho = H * xr;
    float r = sqrt(rho * rho + PLANET_RADIUS * PLANET_RADIUS);

    float dMin = ATMOSPHERE_RADIUS - r;
    float dMax = rho + H;
    float xm = uv.x;
    float d = dMin + xm * (dMax - dMin);

    float mu = (d < 1e-6) ? 1.0 : (H * H - rho * rho - d * d) / (2.0 * r * d);
    mu = clamp(mu, -1.0, 1.0);

    vec3 rayDirection = vec3(sqrt(max(0.0, 1.0 - mu * mu)), mu, 0.0);
    vec3 origin = vec3(0.0, r, 0.0);

    return computeTransmittance(origin, rayDirection);
}

#endif
