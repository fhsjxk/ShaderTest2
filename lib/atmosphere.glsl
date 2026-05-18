// NEED REFACTOR

const float PI = 3.14159265358979323846;
const float INV_PI = 0.31830988618379067154;
const float INV_4PI = 0.25 * INV_PI;

uniform sampler2D {{RT_TRANSMIT_LUT}};
uniform sampler2D {{RT_ATMOSPHERE_LUT}};

uniform vec3 sunDirection;

const int TRANSMITTANCE_STEPS   = 32;
const int INSCATTERING_STEPS    = 32;

const float PLANET_RADIUS       = 6371.0;
const float ATM_THICKNESS       = 100.0;
const float ATM_RADIUS          = PLANET_RADIUS + ATM_THICKNESS;

// 改为 RGB
const vec3 SUN_RADIANCE         = vec3(1.02148, 0.98584, 1.0752) * 10;

// RGB 瑞利散射系数（波长相关）
// 瑞利散射强度 ∝ 1/λ^4，RGB 大致比例：R:G:B ≈ 1:1.6:4.0
const vec3 RAYLEIGH_SCAT_BASE   = vec3(6.6049e-03, 1.2345e-02, 2.9413e-02) * 2;

// RGB 臭氧吸收系数
const vec3 OZONE_ABS_BASE       = vec3(2.2911e-03, 1.5404e-03, 0.0);

// RGB 气溶胶吸收/散射系数（灰度，RGB 相同）
const vec3 AEROSOL_ABS_BASE     = vec3(1.0e-22);
const vec3 AEROSOL_SCAT_BASE    = vec3(1.5e-22);

const float AEROSOL_HEIGHT_SCALE = 1.2;
const float AEROSOL_TURBIDITY    = 1.0;
const float AEROSOL_BASE_DENSITY = 1.37e20;

// RGB 地面反照率
const vec3 GROUND_ALBEDO         = vec3(0.3);

vec3 transmittanceFromLUT(float cosTheta, float normalizedAlt)
{
    vec2 uv = vec2(clamp(cosTheta * 0.5 + 0.5, 0.0, 1.0),
                   clamp(normalizedAlt,      0.0, 1.0));
    return texture({{RT_TRANSMIT_LUT}}, uv).rgb;
}

