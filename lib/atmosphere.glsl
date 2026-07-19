#ifndef ATMOSPHERE
#define ATMOSPHERE

/*
 * From https://www.shadertoy.com/view/msXXDS
 */

#include "/lib/math.glsl"
#include "/lib/color.glsl"
#include "/lib/options.glsl"

const int TRANSMITTANCE_STEPS    = 32;
const int INSCATTERING_STEPS     = 32;

const float PLANET_RADIUS        = 6371.0;
const float ATMOSPHERE_THICKNESS = 100.0;
const float ATMOSPHERE_RADIUS    = PLANET_RADIUS + ATMOSPHERE_THICKNESS;

#ifdef ENABLE_SPECTRAL
#define vec34 vec4
#else
#define vec34 vec3
#endif

#ifdef ENABLE_SPECTRAL
const vec4 SUN_RADIANCE                 = vec4(1.68, 1.83, 1.99, 1.31);

const vec4 RAYLEIGH_SCATTERING_BASE     = vec4(6.605e-3, 1.067e-2, 1.842e-2, 3.156e-2);

const vec4 OZONE_ABSORPTION_BASE        = vec4(3.472e-3, 3.914e-3, 1.349e-3, 11.03e-5) * 0.5;

const vec4 AEROSOL_ABSORPTION_BASE      = vec4(0.6) * 0.01;
const vec4 AEROSOL_SCATTERING_BASE      = vec4(0.9) * 0.015;

const vec4 GROUND_ALBEDO         = vec4(0.57, 0.45, 0.37, 0.8) * 0.1; // = rgbFromSpectral^-1(vec3(15,45,100)/255)
#else
const vec3 SUN_RADIANCE          = vec3(1.24, 1.15, 1.00) * 6.0;

const vec3 RAYLEIGH_SCATTERING_BASE = vec3(6.6049e-03, 1.2345e-02, 2.9413e-02); // ARPC spectral integral
//const vec3 RAYLEIGH_SCATTERING_BASE = vec3(5.83e-03, 1.35e-02, 3.62e-02); // UE: vec3(41,95,255)/255 * 0.03624
//const vec3 RAYLEIGH_SCATTERING_BASE = vec3(4.5e-03, 1.8e-02, 4.0e-02);
//const vec3 RAYLEIGH_SCATTERING_BASE = vec3(41,95,255)/255.0 * 0.03624;

const vec3 OZONE_ABSORPTION_BASE = vec3(2.2911e-03, 1.5404e-03, 0.0);
//const vec3 OZONE_ABSORPTION_BASE = vec3(0);

//const vec3 AEROSOL_ABSORPTION_BASE = vec3(255, 255, 85)/255.0 * 0.015;
//const vec3 AEROSOL_ABSORPTION_BASE = vec3(1.0) * 0.005;
//const vec3 AEROSOL_ABSORPTION_BASE = vec3(0.05, 0.25, 0.5) * 0.01;
//const vec3 AEROSOL_ABSORPTION_BASE = vec3(1.0) * 0.005;
//const vec3 AEROSOL_ABSORPTION_BASE = mix(vec3(130, 185, 255)/255.0, vec3(1), 0.0) * 0.1;
////const vec3 AEROSOL_ABSORPTION_BASE = mix(vec3(0.1, 0.5, 0.8), vec3(0.8), 0.6) * 0.03 * 0.0;
//const vec3 AEROSOL_ABSORPTION_BASE = mix(vec3(0.1, 0.5, 0.8), vec3(0.8), 0.99) * 0.01;
const vec3 AEROSOL_ABSORPTION_BASE = vec3(1.0, 1.0, 0.6) * 0.01;
//const vec3 AEROSOL_SCATTERING_BASE = mix(vec3(130, 185, 255)/255.0, vec3(1), 0.1) * 0.6;
//const vec3 AEROSOL_SCATTERING_BASE = vec3(1.0) * 0.01;
////const vec3 AEROSOL_SCATTERING_BASE = mix(vec3(130, 185, 255)/255.0, vec3(1), 0.8) * 0.03;
const vec3 AEROSOL_SCATTERING_BASE = mix(vec3(130, 145, 255)/255.0, vec3(1), 0.3) * 0.015;

//const vec3 GROUND_ALBEDO         = vec3(15, 45, 100)/255.0;
const vec3 GROUND_ALBEDO         = vec3(0.02, 0.04, 0.12);
#endif

