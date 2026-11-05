// ══════ TEST ONLY: reference model selection ══════
// Two self-contained brute-force reference models, used to validate the pack's own
// atmospheric model. Both are single scattering only and use no LUTs anywhere: the
// sun leg is a second, nested ray march. Everything lives in the clearly delimited
// TEST ONLY blocks at the end of this file, namespaced `bn08` / `bn17`, and touches
// nothing the production path uses.
//
//   0  production  computeInscattering()  (transmittance LUT, the shipping sky)
//   1  BN08        Bruneton & Neyret 2008  (physical set, no ozone)
//   2  BN17        Bruneton 2017           (Hillaire 2020's Earth parameters, ozone)
#define SKY_TEST_MODEL 0

// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/atmosphere/all.glsl"

uniform sampler2D depthtex0;
uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};
uniform vec3 sunDirection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;

layout({{IMG_SKY_FORMAT}}) uniform writeonly image2D {{IMG_SKY}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2({{IMG_SKY_SIZE_X}}, {{IMG_SKY_SIZE_Y}});

bool tileHasSky(ivec2 tileMin, ivec2 tileMax)
{
    for (int y = tileMin.y; y <= tileMax.y; y++)
    {
        for (int x = tileMin.x; x <= tileMax.x; x++)
        {
            float depth = texelFetch(depthtex0, ivec2(x, y), 0).r;
            if (depth >= 1.0)
            {
                return true;
            }
        }
    }

    return false;
}

// ══════ TEST ONLY: forward declarations of the reference models ══════
// The implementations live in the clearly delimited blocks at the end of this file;
// GLSL needs them visible before main().
#if SKY_TEST_MODEL == 1
vec3 bn08Inscattering(vec3 sunDirection, vec3 viewDirection, float altitude);
#elif SKY_TEST_MODEL == 2
vec3 bn17Inscattering(vec3 sunDirection, vec3 viewDirection, float altitude);
#endif

void main()
{
    ivec2 fullRes = ivec2(viewWidth, viewHeight);
    ivec2 skyRes = max(ivec2(1), (fullRes + ivec2(7)) / 8);
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(pixelCoord, skyRes)))
    {
        return;
    }

    ivec2 tileMin = pixelCoord * 8;
    ivec2 tileMax = min(tileMin + ivec2(7), fullRes - ivec2(1));

    if (!tileHasSky(tileMin, tileMax))
    {
        imageStore({{IMG_SKY}}, pixelCoord, vec4(0.0));
        return;
    }

    vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(skyRes);
    vec3 clipPos = vec3(uv * 2.0 - 1.0, 1.0);
    vec3 viewPos = (gbufferProjectionInverse * vec4(clipPos, 1.0)).xyz;
    vec3 viewRay = mat3(gbufferModelViewInverse) * viewPos;

    #if SKY_TEST_MODEL == 1
    // ══════ TEST ONLY ══════
    vec3 sky = bn08Inscattering(normalize(sunDirection), normalize(viewRay),
                                cameraAltitudeKm());
    #elif SKY_TEST_MODEL == 2
    // ══════ TEST ONLY ══════
    vec3 sky = bn17Inscattering(normalize(sunDirection), normalize(viewRay),
                                cameraAltitudeKm());
    #else
    vec34 sky = computeInscattering({{IMG_TRANSMIT_LUT_SAMPLER}}, sunDirection, normalize(viewRay), cameraAltitudeKm());
    #ifdef ENABLE_SPECTRAL
    sky.rgb = rgbFromSpectral(sky);
    #endif
    #endif
    imageStore({{IMG_SKY}}, pixelCoord, vec4(sky.rgb, 1.0));
}
#endif

// ══════════════════════════════════════════════════════════════
// ══════ TEST ONLY: Bruneton & Neyret 2008, brute force ══════
// ══════════════════════════════════════════════════════════════
//
// A reference implementation of the paper's atmospheric model (single scattering,
// no LUTs) placed here so the pack's own model can be validated against it. The
// pass calls it instead of computeInscattering() while SKY_TEST_MODEL is 1.
//
// Everything is self-contained: the constants are the paper's own, not the pack's.
// Visible differences from the production sky are therefore expected and are the
// point -- this is a different atmosphere (physical coefficients, no ozone, no
// ground albedo), not a different integrator for the same one.
//
// Deliberate simplifications against the full paper:
//   * no ground albedo (the paper's Algorithm 2 is pure single scattering too);
//   * no multiple scattering (same reason);
//   * the sun leg is one uniform-density-per-segment march, not the paper's
//     analytic ground/atmosphere transmittance helper.
#if SKY_TEST_MODEL == 1