vec3 atmosphereFromLUT(float normalizedAlt)
{
    vec2 uv = vec2(0.36,
                   clamp(normalizedAlt,      0.0, 1.0));
    return texture({{RT_ATMOSPHERE_LUT}}, uv).rgb;
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

void getAtmCoefficients(float h,
                        out vec3 aerosolAbs,
                        out vec3 aerosolScat,
                        out vec3 molecularAbs,
                        out vec3 molecularScat,
                        out vec3 extinction)
{
    h = max(h, 0.0);

    float aerosolDensity = AEROSOL_BASE_DENSITY * exp(-h / AEROSOL_HEIGHT_SCALE);

    aerosolAbs  = AEROSOL_ABS_BASE  * aerosolDensity * AEROSOL_TURBIDITY;
    aerosolScat = AEROSOL_SCAT_BASE * aerosolDensity * AEROSOL_TURBIDITY;

    molecularScat = RAYLEIGH_SCAT_BASE * exp(-h / 8.696);

    float diff = h - 22.35;
    float ozoneDensity = exp(-(diff * diff) / (2.0 * 35.66 * 35.66));

    molecularAbs = OZONE_ABS_BASE * ozoneDensity;

    //molecularAbs += 1e-3 * exp(-0.07771971 * pow(h + 1.0, 1.16364243));

    extinction = aerosolAbs + aerosolScat + molecularAbs + molecularScat;
}

vec3 multiScatteringIsotropic(float cosTheta, float normalizedAlt, float r)
{
    float solidAngle = 2.0 * PI * (1.0 - sqrt(max(0.0, r*r - PLANET_RADIUS*PLANET_RADIUS)) / r);
    vec3 transToGround = transmittanceFromLUT(cosTheta, 0.0);
    vec3 transGroundToSample = transmittanceFromLUT(1.0, 0.0) / transmittanceFromLUT(1.0, normalizedAlt);

    vec3 groundRadiance = (INV_4PI * solidAngle) *
                          (GROUND_ALBEDO / PI) *
                          transToGround * transGroundToSample *
                          max(0.0, cosTheta);

    // RGB 近似多重散射，基于瑞利 + 气溶胶比例
    vec3 approxMulti = 0.015 * vec3(0.217, 0.347, 0.594) /
                       (1.0 + 5.0 * exp(-17.92 * cosTheta)) * 0.7;

    return groundRadiance + approxMulti;
}

vec3 multiScatteringAnisotropic(float cosTheta, float h)
{
    float phase = mix(hgPhase(cosTheta, 0.6), hgPhase(cosTheta, 0.95), 0.03);
    vec3 molecularScat = atmosphereFromLUT(h / ATM_THICKNESS);
    return 1.0 * molecularScat * phase * AEROSOL_TURBIDITY * AEROSOL_BASE_DENSITY * exp(-h / AEROSOL_HEIGHT_SCALE) * 1.5e-19;
}

vec3 computeTransmittance(vec3 origin, vec3 rayDir)
{
    float rayLen = raySphereIntersect(origin, rayDir, ATM_RADIUS);
    if (rayLen < 0.0)
        return vec3(1.0);

    float dt = rayLen / float(TRANSMITTANCE_STEPS);
    vec3 opticalDepth = vec3(0.0);

    for (int i = 0; i < TRANSMITTANCE_STEPS; ++i)
    {
        float t = (float(i) + 0.5) * dt;
        vec3 p = origin + rayDir * t;
        float h = length(p) - PLANET_RADIUS;

        vec3 aerosolAbs, aerosolScat, molAbs, molScat, extinction;
        getAtmCoefficients(h, aerosolAbs, aerosolScat, molAbs, molScat, extinction);

        opticalDepth += extinction * dt;
    }

    return exp(-opticalDepth);
}

vec3 computeTransmittanceLUT(vec2 uv)
{
    float cosTheta = uv.x * 2.0 - 1.0;
    vec3 rayDir = vec3(sqrt(max(0.0, 1.0 - cosTheta * cosTheta)), 0.0, cosTheta);

    float r = mix(PLANET_RADIUS, ATM_RADIUS, uv.y);
    vec3 origin = vec3(0.0, 0.0, r);

    return computeTransmittance(origin, rayDir);
}

vec3 computeInscattering(vec3 rayDir, float altitude)
{
    vec3 rayOrigin = vec3(0.0, 0.0, PLANET_RADIUS + altitude);
    vec3 sunDir    = normalize(sunDirection.xzy);

    float cosTheta = dot(rayDir, sunDir);

    float atmosDist  = raySphereIntersect(rayOrigin, rayDir, ATM_RADIUS);
    float groundDist = raySphereIntersect(rayOrigin, rayDir, PLANET_RADIUS);

    float rayLen = 0.0;
    bool insideAtm = (length(rayOrigin) <= ATM_RADIUS);

    if (insideAtm)
    {
        rayLen = (groundDist > 0.0) ? groundDist : atmosDist;
    }
    else if (atmosDist > 0.0)
    {
        rayOrigin += rayDir * (atmosDist + 1e-4);
        float secondAtmos = raySphereIntersect(rayOrigin, rayDir, ATM_RADIUS);
        rayLen = (groundDist > 0.0) ? (groundDist - atmosDist) : secondAtmos;
    }

    if (rayLen <= 0.0) return vec3(0.0);

    float dt = rayLen / float(INSCATTERING_STEPS);

    vec3 L = vec3(0.0);
    vec3 T = vec3(1.0);

    float rayleighPhaseVal = rayleighPhase(-cosTheta);
    float aerosolPhaseVal  = aerosolPhase(-cosTheta);

    for (int i = 0; i < INSCATTERING_STEPS; ++i)
    {
        float t = (float(i) + 0.5) * dt;
        vec3 p = rayOrigin + rayDir * t;

        float r = length(p);
        float h = r - PLANET_RADIUS;
        float normalizedH = h / ATM_THICKNESS;

        float sunCosTheta = dot(p / r, sunDir);

        vec3 aerosolAbs, aerosolScat, molAbs, molScat, ext;
        getAtmCoefficients(h, aerosolAbs, aerosolScat, molAbs, molScat, ext);

        vec3 transToSun = transmittanceFromLUT(sunCosTheta, normalizedH);

        vec3 multiIso = multiScatteringIsotropic(sunCosTheta, normalizedH, r);
        vec3 multiAni = multiScatteringAnisotropic(-cosTheta, h) * transToSun;

        vec3 singleScat = (molScat * rayleighPhaseVal + aerosolScat * aerosolPhaseVal) * transToSun;
        vec3 multiScat  = (multiIso + multiAni) * (molScat + aerosolScat);

        vec3 source = SUN_RADIANCE * (singleScat + multiScat);

        vec3 stepT = exp(-ext * dt);
        vec3 integrated = (source - source * stepT) / max(ext, vec3(1e-6));

        L += T * integrated;
        T *= stepT;
    }

    return L;
}

vec3 computeAtmosphereLUT(vec2 uv)
{
    float cosTheta = uv.x * 2.0 - 1.0;
    vec3 rayDir = vec3(sqrt(max(0.0, 1.0 - cosTheta * cosTheta)), 0.0, cosTheta);

    float r = mix(0.0, ATM_THICKNESS, uv.y);

    return computeInscattering(rayDir, r);
}