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

//#define UE
#define UE_M_3

#ifdef ENABLE_SPECTRAL
const vec4 SUN_RADIANCE                 = vec4(1.68, 1.83, 1.99, 1.31);

const vec4 RAYLEIGH_SCATTERING_BASE     = vec4(6.605e-3, 1.067e-2, 1.842e-2, 3.156e-2);

const vec4 OZONE_ABSORPTION_BASE        = vec4(3.472e-3, 3.914e-3, 1.349e-3, 11.03e-5) * 0.5;

const vec4 AEROSOL_ABSORPTION_BASE      = vec4(1) * 0.005;
//const vec4 AEROSOL_SCATTERING_BASE      = vec4(0.9) * 0.01;
const vec4 AEROSOL_SCATTERING_BASE      = vec4(1.5908, 1.7711, 2.0942, 2.4033) * 0.6 * 0.02;

const vec4 GROUND_ALBEDO         = vec4(0.57, 0.45, 0.37, 0.8) * 0.1; // = rgbFromSpectral^-1(vec3(15,45,100)/255)
#elif defined(UE)

const vec3 SUN_RADIANCE          = vec3(1) * 6.0;
const vec3 RAYLEIGH_SCATTERING_BASE = vec3(41, 95, 233) / 255.0 * 0.03624;
const vec3 OZONE_ABSORPTION_BASE = vec3(83, 241, 11) / 255.0 * 0.00199;
const vec3 AEROSOL_ABSORPTION_BASE = vec3(147, 147, 147)/255.0 * 0.00077;
const vec3 AEROSOL_SCATTERING_BASE = vec3(147, 147, 147)/255.0 * 0.00692;
const vec3 GROUND_ALBEDO         = vec3(15, 45, 100)/255.0 * 0.7;

#elif defined(UE_M)

const vec3 SUN_RADIANCE          = vec3(1) * 6.0;
const vec3 RAYLEIGH_SCATTERING_BASE = vec3(41, 95, 233) / 255.0 * 0.03624;
const vec3 OZONE_ABSORPTION_BASE = vec3(255, 241, 11) / 255.0 * 0.001;
const vec3 AEROSOL_ABSORPTION_BASE = vec3(1) * 0.01;
const vec3 AEROSOL_SCATTERING_BASE = vec3(190, 210, 255)/255.0 * 0.02;
const vec3 GROUND_ALBEDO         = vec3(0, 0, 0)/255.0;

#elif defined(UE_M_2)

const vec3 SUN_RADIANCE          = vec3(0.95, 1.0, 1.0) * 6.0;
//const vec3 RAYLEIGH_SCATTERING_BASE = vec3(41, 95, 233) / 255.0 * 0.03624;
//const vec3 RAYLEIGH_SCATTERING_BASE = vec3(46, 89, 207) / 255.0 * 0.03624;
const vec3 RAYLEIGH_SCATTERING_BASE = mix(vec3(46, 95, 233), vec3(46, 89, 207), 0.5) / 255.0 * 0.03624;
const vec3 OZONE_ABSORPTION_BASE = vec3(190, 170, 0) / 255.0 * 0.0015;
const vec3 AEROSOL_SCATTERING_BASE = vec3(185, 210, 255)/255.0 * 0.02;
//const vec3 AEROSOL_SCATTERING_BASE = vec3(165, 200, 255)/255.0 * 0.02;
const vec3 AEROSOL_ABSORPTION_BASE = vec3(1) * 0.005;
const vec3 GROUND_ALBEDO         = vec3(20, 40, 100)/255.0 * 1;

#elif defined(UE_M_3)

const vec3 SUN_RADIANCE          = vec3(0.95, 0.98, 1.0) * 6.0;
//const vec3 RAYLEIGH_SCATTERING_BASE = vec3(41, 95, 233) / 255.0 * 0.03624;
//const vec3 RAYLEIGH_SCATTERING_BASE = vec3(46, 89, 207) / 255.0 * 0.03624;
const vec3 RAYLEIGH_SCATTERING_BASE = mix(vec3(46, 95, 233), vec3(46, 89, 207), 0.5) / 255.0 * 0.03624;
const vec3 OZONE_ABSORPTION_BASE = vec3(190, 170, 0) / 255.0 * 0.0015;
const vec3 AEROSOL_SCATTERING_BASE = vec3(180, 203, 255)/255.0 * 0.05;
//const vec3 AEROSOL_SCATTERING_BASE = vec3(165, 200, 255)/255.0 * 0.02;
const vec3 AEROSOL_ABSORPTION_BASE = vec3(1) * 0.0005;
const vec3 GROUND_ALBEDO         = vec3(20, 40, 100)/255.0 * 1;