const float MOLECULAR_HEIGHT_SCALE = 8.67;

const float AEROSOL_HEIGHT_SCALE = 1.2;
const float AEROSOL_TURBIDITY    = 1.0;
const float AEROSOL_BASE_DENSITY = 1.0;

const mat4x3 M = mat4x3(
    137.672389239975, -8.632904716299537, -1.7181567391931372,
    32.549094028629234, 91.29801417199785, -12.005406444382531,
    -38.91428392614275, 34.31665471469816, 29.89044807197628,
    8.572844237945445, -11.103384660054624, 117.47585277566478
);


float distanceToTopAtmosphereBoundary(float r, float mu)
{
    float discriminant = r * r * (mu * mu - 1.0) + ATMOSPHERE_RADIUS * ATMOSPHERE_RADIUS;
    return clamp(-r * mu + sqrt(max(0.0, discriminant)), 0.0, 1e6);
}

bool rayIntersectsGround(float r, float mu)
{
    return mu < 0.0 && r * r * (mu * mu - 1.0) + PLANET_RADIUS * PLANET_RADIUS >= 0.0;
}

vec34 transmittanceFromLUT(sampler2D transmitLUT, float r, float mu)
{
    if (rayIntersectsGround(r, mu))
    {
        return vec34(0.0);
    }

    float H = sqrt(ATMOSPHERE_RADIUS * ATMOSPHERE_RADIUS - PLANET_RADIUS * PLANET_RADIUS);
    float rho = sqrt(max(0.0, r * r - PLANET_RADIUS * PLANET_RADIUS));
    float d = distanceToTopAtmosphereBoundary(r, mu);
    float d_min = ATMOSPHERE_RADIUS - r;
    float d_max = rho + H;
    float x_mu = (d - d_min) / max(d_max - d_min, 1e-6);
    float x_r = 1.0 - rho / H;
    vec2 uv = vec2(clamp(x_mu, 0.0, 1.0), clamp(x_r, 0.0, 1.0));
    #ifdef ENABLE_SPECTRAL
    return texture(transmitLUT, uv);
    #else
    return texture(transmitLUT, uv).rgb;
    #endif
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

// ── Phase functions ──────────────────────────────────────────

float hgPhase(float cosTheta, float g)
{
    float g2 = g * g;
    float denom = 1.0 + g2 + 2.0 * g * cosTheta;
    return INV_4PI * (1.0 - g2) / (denom * sqrt(denom));
}

float aerosolPhase(float cosTheta)
{
    //return mix(hgPhase(cosTheta, 0.9),hgPhase(cosTheta, 0.7),0.3);
    //return mix(mix(hgPhase(cosTheta, 0.65), hgPhase(cosTheta, 0.85), 0.1), hgPhase(cosTheta, 0.95), 0.03);
    return mix(mix(hgPhase(cosTheta, 0.55), hgPhase(cosTheta, 0.8), 0.35), hgPhase(cosTheta, 0.95), 0.07) * 1.2; // multscatter
    return hgPhase(cosTheta, 0.5);
    return mix(hgPhase(cosTheta, 0.6), hgPhase(cosTheta, 0.95), 0.1);
}

float rayleighPhase(float cosTheta)
{
    return (3.0 / (16.0 * PI)) * (1.0 + cosTheta * cosTheta);
}

// ── Atmospheric coefficients ─────────────────────────────────

void getAtmosphereCoefficients(
    float h,
    out vec34 aerosolAbsorption,
    out vec34 aerosolScattering,
    out vec34 molecularAbsorption,
    out vec34 molecularScattering,
    out vec34 extinction
)
{
    h = max(h, 0.0);

    float aerosolDensity = AEROSOL_BASE_DENSITY * exp(-h / AEROSOL_HEIGHT_SCALE);

    aerosolAbsorption  = AEROSOL_ABSORPTION_BASE  * aerosolDensity * AEROSOL_TURBIDITY;
    aerosolScattering  = AEROSOL_SCATTERING_BASE  * aerosolDensity * AEROSOL_TURBIDITY;

    molecularScattering = RAYLEIGH_SCATTERING_BASE * exp(-h / MOLECULAR_HEIGHT_SCALE);

    // Ozone: Gaussian profile centered at LayerBase + LayerThickness/2
    const float ozonePeak = 22.35;
    const float ozoneHalfThickness = 35.66 * 0.5;
    float ozoneDensity = max(1.0 - abs(h - ozonePeak) / ozoneHalfThickness, 0.0);
    molecularAbsorption = OZONE_ABSORPTION_BASE * ozoneDensity;
    molecularAbsorption += 1e-3 * exp(-0.07771971 * pow(h + 1.0, 1.16364243));

    extinction = aerosolAbsorption + aerosolScattering + molecularAbsorption + molecularScattering;
}

// ── Multiple scattering ──────────────────────────────────────

vec34 multiScatteringIsotropic(sampler2D transmitLUT, float cosTheta, float normalizedAlt, float r)
{
    //return vec34(0.0);
    float solidAngle = 2.0 * PI * (1.0 - sqrt(max(0.0, r*r - PLANET_RADIUS*PLANET_RADIUS)) / r);
    vec34 transToGround = transmittanceFromLUT(transmitLUT, PLANET_RADIUS, cosTheta);
    vec34 transGroundToSample = transmittanceFromLUT(transmitLUT, PLANET_RADIUS, 1.0) / transmittanceFromLUT(transmitLUT, PLANET_RADIUS + normalizedAlt * ATMOSPHERE_THICKNESS, 1.0);

    vec34 groundRadiance = (INV_4PI * solidAngle) *
                          (GROUND_ALBEDO / PI) *
                          transToGround * transGroundToSample *
                          max(0.0, cosTheta);

    float aerosolDensity = AEROSOL_BASE_DENSITY * exp(-normalizedAlt * ATMOSPHERE_THICKNESS / AEROSOL_HEIGHT_SCALE);

    vec34 approxMulti = 0.015 *
    #ifdef ENABLE_SPECTRAL
    vec4(0.217, 0.347, 0.594, 1.0)
    #else
    vec3(0.2, 0.3, 1.0)
    #endif
    / (1.0 + 5.0 * exp(-17.92 * cosTheta))
    / (aerosolDensity + 1.0);

    return groundRadiance + approxMulti;
}

// ── Transmittance ────────────────────────────────────────────

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
    float x_r = 1.0 - uv.y;
    float rho = H * x_r;
    float r = sqrt(rho * rho + PLANET_RADIUS * PLANET_RADIUS);

    float d_min = ATMOSPHERE_RADIUS - r;
    float d_max = rho + H;
    float x_mu = uv.x;
    float d = d_min + x_mu * (d_max - d_min);

    float mu = (d < 1e-6) ? 1.0 : (H * H - rho * rho - d * d) / (2.0 * r * d);
    mu = clamp(mu, -1.0, 1.0);

    vec3 rayDirection = vec3(sqrt(max(0.0, 1.0 - mu * mu)), 0.0, mu);
    vec3 origin = vec3(0.0, 0.0, r);

    return computeTransmittance(origin, rayDirection);
}

