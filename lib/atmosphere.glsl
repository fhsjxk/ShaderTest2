/*
 * From https://www.shadertoy.com/view/msXXDS
 *
 * NOTE: sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}} is needed as a parameter
 * for functions that sample the LUT. sunDirection is a parameter for
 * computeInscattering. Both must be declared as uniform at the call site.
 */

#include "/lib/common.glsl"

const int TRANSMITTANCE_STEPS    = 32;
const int INSCATTERING_STEPS     = 32;

const float PLANET_RADIUS               = 6371.0;
const float ATMOSPHERE_THICKNESS        = 100.0;
const float ATMOSPHERE_RADIUS           = PLANET_RADIUS + ATMOSPHERE_THICKNESS;

const vec4 SUN_RADIANCE                 = vec4(1.68, 1.83, 1.99, 1.31);

const vec4 RAYLEIGH_SCATTERING_BASE     = vec4(6.605e-3, 1.067e-2, 1.842e-2, 3.156e-2);

const vec4 OZONE_ABSORPTION_BASE        = vec4(3.472e-21, 3.914e-21, 1.349e-21, 11.03e-23) * 1e-4f;

const vec4 AEROSOL_ABSORPTION_BASE      = vec4(1.0e-22);
const vec4 AEROSOL_SCATTERING_BASE      = vec4(1.5e-22);

const float AEROSOL_HEIGHT_SCALE = 1.2;
const float AEROSOL_TURBIDITY    = 1.0;
const float AEROSOL_BASE_DENSITY = 1.37e20;

const vec4 GROUND_ALBEDO         = vec4(0.3);

vec4 transmittanceFromLUT(sampler2D transmitLUT, float cosTheta, float normalizedAlt)
{
    vec2 uv = vec2(clamp(cosTheta * 0.5 + 0.5, 0.0, 1.0),
                   clamp(normalizedAlt,      0.0, 1.0));
    return texture(transmitLUT, uv).rgba;
}

float raySphereIntersect(vec3 origin, vec3 dir, float radius)
{
    float b = dot(origin, dir);
    float c = dot(origin, origin) - radius * radius;
    float disc = b * b - c;
    if (disc < 0.0) return -1.0;
    float sqrtDisc = sqrt(disc);
    float t0 = -b - sqrtDisc;
    float t1 = -b + sqrtDisc;
    return (t0 >= 0.0) ? t0 : ((t1 >= 0.0) ? t1 : -1.0);
}

float hgPhase(float cosTheta, float g)
{
    float g2 = g * g;
    float denom = 1.0 + g2 + 2.0 * g * cosTheta;
    return INV_4PI * (1.0 - g2) / (denom * sqrt(denom));
}

float aerosolPhase(float cosTheta)
{
    return mix(hgPhase(cosTheta, 0.6), hgPhase(cosTheta, 0.95), 0.1);
}

float rayleighPhase(float cosTheta)
{
    return (3.0 / (16.0 * PI)) * (1.0 + cosTheta * cosTheta);
}

void getAtmosphereCoefficients(float h,
                              out vec4 aerosolAbsorption,
                              out vec4 aerosolScattering,
                              out vec4 molecularAbsorption,
                              out vec4 molecularScattering,
                              out vec4 extinction)
{
    h = max(h, 0.0);

    float aerosolDensity = AEROSOL_BASE_DENSITY * exp(-h / AEROSOL_HEIGHT_SCALE);

    aerosolAbsorption  = AEROSOL_ABSORPTION_BASE  * aerosolDensity * AEROSOL_TURBIDITY;
    aerosolScattering  = AEROSOL_SCATTERING_BASE  * aerosolDensity * AEROSOL_TURBIDITY;

    molecularScattering = RAYLEIGH_SCATTERING_BASE * exp(-0.07771971 * pow(h + 1.0, 1.16364243));

    float t = log(h + 1e-4) - 3.22261;
    float ozoneDensity = 3.78547397e20 / (h + 1e-4) * exp(-t * t * 5.55555555);
    molecularAbsorption = OZONE_ABSORPTION_BASE * 300.0 * ozoneDensity;
    molecularAbsorption += 1e-3 * exp(-0.07771971 * pow(h + 1.0, 1.16364243));

    extinction = aerosolAbsorption + aerosolScattering + molecularAbsorption + molecularScattering;
}

vec4 multiScatteringIsotropic(sampler2D transmitLUT, float cosTheta, float normalizedAlt, float r)
{
    float solidAngle = 2.0 * PI * (1.0 - sqrt(max(0.0, r*r - PLANET_RADIUS*PLANET_RADIUS)) / r);
    vec4 transToGround = transmittanceFromLUT(transmitLUT, cosTheta, 0.0);
    vec4 transGroundToSample = transmittanceFromLUT(transmitLUT, 1.0, 0.0) / transmittanceFromLUT(transmitLUT, 1.0, normalizedAlt);

    vec4 groundRadiance = (INV_4PI * solidAngle) *
                          (GROUND_ALBEDO / PI) *
                          transToGround * transGroundToSample *
                          max(0.0, cosTheta);

    vec4 approxMulti = 0.015 * vec4(0.217, 0.347, 0.594, 1.0) /
                       (1.0 + 5.0 * exp(-17.92 * cosTheta)) * 0.7;

    return groundRadiance + approxMulti;
}

vec4 multiScatteringAnisotropic(float cosTheta, float h)
{
    float phase = mix(hgPhase(cosTheta, 0.6), hgPhase(cosTheta, 0.95), 0.03);
    vec4 molecularScattering = RAYLEIGH_SCATTERING_BASE;
    return 1 * molecularScattering * phase * AEROSOL_TURBIDITY * AEROSOL_BASE_DENSITY * exp(-h / AEROSOL_HEIGHT_SCALE) * 1.5e-19;
}