#else

//const vec3 SUN_RADIANCE          = vec3(1.24, 1.15, 1.00) * 6.0;
//const vec3 SUN_RADIANCE          = vec3(1.02148, 0.98584, 1.0752) * 6.0;
//const vec3 SUN_RADIANCE          = vec3(1, 0.8794, 0.8267) * 7;

//const vec3 SUN_RADIANCE          = vec3(1.6695, 1.8824, 1.8963) * 4;
//const vec3 SUN_RADIANCE          = vec3(1.500, 1.864, 1.715) * 4;
//const vec3 SUN_RADIANCE          = vec3(1.72, 1.58, 1.44) * 4;
const vec3 SUN_RADIANCE          = vec3(1.7, 1.85, 1.89) * 4;

//const vec3 RAYLEIGH_SCATTERING_BASE = vec3(4.6049e-03, 1.2345e-02, 4.9413e-02);
const vec3 RAYLEIGH_SCATTERING_BASE = vec3(6.6049e-03, 1.2345e-02, 2.9413e-02); // ARPC spectral integral
//const vec3 RAYLEIGH_SCATTERING_BASE = vec3(5.83e-03, 1.35e-02, 3.62e-02); // UE: vec3(41,95,255)/255 * 0.03624
//const vec3 RAYLEIGH_SCATTERING_BASE = vec3(4.5e-03, 1.8e-02, 4.0e-02);
//const vec3 RAYLEIGH_SCATTERING_BASE = vec3(41,95,255)/255.0 * 0.03624;

const vec3 OZONE_ABSORPTION_BASE = vec3(2.2911e-03, 1.5404e-03, 0.0);
//const vec3 OZONE_ABSORPTION_BASE = vec3(83, 241, 11) / 255.0 * 0.002;
//const vec3 OZONE_ABSORPTION_BASE = vec3(0);

//const vec3 AEROSOL_ABSORPTION_BASE = vec3(255, 255, 85)/255.0 * 0.015;
//const vec3 AEROSOL_ABSORPTION_BASE = vec3(1.0) * 0.005;
//const vec3 AEROSOL_ABSORPTION_BASE = vec3(0.05, 0.25, 0.5) * 0.01;
//const vec3 AEROSOL_ABSORPTION_BASE = vec3(1.0) * 0.005;
//const vec3 AEROSOL_ABSORPTION_BASE = mix(vec3(130, 185, 255)/255.0, vec3(1), 0.0) * 0.1;
////const vec3 AEROSOL_ABSORPTION_BASE = mix(vec3(0.1, 0.5, 0.8), vec3(0.8), 0.6) * 0.03 * 0.0;
//const vec3 AEROSOL_ABSORPTION_BASE = mix(vec3(0.1, 0.5, 0.8), vec3(0.8), 0.99) * 0.01;
//const vec3 AEROSOL_ABSORPTION_BASE = vec3(1.0, 1.0, 0.6) * 0.005;

//const vec3 AEROSOL_ABSORPTION_BASE = vec3(1) * 0.005;
//const vec3 AEROSOL_ABSORPTION_BASE = vec3(1,0.8,0.5) * 0.01;
//const vec3 AEROSOL_ABSORPTION_BASE = vec3(1,0.9,0.7) * 0.01;
const vec3 AEROSOL_ABSORPTION_BASE = vec3(1) * 0.01;

//const vec3 AEROSOL_SCATTERING_BASE = mix(vec3(130, 185, 255)/255.0, vec3(1), 0.1) * 0.6;
//const vec3 AEROSOL_SCATTERING_BASE = vec3(1.0) * 0.01;
////const vec3 AEROSOL_SCATTERING_BASE = mix(vec3(130, 185, 255)/255.0, vec3(1), 0.8) * 0.03;
//const vec3 AEROSOL_SCATTERING_BASE = mix(vec3(130, 145, 255)/255.0, vec3(1), 0.3) * 0.01;
//const vec3 AEROSOL_SCATTERING_BASE = mix(vec3(130, 145, 255)/255.0, vec3(1), 0.5) * 0.015;
const vec3 AEROSOL_SCATTERING_BASE = vec3(190, 210, 255)/255.0 * 0.02;
//const vec3 AEROSOL_SCATTERING_BASE = vec3(1) * 0.01;