const float BN08_GROUND_RADIUS_KM      = 6360.0;   // Rg
const float BN08_ATMOSPHERE_RADIUS_KM  = 6420.0;   // Rt
const float BN08_RAYLEIGH_SCALE_KM     = 8.0;      // HR
const float BN08_MIE_SCALE_KM          = 1.2;      // HM
// m^-1 in the paper; here per km.
const vec3  BN08_RAYLEIGH_BETA         = vec3(5.8e-3, 13.5e-3, 33.1e-3);
const vec3  BN08_MIE_EXTINCTION_BETA   = vec3(21e-3);
const vec3  BN08_MIE_SCATTERING_BETA   = BN08_MIE_EXTINCTION_BETA * 0.9;
const float BN08_MIE_G                 = 0.76;

// Step counts. The sun leg is nested inside the view leg, so the cost is the
// product: 64 * 32 = 2048 coefficient evaluations per sky texel.
const int BN08_VIEW_STEPS = 64;
const int BN08_SUN_STEPS  = 32;

// Cornette-Shanks, the Mie phase the paper's reference uses. `mu` is the cosine
// between the incident and the scattered propagation directions, so +1 is the sun
// seen head-on and the lobe peaks there.
float bn08MiePhase(float mu)
{
    float g  = BN08_MIE_G;
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * mu;
    return (3.0 / (8.0 * PI)) * ((1.0 - g2) * (1.0 + mu * mu))
           / ((2.0 + g2) * denom * sqrt(denom));
}

// Optical depth from `p` towards `dir` up to the top of the atmosphere. Returns
// zero transmittance when the planet blocks the sun.
vec3 bn08Transmittance(vec3 p, vec3 dir)
{
    // Closest approach of the ray to the planet centre decides occlusion.
    float b    = dot(p, dir);
    float c    = dot(p, p) - BN08_GROUND_RADIUS_KM * BN08_GROUND_RADIUS_KM;
    float disc = b * b - c;
    if (disc >= 0.0 && b < 0.0)
    {
        return vec3(0.0);
    }

    float rt   = BN08_ATMOSPHERE_RADIUS_KM;
    float tMax = -b + sqrt(max(0.0, b * b - (dot(p, p) - rt * rt)));
    if (tMax <= 0.0)
    {
        return vec3(1.0);
    }

    float dt = tMax / float(BN08_SUN_STEPS);
    vec3 tau = vec3(0.0);
    for (int i = 0; i < BN08_SUN_STEPS; ++i)
    {
        vec3 q = p + dir * ((float(i) + 0.5) * dt);
        float h = max(length(q) - BN08_GROUND_RADIUS_KM, 0.0);
        tau += (BN08_RAYLEIGH_BETA * exp(-h / BN08_RAYLEIGH_SCALE_KM)
                + BN08_MIE_EXTINCTION_BETA * exp(-h / BN08_MIE_SCALE_KM)) * dt;
    }

    return exp(-tau);
}