vec4 computeTransmittance(vec3 origin, vec3 rayDirection)
{
    float rayLength = raySphereIntersect(origin, rayDirection, ATMOSPHERE_RADIUS);
    if (rayLength < 0.0)
    {
        return vec4(1.0);
    }

    float dt = rayLength / float(TRANSMITTANCE_STEPS);
    vec4 opticalDepth = vec4(0.0);

    for (int i = 0; i < TRANSMITTANCE_STEPS; ++i)
    {
        float t = (float(i) + 0.5) * dt;
        vec3 p = origin + rayDirection * t;
        float h = length(p) - PLANET_RADIUS;

        vec4 molecularAbsorption, molecularScattering;
        vec4 aerosolAbsorption, aerosolScattering;
        vec4 extinction;

        getAtmosphereCoefficients(h, aerosolAbsorption, aerosolScattering, molecularAbsorption, molecularScattering, extinction);

        opticalDepth += extinction * dt;
    }

    return exp(-opticalDepth);
}

vec4 computeTransmittanceLUT(vec2 uv)
{
    float cosTheta = uv.x * 2.0 - 1.0;
    vec3 rayDirection = vec3(sqrt(max(0.0, 1.0 - cosTheta * cosTheta)), 0.0, cosTheta);

    float r = mix(PLANET_RADIUS, ATMOSPHERE_RADIUS, uv.y);
    vec3 origin = vec3(0.0, 0.0, r);

    return computeTransmittance(origin, rayDirection);
}

vec4 computeInscattering(sampler2D transmitLUT, vec3 sunDirection, vec3 rayDirection, float altitude)
{
    vec3 rayOrigin = vec3(0.0, 0.0, PLANET_RADIUS + altitude);
    vec3 sunDirectionNormalized = normalize(sunDirection.xzy);

    float cosTheta = dot(rayDirection, sunDirectionNormalized);

    float atmosphereDistance = raySphereIntersect(rayOrigin, rayDirection, ATMOSPHERE_RADIUS);
    float groundDistance = raySphereIntersect(rayOrigin, rayDirection, PLANET_RADIUS);

    float rayLength = 0.0;
    bool insideAtmosphere = (length(rayOrigin) <= ATMOSPHERE_RADIUS);

    if (insideAtmosphere)
    {
        rayLength = (groundDistance > 0.0) ? groundDistance : atmosphereDistance;
    }
    else if (atmosphereDistance > 0.0)
    {
        rayOrigin += rayDirection * (atmosphereDistance + 1e-4);
        float secondAtmosphereDistance = raySphereIntersect(rayOrigin, rayDirection, ATMOSPHERE_RADIUS);
        rayLength = (groundDistance > 0.0) ? (groundDistance - atmosphereDistance) : secondAtmosphereDistance;
    }

    if (rayLength <= 0.0) return vec4(0.0);

    float dt = rayLength / float(INSCATTERING_STEPS);

    vec4 L = vec4(0.0);
    vec4 T = vec4(1.0);

    float rayleighPhaseValue = rayleighPhase(-cosTheta);
    float aerosolPhaseValue  = aerosolPhase(-cosTheta);

    for (int i = 0; i < INSCATTERING_STEPS; ++i)
    {
        float t = (float(i) + 0.5) * dt;
        vec3 p = rayOrigin + rayDirection * t;

        float r = length(p);
        float h = r - PLANET_RADIUS;
        float normalizedH = h / ATMOSPHERE_THICKNESS;

        float sunCosTheta = dot(p / r, sunDirectionNormalized);

        vec4 aerosolAbsorption, aerosolScattering, molecularAbsorption, molecularScattering, ext;
        getAtmosphereCoefficients(h, aerosolAbsorption, aerosolScattering, molecularAbsorption, molecularScattering, ext);

        vec4 transToSun = transmittanceFromLUT(transmitLUT, sunCosTheta, normalizedH);

        vec4 multiIso = multiScatteringIsotropic(transmitLUT, sunCosTheta, normalizedH, r);
        vec4 multiAni = multiScatteringAnisotropic(-cosTheta, h) * transToSun;

        vec4 singleScattering = (molecularScattering * rayleighPhaseValue + aerosolScattering * aerosolPhaseValue) * transToSun;
        vec4 multiScattering  = (multiIso + multiAni) * (molecularScattering + aerosolScattering);

        vec4 source = SUN_RADIANCE * (singleScattering + multiScattering);

        vec4 stepT = exp(-ext * dt);
        vec4 integrated = (source - source * stepT) / max(ext, vec4(1e-6));

        L += T * integrated;
        T *= stepT;
    }

    return L;
}

vec4 computeAtmosphereLUT(sampler2D transmitLUT, vec3 sunDir, vec2 uv)
{
    float cosTheta = uv.x * 2.0 - 1.0;
    vec3 rayDirection = vec3(sqrt(max(0.0, 1.0 - cosTheta * cosTheta)), 0.0, cosTheta);

    float r = mix(0.0, ATMOSPHERE_THICKNESS, uv.y);

    return computeInscattering(transmitLUT, sunDir, rayDirection, r);
}

const mat4x3 M = mat4x3(
    137.672389239975, -8.632904716299537, -1.7181567391931372,
    32.549094028629234, 91.29801417199785, -12.005406444382531,
    -38.91428392614275, 34.31665471469816, 29.89044807197628,
    8.572844237945445, -11.103384660054624, 117.47585277566478
);

vec3 rgbFromSpectral(vec4 L)
{
    return M * L * 0.04;
}