//const vec3 GROUND_ALBEDO         = vec3(15, 45, 100)/255.0;
//const vec3 GROUND_ALBEDO         = vec3(0.04, 0.08, 0.24);
const vec3 GROUND_ALBEDO         = vec3(15, 45, 100)/255.0 * 0.7;
#endif

const float MOLECULAR_HEIGHT_SCALE = 8.5;
//const float MOLECULAR_HEIGHT_SCALE = 8.67;

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
    #if defined(UE_M_3)
    return mix(hgPhase(cosTheta, 0.65), mix(hgPhase(cosTheta, 0.84), mix(hgPhase(cosTheta, 0.93), hgPhase(cosTheta, 0.98), 0.35), 0.5), 0.35) * 1.3;
    //return mix(hgPhase(cosTheta, 0.65), mix(hgPhase(cosTheta, 0.83), mix(hgPhase(cosTheta, 0.93), hgPhase(cosTheta, 0.98), 0.3), 0.45), 0.35) * 1.3;
    #else
    return mix(hgPhase(cosTheta, 0.6), mix(hgPhase(cosTheta, 0.91), mix(hgPhase(cosTheta, 0.96), hgPhase(cosTheta, 0.99), 0.3), 0.3), 0.15) * 1.3;
    #endif
    //return mix(hgPhase(cosTheta, 0.6), mix(hgPhase(cosTheta, 0.93), hgPhase(cosTheta, 0.99), 0.1), 0.1) * 1.2;
    //return mix(mix(, hgPhase(cosTheta, 0.95), 0.05), hgPhase(cosTheta, 0.99), 0.9) * 1.2; // multscatter
    //return mix(mix(mix(hgPhase(cosTheta, 0.55), hgPhase(cosTheta, 0.78), 0.4), hgPhase(cosTheta, 0.95), 0.1), hgPhase(cosTheta, 0.99), 0.05) * 1.2; // multscatter
    //return mix(mix(mix(hgPhase(cosTheta, 0.5), hgPhase(cosTheta, 0.75), 0.45), hgPhase(cosTheta, 0.93), 0.08), hgPhase(cosTheta, 0.99), 0.02) * 1.2; // multscatter
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

    const float ozonePeak = 22.35;
    const float ozoneHalfThickness = 35.66 * 0.5;
    float ozoneDensity = max(1.0 - abs(h - ozonePeak) / ozoneHalfThickness, 0.0);
    molecularAbsorption = OZONE_ABSORPTION_BASE * ozoneDensity;
    molecularAbsorption += 1e-3 * exp(-0.07771971 * pow(h + 1.0, 1.16364243));

    extinction = aerosolAbsorption + aerosolScattering + molecularAbsorption + molecularScattering;
}

// ── Multiple scattering ──────────────────────────────────────

vec34 multiScattering(sampler2D transmitLUT, float cosTheta, float normalizedAlt, float r)
{
    #ifndef MULTISCATTERING
    return vec34(0.0);
    #else
    float solidAngle = 2.0 * PI * (1.0 - sqrt(max(0.0, r*r - PLANET_RADIUS*PLANET_RADIUS)) / r);
    vec34 transToGround = transmittanceFromLUT(transmitLUT, PLANET_RADIUS, cosTheta);
    vec34 transGroundToSample = transmittanceFromLUT(transmitLUT, PLANET_RADIUS, 1.0) / transmittanceFromLUT(transmitLUT, PLANET_RADIUS + normalizedAlt * ATMOSPHERE_THICKNESS, 1.0);

    vec34 groundRadiance = (INV_4PI * solidAngle) *
                          (GROUND_ALBEDO / PI) *
                          transToGround * transGroundToSample *
                          max(0.0, cosTheta);

    float aerosolDensity = AEROSOL_BASE_DENSITY * exp(-normalizedAlt * ATMOSPHERE_THICKNESS / AEROSOL_HEIGHT_SCALE);

    vec34 approxMulti = 0.01 *
    #ifdef ENABLE_SPECTRAL
    vec4(0.217, 0.347, 0.594, 1.0)
    #else
    vec3(0.2, 0.35, 1.0)
    #endif
    / (1.0 + 5.0 * exp(-17.92 * cosTheta));
    // / (aerosolDensity + 1.0);

    return groundRadiance + approxMulti;
    #endif
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

// ── Inscattering ─────────────────────────────────────────────

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

    //rayLength = min(rayLength, 100.0);

    float dt = rayLength / float(INSCATTERING_STEPS);

    vec34 L = vec34(0.0);
    vec34 T = vec34(1.0);

    float rayleighPhaseVal = rayleighPhase(-cosTheta);
    float aerosolPhaseVal  = aerosolPhase(-cosTheta);

    //aerosolPhaseVal = mix(aerosolPhaseVal, 0.0, step(rayDirection.z, sunDirection.z));

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
                            + aerosolScattering   * aerosolPhaseVal) * transToSun;
        vec34 multiScatter  = multiScattering(transmitLUT, sunCosTheta, normalizedH, r) * (molecularScattering + aerosolScattering);

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
    vec3 rayDirection = vec3(sqrt(max(0.0, 1.0 - cosTheta * cosTheta)), cosTheta, 0.0);

    float r = mix(0.0, ATMOSPHERE_THICKNESS, uv.y);

    return computeInscattering(transmitLUT, sunDir, rayDirection, r);
}

