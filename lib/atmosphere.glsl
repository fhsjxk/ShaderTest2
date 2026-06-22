/*
 * From https://www.shadertoy.com/view/msXXDS
 */

#include "/lib/common.glsl"
// (PI, INV_PI, INV_4PI now in common.glsl)$

uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};
//uniform sampler2D {{IMG_ATMOSPHERE_LUT_SAMPLER}};

uniform vec3 sunDirection;

const int TRANSMITTANCE_STEPS    = 32;
const int INSCATTERING_STEPS     = 32;

const float PLANET_RADIUS               = 6371.0;
const float ATMOSPHERE_THICKNESS        = 100.0;
//const float ATM_THICKNESS              = 100.0;$
const float ATMOSPHERE_RADIUS           = PLANET_RADIUS + ATMOSPHERE_THICKNESS;
//const float ATM_RADIUS                 = PLANET_RADIUS + ATM_THICKNESS;$

const vec4 SUN_RADIANCE                 = vec4(1.68, 1.83, 1.99, 1.31);

const vec4 RAYLEIGH_SCATTERING_BASE     = vec4(6.605e-3, 1.067e-2, 1.842e-2, 3.156e-2);
//const vec4 RAYLEIGH_SCAT_BASE          = vec4(6.605e-3, 1.067e-2, 1.842e-2, 3.156e-2);$

const vec4 OZONE_ABSORPTION_BASE        = vec4(3.472e-21, 3.914e-21, 1.349e-21, 11.03e-23) * 1e-4f;
//const vec4 OZONE_ABS_BASE              = vec4(3.472e-21, 3.914e-21, 1.349e-21, 11.03e-23) * 1e-4f;$

const vec4 AEROSOL_ABSORPTION_BASE      = vec4(1.0e-22);
//const vec4 AEROSOL_ABS_BASE            = vec4(1.0e-22);$
const vec4 AEROSOL_SCATTERING_BASE      = vec4(1.5e-22);
//const vec4 AEROSOL_SCAT_BASE           = vec4(1.5e-22);$

const float AEROSOL_HEIGHT_SCALE = 1.2;
const float AEROSOL_TURBIDITY    = 1.0;
const float AEROSOL_BASE_DENSITY = 1.37e20;

const vec4 GROUND_ALBEDO         = vec4(0.3);

vec4 transmittanceFromLUT(float cosTheta, float normalizedAlt)
{
    vec2 uv = vec2(clamp(cosTheta * 0.5 + 0.5, 0.0, 1.0),
                   clamp(normalizedAlt,      0.0, 1.0));
    return texture({{IMG_TRANSMIT_LUT_SAMPLER}}, uv).rgba;
}

//vec4 atmosphereFromLUT(float normalizedAlt)
//{
//    vec2 uv = vec2(0.36,
//                   clamp(normalizedAlt,      0.0, 1.0));
//    return texture({{IMG_TRANSMIT_LUT_SAMPLER}}, uv).rgba;
//}

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
    return mix(hgPhase(cosTheta, 0.55), mix(hgPhase(cosTheta, 0.8), hgPhase(cosTheta, 0.95), 0.15), 0.4);
    return mix(hgPhase(cosTheta, 0.45), mix(hgPhase(cosTheta, 0.75), hgPhase(cosTheta, 0.95), 0.15), 0.4);
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
//void getAtmCoefficients(float h, out vec4 aerosolAbs, out vec4 aerosolScat, out vec4 molecularAbs, out vec4 molecularScat, out vec4 extinction)$
{
    h = max(h, 0.0);

    float aerosolDensity = AEROSOL_BASE_DENSITY * exp(-h / AEROSOL_HEIGHT_SCALE);

    aerosolAbsorption  = AEROSOL_ABSORPTION_BASE  * aerosolDensity * AEROSOL_TURBIDITY;
    //aerosolAbs  = AEROSOL_ABS_BASE  * aerosolDensity * AEROSOL_TURBIDITY;$
    aerosolScattering = AEROSOL_SCATTERING_BASE * aerosolDensity * AEROSOL_TURBIDITY;
    //aerosolScat = AEROSOL_SCAT_BASE * aerosolDensity * AEROSOL_TURBIDITY;$

    molecularScattering = RAYLEIGH_SCATTERING_BASE * exp(-0.07771971 * pow(h + 1.0, 1.16364243));
    //molecularScat = RAYLEIGH_SCAT_BASE * exp(-0.07771971 * pow(h + 1.0, 1.16364243));$

    float t = log(h + 1e-4) - 3.22261;
    float ozoneDensity = 3.78547397e20 / (h + 1e-4) * exp(-t * t * 5.55555555);
    molecularAbsorption = OZONE_ABSORPTION_BASE * 300.0 * ozoneDensity;
    //molecularAbs = OZONE_ABS_BASE * 300.0 * ozoneDensity;$
    molecularAbsorption += 1e-3 * exp(-0.07771971 * pow(h + 1.0, 1.16364243));

    extinction = aerosolAbsorption + aerosolScattering + molecularAbsorption + molecularScattering;
    //extinction = aerosolAbs + aerosolScat + molecularAbs + molecularScat;$
}