// Single-scattering radiance along a view ray, in the pack's colour units.
vec3 bn08Inscattering(vec3 sunDirection, vec3 viewDirection, float altitude)
{
    vec3 origin = vec3(0.0, BN08_GROUND_RADIUS_KM + altitude, 0.0);

    // Where the view ray leaves the medium: the ground if it hits first.
    float tGround = raySphereIntersect(origin, viewDirection, BN08_GROUND_RADIUS_KM);
    float tTop    = raySphereIntersect(origin, viewDirection, BN08_ATMOSPHERE_RADIUS_KM);
    float tMax    = (tGround > 0.0) ? tGround : tTop;
    if (tMax <= 0.0)
    {
        return vec3(0.0);
    }

    // Scattering cosine: the incident light travels along -sunDirection and leaves
    // towards the viewer along -viewDirection, so the cosine between those two is
    // dot(sunDirection, viewDirection) -- +1 when looking straight at the sun,
    // which is where the Mie lobe peaks.
    float mu = dot(sunDirection, viewDirection);
    float rayleighPhaseVal = (3.0 / (16.0 * PI)) * (1.0 + mu * mu);
    float miePhaseVal      = bn08MiePhase(mu);

    float dt   = tMax / float(BN08_VIEW_STEPS);
    vec3  L    = vec3(0.0);
    vec3  viewT = vec3(1.0);

    for (int i = 0; i < BN08_VIEW_STEPS; ++i)
    {
        vec3  p = origin + viewDirection * ((float(i) + 0.5) * dt);
        float h = max(length(p) - BN08_GROUND_RADIUS_KM, 0.0);

        vec3 densityR = BN08_RAYLEIGH_BETA * exp(-h / BN08_RAYLEIGH_SCALE_KM);
        vec3 densityM = BN08_MIE_SCATTERING_BETA * exp(-h / BN08_MIE_SCALE_KM);
        vec3 sigmaExt = densityR + BN08_MIE_EXTINCTION_BETA * exp(-h / BN08_MIE_SCALE_KM);

        vec3 sunT = bn08Transmittance(p, sunDirection);

        L += viewT * sunT * (densityR * rayleighPhaseVal + densityM * miePhaseVal) * dt;
        viewT *= exp(-sigmaExt * dt);
    }

    // Light source: the pack's solar irradiance keeps the brightness in the same
    // units as the production sky, so the two can be compared directly. The paper
    // uses E = 1 here; drop the factor to get its absolute radiance instead.
    // `.rgb` keeps this valid for both the RGB (vec3) and spectral (vec4) builds.
    return SUN_IRRADIANCE.rgb * L;
}

#endif
// ══════ END TEST ONLY: BN08 ══════

// ══════════════════════════════════════════════════════════════
// ══════ TEST ONLY: Bruneton 2017, brute force ══════
// ══════════════════════════════════════════════════════════════
//
// Second reference model, same shape as the BN08 one above: single scattering, no
// LUTs, the sun leg marched in a nested loop. What differs from BN08 is the
// atmosphere itself -- the Earth parameter set Bruneton published in 2017 (the one
// Hillaire's 2020 paper tabulates and the pack's constants.glsl cites), which adds
// an ozone layer and drops the Mie coefficients by a factor of five.
//
//   beta_R  (5.802, 13.558, 33.1)e-3 /km, H_R 8 km
//   beta_Ms 3.996e-3 /km, beta_Me 4.4e-3 /km, H_M 1.2 km, g 0.8
//   beta_O3 (0.650, 1.881, 0.085)e-3 /km, tent centred at 25 km, half-width 15 km
//
// As with BN08: no ground albedo (pure single scattering) and no multiple
// scattering, so the two references differ only in their atmosphere.
#if SKY_TEST_MODEL == 2

const float BN17_GROUND_RADIUS_KM     = 6360.0;   // Rg
const float BN17_ATMOSPHERE_RADIUS_KM = 6420.0;   // Rt
const float BN17_RAYLEIGH_SCALE_KM    = 8.0;      // H_R
const float BN17_MIE_SCALE_KM         = 1.2;      // H_M
const float BN17_OZONE_CENTER_KM      = 25.0;
const float BN17_OZONE_HALF_WIDTH_KM  = 15.0;

// m^-1 in the literature; here per km.
const vec3  BN17_RAYLEIGH_BETA         = vec3(5.802e-3, 13.558e-3, 33.1e-3);
const vec3  BN17_MIE_SCATTERING_BETA   = vec3(3.996e-3);
const vec3  BN17_MIE_EXTINCTION_BETA   = vec3(4.4e-3);
const vec3  BN17_OZONE_EXTINCTION_BETA = vec3(0.650e-3, 1.881e-3, 0.085e-3);
const float BN17_MIE_G                 = 0.8;

const int BN17_VIEW_STEPS = 64;
const int BN17_SUN_STEPS  = 32;

