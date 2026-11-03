// Multiple scattering and the inscattering integral
//
// Depends on geometry, phase, medium and transmittance. The result is radiance
// in colour units (see lib/utility/units.glsl).

#ifndef ATMOSPHERE_SCATTERING
#define ATMOSPHERE_SCATTERING

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"
#include "/lib/atmosphere/geometry.glsl"
#include "/lib/atmosphere/phase.glsl"
#include "/lib/atmosphere/medium.glsl"
#include "/lib/atmosphere/transmittance.glsl"

// ── Multiple scattering ─────────────────────────────────────
// Cheap two-term approximation, no extra integration:
//   1. light reflected once by the ground, attenuated on both legs;
//   2. a single analytic lobe standing in for everything above first order,
//      tinted like Rayleigh-scattered light and peaking towards the sun.
// The caller scales the result by the local scattering coefficient, so what is
// returned here is an angular distribution, not radiance.

vec34 multiScattering(sampler2D transmitLUT, float cosTheta, float normalizedAlt, float r)
{
    #ifndef MULTISCATTERING
    return vec34(0.0);
    #else
    // Solid angle of the ground disc seen from the sample: the cap of
    // half-angle asin(R/r), i.e. 2*pi*(1 - cos(halfAngle)) = 2*pi*(1 - sqrt(r²-R²)/r).
    float groundSolidAngle = 2.0 * PI * (1.0 - sqrt(max(0.0, r * r - PLANET_RADIUS_KM * PLANET_RADIUS_KM)) / r);

    vec34 transToGround = transmittanceFromLUT(transmitLUT, PLANET_RADIUS_KM, cosTheta);
    vec34 transGroundToSample = transmittanceFromLUT(transmitLUT, PLANET_RADIUS_KM, 1.0)
                              / transmittanceFromLUT(transmitLUT,
                                                     PLANET_RADIUS_KM + normalizedAlt * ATMOSPHERE_THICKNESS_KM, 1.0);

    // Ground bounce: a Lambertian disc of reflectance GROUND_ALBEDO lit by the sun.
    vec34 groundRadiance = (INV_4PI * groundSolidAngle)
                         * (GROUND_ALBEDO / PI)
                         * transToGround * transGroundToSample
                         * max(0.0, cosTheta);

    // Higher orders as one lobe: 1/6 of the peak at 90 deg to the sun, rising
    // towards it. The 0.01 sets the overall share of the light that comes back.
    vec34 approxMulti = 0.01 * RAYLEIGH_MULTISCATTER_TINT / (1.0 + 5.0 * exp(-17.92 * cosTheta));

    return groundRadiance + approxMulti;
    #endif
}

// ── Inscattering ────────────────────────────────────────────

vec34 computeInscattering(sampler2D transmitLUT, vec3 sunDirection, vec3 rayDirection, float altitude)
{
    vec3 rayOrigin = vec3(0.0, PLANET_RADIUS_KM + altitude, 0.0);
    vec3 sunDirN = normalize(sunDirection);

    float cosTheta = dot(rayDirection, sunDirN);

    float atmosphereDist = raySphereIntersect(rayOrigin, rayDirection, ATMOSPHERE_RADIUS_KM);
    float groundDist = raySphereIntersect(rayOrigin, rayDirection, PLANET_RADIUS_KM);

    float rayLength = 0.0;
    bool inside = (length(rayOrigin) <= ATMOSPHERE_RADIUS_KM);

    if (inside)
    {
        rayLength = (groundDist > 0.0) ? groundDist : atmosphereDist;
    }
    else if (atmosphereDist > 0.0)
    {
        rayOrigin += rayDirection * (atmosphereDist + 1e-4);
        float secondDist = raySphereIntersect(rayOrigin, rayDirection, ATMOSPHERE_RADIUS_KM);
        rayLength = (groundDist > 0.0) ? (groundDist - atmosphereDist) : secondDist;
    }

    if (rayLength <= 0.0) return vec34(0.0);

    float dt = rayLength / float(INSCATTERING_STEPS);

    vec34 L = vec34(0.0);
    vec34 T = vec34(1.0);

    // The phase functions are evaluated for the angle between the view ray and
    // the direction back to the sun, which is -cosTheta by construction here.
    float rayleighPhaseVal = rayleighPhase(-cosTheta);
    float aerosolPhaseVal  = aerosolPhase(-cosTheta);

    for (int i = 0; i < INSCATTERING_STEPS; ++i)
    {
        float t = (float(i) + 0.5) * dt;
        vec3 p = rayOrigin + rayDirection * t;

        float r = length(p);
        float h = r - PLANET_RADIUS_KM;
        float normalizedH = h / ATMOSPHERE_THICKNESS_KM;

        float sunCosTheta = dot(p / r, sunDirN);

        vec34 aerosolAbsorption, aerosolScattering, molecularAbsorption, molecularScattering, ext;
        getAtmosphereCoefficients(h, aerosolAbsorption, aerosolScattering,
                                  molecularAbsorption, molecularScattering, ext);

        vec34 transToSun = transmittanceFromLUT(transmitLUT, r, sunCosTheta);

        vec34 singleScatter = (molecularScattering * rayleighPhaseVal
                             + aerosolScattering * aerosolPhaseVal) * transToSun;

        vec34 multiScatter = multiScattering(transmitLUT, sunCosTheta, normalizedH, r)
                           * (molecularScattering + aerosolScattering);

        // Irradiance times scattering coefficient times phase gives radiance per
        // unit length; the loop integrates over length.
        vec34 source = SUN_IRRADIANCE * (singleScatter + multiScatter);

        // Analytic integration of a constant source over the step.
        vec34 stepT = exp(-ext * dt);
        vec34 integrated = (source - source * stepT) / max(ext, vec34(EPS));

        L += T * integrated;
        T *= stepT;
    }

    return L;
}

#endif
