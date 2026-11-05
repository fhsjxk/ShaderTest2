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
//
// MULTISCATTERING_METHOD (options.glsl) picks between that and SEBH20
// (Hillaire 2020), which replaces the whole approximation with a 32x32 transfer
// LUT Psi_ms built once per frame by prepare2:
//
//     Psi_ms = L_2ndOrder / (1 - f_ms)                        (paper Eq.10)
//
// where L_2ndOrder is the sphere-averaged single-scattered luminance reaching the
// point and f_ms the fraction of light that scatters again, both obtained from one
// 64-direction integration. Multiple scattering is treated as isotropic, so Psi_ms
// carries no view dependence -- which is exactly why it fits behind the same
// interface: an angular distribution the caller multiplies by sigma_s.

#if MULTISCATTERING_METHOD == 1 && !defined(MULTISCAT_BUILD)
uniform sampler2D {{IMG_MULTISCAT_SAMPLER}};
const ivec2 MULTISCAT_SIZE = ivec2({{IMG_MULTISCAT_SIZE_X}}, {{IMG_MULTISCAT_SIZE_Y}});

// Psi_ms, divided by the solar irradiance at build time so this stays a pure
// transfer function: the caller applies SUN_IRRADIANCE to both terms alike.
vec34 sampleMultiScatteringLUT(float sunCosZenith, float altitudeKm)
{
    vec2 unit = clamp(vec2(sunCosZenith * 0.5 + 0.5, altitudeKm / ATMOSPHERE_THICKNESS_KM),
                      0.0, 1.0);
    // Map the unit interval onto the sub-texel centres; without the renormalisation
    // the bilinear footprint leaks past the first and last texel of the axis.
    vec2 uv = (unit + 0.5 / vec2(MULTISCAT_SIZE))
              * (vec2(MULTISCAT_SIZE) / (vec2(MULTISCAT_SIZE) + 1.0));
    return texture({{IMG_MULTISCAT_SAMPLER}}, uv).rgb;
}
#endif

vec34 multiScattering(sampler2D transmitLUT, float cosTheta, float normalizedAlt, float r)
{
    #if defined(MULTISCAT_BUILD)
    // Building the transfer LUT itself: only first-order scattering may
    // contribute, otherwise the pass would read the LUT it is writing.
    return vec34(0.0);
    #elif !defined(MULTISCATTERING)
    return vec34(0.0);
    #elif MULTISCATTERING_METHOD == 1
    return sampleMultiScatteringLUT(cosTheta, normalizedAlt * ATMOSPHERE_THICKNESS_KM);
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
    // vec34这个名字要改，因为目前这东西只根据ENABLE_SPECTRAL宏来决定是vec3还是vec4，没有通用性，但名字很像通用的东西，这就是一个临时遗留
    // 下面一行代码实际比较hacky的视觉拟合，需要改，但效果是需要的，后期会使用sebh的多重散射lut方案或者预计算方案
    vec34 multiScatterColor = mix(mix(RAYLEIGH_MULTISCATTER_TINT, vec34(0.7), 0.7), RAYLEIGH_MULTISCATTER_TINT, smoothstep(0.05, 0.33, cosTheta) + 0.7 * smoothstep(0.02, -0.08, cosTheta));
    vec34 approxMulti = 0.01 * multiScatterColor / (1.0 + 5.0 * exp(-17.92 * cosTheta));

    return groundRadiance + approxMulti;
    #endif
}

// ── Inscattering ────────────────────────────────────────────

// The march itself. `fmsOut` is the SEBH20 transfer integral
//     ∫ T(s) · sigma_s(s) · (1 - e^{-sigma_t ds}) / sigma_t
// i.e. the fraction of the light that scatters again along this ray; the
// multiple-scattering LUT is built from it and every other caller ignores it.
vec34 computeInscatteringCore(sampler2D transmitLUT, vec3 sunDirection, vec3 rayDirection,
                              float altitude, out vec34 fmsOut)
{
    fmsOut = vec34(0.0);

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
        // The nudge is 1e-4 km = 10 cm, not EPS: float32 spacing at planet radius
        // is ~5e-4 km, so a smaller offset would round away and leave the ray on
        // the shell.
        rayOrigin += rayDirection * (atmosphereDist + 1e-4);
        float secondDist = raySphereIntersect(rayOrigin, rayDirection, ATMOSPHERE_RADIUS_KM);
        rayLength = (groundDist > 0.0) ? (groundDist - atmosphereDist) : secondDist;
    }

    if (rayLength <= 0.0) return vec34(0.0);

    float dt = rayLength / float(INSCATTERING_STEPS);

    // Single and multiple scattering are accumulated separately under
    // PHYSICAL_PARAM: the aerosol's higher orders come from a fitted gain applied
    // once to the whole single-scattering integral, while the multiple-scattering
    // LUT only carries Rayleigh. Mixing them in one accumulator would apply the
    // gain to the Rayleigh multiple scattering as well.
    vec34 L = vec34(0.0);
    #ifdef PHYSICAL_PARAM
    vec34 multiL = vec34(0.0);
    #endif
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

        #ifdef PHYSICAL_PARAM
        // Rayleigh only: aerosol-vs-aerosol scattering is in aerosolScatteringGain().
        vec34 msScatterColor = molecularScattering;
        #else
        vec34 msScatterColor = molecularScattering + aerosolScattering;
        #endif

        vec34 multiScatter = multiScattering(transmitLUT, sunCosTheta, normalizedH, r)
                           * msScatterColor;

        // Analytic integration of a constant source over the step.
        vec34 stepT = exp(-ext * dt);

        #ifdef PHYSICAL_PARAM
        vec34 singleSource = SUN_IRRADIANCE * singleScatter;
        vec34 multiSource  = SUN_IRRADIANCE * multiScatter;
        L      += T * (singleSource - singleSource * stepT) / max(ext, vec34(EPS));
        multiL += T * (multiSource - multiSource * stepT) / max(ext, vec34(EPS));
        #else
        // Irradiance times scattering coefficient times phase gives radiance per
        // unit length; the loop integrates over length.
        vec34 source = SUN_IRRADIANCE * (singleScatter + multiScatter);
        vec34 integrated = (source - source * stepT) / max(ext, vec34(EPS));
        L += T * integrated;
        #endif

        #if MULTISCATTERING_METHOD == 1
        // Second-order transfer for the Psi_ms LUT: the share of the light that is
        // scattered again along this ray, with the same analytic step integral.
        vec34 msScatter = molecularScattering + aerosolScattering;
        fmsOut += T * (msScatter - msScatter * stepT) / max(ext, vec34(EPS));
        #endif
        T *= stepT;
    }

    #ifdef PHYSICAL_PARAM
    // The fitted gain covers every scattering order above the first, for the
    // aerosol only. It is deliberately not applied while building the transfer
    // LUT: that LUT is Rayleigh-only and the gain belongs to the aerosol.
    #ifndef MULTISCAT_BUILD
    L *= aerosolScatteringGain();
    #endif
    return L + multiL;
    #else
    return L;
    #endif
}

// Callers that only want the radiance; the transfer integral is for the LUT build.
vec34 computeInscattering(sampler2D transmitLUT, vec3 sunDirection, vec3 rayDirection,
                          float altitude)
{
    vec34 fmsUnused;
    return computeInscatteringCore(transmitLUT, sunDirection, rayDirection, altitude, fmsUnused);
}

#endif