// ── Inscattering ─────────────────────────────────────────────

vec34 computeInscattering(sampler2D transmitLUT, vec3 sunDirection, vec3 rayDirection, float altitude)
{
    vec3 rayOrigin = vec3(0.0, 0.0, PLANET_RADIUS + altitude);
    vec3 sunDirN = normalize(sunDirection.xzy);

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
    float aerosolPhaseVal  = aerosolPhase(-cosTheta);

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

        vec34 multiIso = multiScatteringIsotropic(transmitLUT, sunCosTheta, normalizedH, r);

        vec34 singleScatter = (molecularScattering * rayleighPhaseVal
                            + aerosolScattering   * aerosolPhaseVal) * transToSun;
        vec34 multiScatter  = multiIso * (molecularScattering + aerosolScattering);

        vec34 source = SUN_RADIANCE * (singleScatter + multiScatter);

        vec34 stepT = exp(-ext * dt);
        vec34 integrated = (source - source * stepT) / max(ext, vec34(1e-6));

        L += T * integrated;
        T *= stepT;
    }

    return L;
}

vec34 computeAtmosphereLUT(sampler2D transmitLUT, vec3 sunDir, vec2 uv)
{
    float cosTheta = uv.x * 2.0 - 1.0;
    vec3 rayDirection = vec3(sqrt(max(0.0, 1.0 - cosTheta * cosTheta)), 0.0, cosTheta);

    float r = mix(0.0, ATMOSPHERE_THICKNESS, uv.y);

    return computeInscattering(transmitLUT, sunDir, rayDirection, r);
}

vec3 rgbFromSpectral(vec4 L)
{
    return M * L * 0.025;
}

#endif