vec4 multiScatteringIsotropic(float cosTheta, float normalizedAlt, float r)
{
    //return vec4(0);
    float solidAngle = 2.0 * PI * (1.0 - sqrt(max(0.0, r*r - PLANET_RADIUS*PLANET_RADIUS)) / r);
    vec4 transToGround = transmittanceFromLUT(cosTheta, 0.0);
    vec4 transGroundToSample = transmittanceFromLUT(1.0, 0.0) / transmittanceFromLUT(1.0, normalizedAlt);

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
    //return vec4(0);
    //float phase = mix(hgPhase(cosTheta, 0.45),mix(hgPhase(cosTheta, 0.75), hgPhase(cosTheta, 0.95), 0.02), 0.3);
    float phase = mix(hgPhase(cosTheta, 0.6), hgPhase(cosTheta, 0.95), 0.03);
    //vec4 molecularScattering = atmosphereFromLUT(h / ATMOSPHERE_THICKNESS);
    //vec4 molecularScat = atmosphereFromLUT(h / ATM_THICKNESS);$
    vec4 molecularScattering = RAYLEIGH_SCATTERING_BASE;
    //vec4 molecularScat = RAYLEIGH_SCAT_BASE;$
    return 1 * molecularScattering * phase * AEROSOL_TURBIDITY * AEROSOL_BASE_DENSITY * exp(-h / AEROSOL_HEIGHT_SCALE) * 1.5e-19;
    //return 1 * molecularScat * phase * AEROSOL_TURBIDITY * AEROSOL_BASE_DENSITY * exp(-h / AEROSOL_HEIGHT_SCALE) * 1.5e-19;$
}

vec4 computeTransmittance(vec3 origin, vec3 rayDirection)
//vec4 computeTransmittance(vec3 origin, vec3 rayDir)$
{
    float rayLength = raySphereIntersect(origin, rayDirection, ATMOSPHERE_RADIUS);
    //float rayLen = raySphereIntersect(origin, rayDir, ATM_RADIUS);$
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
        //vec4 molAbs, molScat;$
        vec4 aerosolAbsorption, aerosolScattering;
        //vec4 aerosolAbs, aerosolScat;$
        vec4 extinction;

        getAtmosphereCoefficients(h, aerosolAbsorption, aerosolScattering, molecularAbsorption, molecularScattering, extinction);
        //getAtmCoefficients(h, aerosolAbs, aerosolScat, molAbs, molScat, extinction);$

        opticalDepth += extinction * dt;
    }

    return exp(-opticalDepth);
}

vec4 computeTransmittanceLUT(vec2 uv)
{
    float cosTheta = uv.x * 2.0 - 1.0;
    vec3 rayDirection = vec3(sqrt(max(0.0, 1.0 - cosTheta * cosTheta)), 0.0, cosTheta);
    //vec3 rayDir = vec3(sqrt(max(0.0, 1.0 - cosTheta * cosTheta)),0.0,cosTheta);$

    float r = mix(PLANET_RADIUS, ATMOSPHERE_RADIUS, uv.y);
    //float r = mix(PLANET_RADIUS, ATM_RADIUS, uv.y);$
    vec3 origin = vec3(0.0, 0.0, r);

    return computeTransmittance(origin, rayDirection);
}