// Extinction per km at altitude h, all three layers at once. Ozone absorbs but
// does not scatter, so it appears here and nowhere in the scattering term.
vec3 bn17Extinction(float h)
{
    float ozoneDensity = max(0.0, 1.0 - abs(h - BN17_OZONE_CENTER_KM) / BN17_OZONE_HALF_WIDTH_KM);
    return BN17_RAYLEIGH_BETA * exp(-h / BN17_RAYLEIGH_SCALE_KM)
         + BN17_MIE_EXTINCTION_BETA * exp(-h / BN17_MIE_SCALE_KM)
         + BN17_OZONE_EXTINCTION_BETA * ozoneDensity;
}

// Cornette-Shanks. `mu` is the cosine between the incident and the scattered
// propagation directions, so +1 is the sun seen head-on.
float bn17MiePhase(float mu)
{
    float g  = BN17_MIE_G;
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * mu;
    return (3.0 / (8.0 * PI)) * ((1.0 - g2) * (1.0 + mu * mu))
           / ((2.0 + g2) * denom * sqrt(denom));
}

// Optical depth from `p` towards `dir` up to the top of the atmosphere; zero
// transmittance when the planet blocks the sun.
vec3 bn17Transmittance(vec3 p, vec3 dir)
{
    float b    = dot(p, dir);
    float c    = dot(p, p) - BN17_GROUND_RADIUS_KM * BN17_GROUND_RADIUS_KM;
    float disc = b * b - c;
    if (disc >= 0.0 && b < 0.0)
    {
        return vec3(0.0);
    }

    float rt   = BN17_ATMOSPHERE_RADIUS_KM;
    float tMax = -b + sqrt(max(0.0, b * b - (dot(p, p) - rt * rt)));
    if (tMax <= 0.0)
    {
        return vec3(1.0);
    }

    float dt = tMax / float(BN17_SUN_STEPS);
    vec3 tau = vec3(0.0);
    for (int i = 0; i < BN17_SUN_STEPS; ++i)
    {
        vec3 q = p + dir * ((float(i) + 0.5) * dt);
        float h = max(length(q) - BN17_GROUND_RADIUS_KM, 0.0);
        tau += bn17Extinction(h) * dt;
    }

    return exp(-tau);
}

// Single-scattering radiance along a view ray, in the pack's colour units.
vec3 bn17Inscattering(vec3 sunDirection, vec3 viewDirection, float altitude)
{
    vec3 origin = vec3(0.0, BN17_GROUND_RADIUS_KM + altitude, 0.0);

    float tGround = raySphereIntersect(origin, viewDirection, BN17_GROUND_RADIUS_KM);
    float tTop    = raySphereIntersect(origin, viewDirection, BN17_ATMOSPHERE_RADIUS_KM);
    float tMax    = (tGround > 0.0) ? tGround : tTop;
    if (tMax <= 0.0)
    {
        return vec3(0.0);
    }

    // +1 when looking straight at the sun, which is where the Mie lobe peaks.
    float mu = dot(sunDirection, viewDirection);
    float rayleighPhaseVal = (3.0 / (16.0 * PI)) * (1.0 + mu * mu);
    float miePhaseVal      = bn17MiePhase(mu);

    float dt    = tMax / float(BN17_VIEW_STEPS);
    vec3  L     = vec3(0.0);
    vec3  viewT = vec3(1.0);

    for (int i = 0; i < BN17_VIEW_STEPS; ++i)
    {
        vec3  p = origin + viewDirection * ((float(i) + 0.5) * dt);
        float h = max(length(p) - BN17_GROUND_RADIUS_KM, 0.0);

        vec3 densityR = BN17_RAYLEIGH_BETA * exp(-h / BN17_RAYLEIGH_SCALE_KM);
        vec3 densityM = BN17_MIE_SCATTERING_BETA * exp(-h / BN17_MIE_SCALE_KM);

        vec3 sunT = bn17Transmittance(p, sunDirection);

        L     += viewT * sunT * (densityR * rayleighPhaseVal + densityM * miePhaseVal) * dt;
        viewT *= exp(-bn17Extinction(h) * dt);
    }

    // Same colour-unit source as the production sky, so the two are comparable.
    return SUN_IRRADIANCE.rgb * L;
}

#endif
// ══════ END TEST ONLY: BN17 ══════