// ── Sky view LUT sampling (lat-long) ────────────────────────

vec3 sampleSkyViewLUT(sampler2D skyViewLUT, vec3 viewDir, float viewHeight)
{
    // Ground at bottom (v < 0.125), horizon at 0.125, sky above
    float r  = PLANET_RADIUS + viewHeight;
    float Vh = sqrt(max(0.0, r * r - PLANET_RADIUS * PLANET_RADIUS));
    float thetaHorizon = acos(clamp(Vh / r, 0.0, 1.0));

    float phi   = atan(viewDir.z, viewDir.x) + PI;
    float theta = acos(clamp(viewDir.y, -1.0, 1.0));

    float groundFraction = 0.125;
    float v;
    if (theta > thetaHorizon)
    {
        v = groundFraction * (1.0 - (theta - thetaHorizon) / max(PI - thetaHorizon, 1e-6));
    }
    else
    {
        v = groundFraction + (1.0 - theta / max(thetaHorizon, 1e-6)) * (1.0 - groundFraction);
    }
    vec2 uv = vec2(phi / (2.0 * PI), clamp(v, 0.0, 1.0));
    return texture(skyViewLUT, uv).rgb;
}

vec3 rgbFromSpectral(vec4 L)
{
    return M * L * 0.025;
}

// ── Froxel (screen-space atmosphere volume) ─────────────────
// Froxel 使用指数分布距离：100m ~ 100km
// 层 0 = 最近（~100m 累积），层 7 = 最远（~100km 累积）

const int    FROXEL_LAYERS      = 8;
const float  FROXEL_MIN_DIST    = 0.1;    // 100 m
const float  FROXEL_MAX_DIST    = 1000.0; // 100 km

float froxelDepthToLayer(float viewDist)
{
    // Maps viewDist in [FROXEL_MIN_DIST, FROXEL_MAX_DIST] to layer index [0, 7]
    // using logarithmic distribution to match froxel computation
    float clamped = clamp(viewDist, FROXEL_MIN_DIST, FROXEL_MAX_DIST);
    float norm = log(clamped / FROXEL_MIN_DIST) / log(FROXEL_MAX_DIST / FROXEL_MIN_DIST);
    return norm * float(FROXEL_LAYERS) - 1.0;
}

vec4 sampleFroxel(sampler2D froxelTex, vec2 screenUV, float viewDist)
{
    // Map view distance to continuous layer index
    float layerF = froxelDepthToLayer(viewDist);
    float layer  = clamp(layerF, 0.0, float(FROXEL_LAYERS - 1));

    // Bilinear within layer + linear across layers = trilinear
    float layer0 = floor(layer);
    float layer1 = min(layer0 + 1.0, float(FROXEL_LAYERS - 1));
    float lerpFrac = layer - layer0;

    // Froxel atlas: 64 wide, 512 tall (8 layers × 64)
    float atlasH = 512.0;
    float layerH = 64.0;

    vec2 uv0 = vec2(screenUV.x, (screenUV.y * layerH + layer0 * layerH) / atlasH);
    vec2 uv1 = vec2(screenUV.x, (screenUV.y * layerH + layer1 * layerH) / atlasH);

    vec4 v0 = texture(froxelTex, uv0);
    vec4 v1 = texture(froxelTex, uv1);

    return mix(v0, v1, lerpFrac);
}

#endif