vec4 computeInscattering(vec3 rayDirection, float altitude)
//vec4 computeInscattering(vec3 rayDir, float altitude)$
{
    vec3 rayOrigin = vec3(0.0, 0.0, PLANET_RADIUS + altitude);
    vec3 sunDirectionLocal = normalize(sunDirection.xzy);
    //vec3 sunDir = normalize(sunDirection.xzy);$

    //sunDirectionLocal.y = 1.0 - sunDirectionLocal.y;

    float cosTheta = dot(rayDirection, sunDirectionLocal);

    float atmosphereDistance = raySphereIntersect(rayOrigin, rayDirection, ATMOSPHERE_RADIUS);
    //float atmosDist = raySphereIntersect(rayOrigin, rayDir, ATM_RADIUS);$
    float groundDistance = raySphereIntersect(rayOrigin, rayDirection, PLANET_RADIUS);
    //float groundDist = raySphereIntersect(rayOrigin, rayDir, PLANET_RADIUS);$

    float rayLength = 0.0;
    //float rayLen = 0.0;$
    bool insideAtmosphere = (length(rayOrigin) <= ATMOSPHERE_RADIUS);
    //bool insideAtm = (length(rayOrigin) <= ATM_RADIUS);$

    if (insideAtmosphere)
    {
        rayLength = (groundDistance > 0.0) ? groundDistance : atmosphereDistance;
        //rayLen = (groundDist > 0.0) ? groundDist : atmosDist;$
    }
    else if (atmosphereDistance > 0.0)
    {
        rayOrigin += rayDirection * (atmosphereDistance + 1e-4);
        float secondAtmosphereDistance = raySphereIntersect(rayOrigin, rayDirection, ATMOSPHERE_RADIUS);
        //float secondAtmos = raySphereIntersect(rayOrigin, rayDir, ATM_RADIUS);$
        rayLength = (groundDistance > 0.0) ? (groundDistance - atmosphereDistance) : secondAtmosphereDistance;
        //rayLen = (groundDist > 0.0) ? (groundDist - atmosDist) : secondAtmos;$
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
        //float normalizedH = h / ATM_THICKNESS;$

        float sunCosTheta = dot(p / r, sunDirectionLocal);
        //float sunCosTheta = dot(p / r, sunDir);$

        vec4 aerosolAbsorption, aerosolScattering, molecularAbsorption, molecularScattering, ext;
        //vec4 aerosolAbs, aerosolScat, molAbs, molScat, ext;$
        getAtmosphereCoefficients(h, aerosolAbsorption, aerosolScattering, molecularAbsorption, molecularScattering, ext);
        //getAtmCoefficients(h, aerosolAbs, aerosolScat, molAbs, molScat, ext);$

        vec4 transToSun = transmittanceFromLUT(sunCosTheta, normalizedH);

        vec4 multiIso = multiScatteringIsotropic(sunCosTheta, normalizedH, r);
        vec4 multiAni = multiScatteringAnisotropic(-cosTheta, h) * transToSun;

        vec4 singleScattering = (molecularScattering * rayleighPhaseValue + aerosolScattering * aerosolPhaseValue) * transToSun;
        //vec4 singleScat = (molScat * rayleighPhase + aerosolScat * aerosolPhase) * transToSun;$
        vec4 multiScattering  = (multiIso + multiAni) * (molecularScattering + aerosolScattering);
        //vec4 multiScat  = (multiIso + multiAni) * (molScat + aerosolScat);$

        vec4 source = SUN_RADIANCE * (singleScattering + multiScattering);

        vec4 stepT = exp(-ext * dt);
        vec4 integrated = (source - source * stepT) / max(ext, vec4(1e-6));

        L += T * integrated;
        T *= stepT;
    }

    float sun = float(cosTheta > 0.99999) * 15000.0;
    //L += T * SUN_RADIANCE * sun;

    return L;
}

vec4 computeAtmosphereLUT(vec2 uv)
{
    float cosTheta = uv.x * 2.0 - 1.0;
    vec3 rayDirection = vec3(sqrt(max(0.0, 1.0 - cosTheta * cosTheta)), 0.0, cosTheta);
    //vec3 rayDir = vec3(sqrt(max(0.0, 1.0 - cosTheta * cosTheta)),0.0,cosTheta);$

    float r = mix(0.0, ATMOSPHERE_THICKNESS, uv.y);
    //float r = mix(0.0, ATM_THICKNESS, uv.y);$

    return computeInscattering(rayDirection, r);
}

const mat4x3 M = mat4x3(
    137.672389239975, -8.632904716299537, -1.7181567391931372,
    32.549094028629234, 91.29801417199785, -12.005406444382531,
    -38.91428392614275, 34.31665471469816, 29.89044807197628,
    8.572844237945445, -11.103384660054624, 117.47585277566478
);

vec3 rgbFromSpectral(vec4 L)
//vec3 RgbFromSpectral(vec4 L)$
{
    return M * L * 0.04;
}