#ifndef ATMOSPHERE
#define ATMOSPHERE

// Physically-inspired single scattering with a multi-scatter approximation,
// LUT based (transmittance + sky-view). Structure follows
// https://www.shadertoy.com/view/msXXDS (Bruneton style parameterisation).
//
// Units
//   distances      km  (PLANET_RADIUS is the real Earth radius)
//   coefficients   1/km (multiplied by exp(-altitude / scaleHeight))
//   radiance       scene-linear, unitless: this pack has no absolute exposure
//                  reference, everything is scaled to look right after ACES.
//
// Provenance of the numbers
//   Height scales and the ozone tent profile follow the US Standard Atmosphere.
//   The colour tints were fitted by eye against reference photographs; they are
//   authored as 0-255 sRGB triples and intentionally used *without* gamma
//   decoding, because the tuning was done in that space. Decoding them to linear
//   will shift the sky hue, so change them only together with the multipliers.

#include "/lib/prelude.glsl"
#include "/lib/color.glsl"

const int TRANSMITTANCE_STEPS = 32;
const int INSCATTERING_STEPS  = 32;

const float PLANET_RADIUS        = 6371.0;
const float ATMOSPHERE_THICKNESS = 100.0;
const float ATMOSPHERE_RADIUS    = PLANET_RADIUS + ATMOSPHERE_THICKNESS;

#ifdef ENABLE_SPECTRAL
#define vec34 vec4
#else
#define vec34 vec3
#endif

// Authored 0-255 tint → 0..1, used un-decoded (see header).
#define UNIT_TINT(r, g, b) (vec3(r, g, b) / 255.0)

#ifdef ENABLE_SPECTRAL

// Four spectral bands. Radiance is band-integrated, not per-nanometre.
const vec4 SUN_RADIANCE = vec4(1.68, 1.83, 1.99, 1.31);

const vec4 RAYLEIGH_SCATTERING_BASE = vec4(6.605e-3, 1.067e-2, 1.842e-2, 3.156e-2);

const vec4 OZONE_ABSORPTION_BASE    = vec4(3.472e-3, 3.914e-3, 1.349e-3, 11.03e-5) * 0.5;

const vec4 AEROSOL_ABSORPTION_BASE  = vec4(1.0) * 0.0003;
const vec4 AEROSOL_SCATTERING_BASE  = vec4(1.5908, 1.7711, 2.0942, 2.4033) * 0.6 * 0.035;

// Same tint as the RGB path, expressed as the pre-image of rgbFromSpectral.
const vec4 GROUND_ALBEDO = vec4(0.57, 0.45, 0.37, 0.8) * 0.1;

#else

// Scene radiance of the sun disc; ATMOSPHERE_SUN_INTENSITY is the exposure knob.
const vec3 SUN_RADIANCE = UNIT_TINT(225.0, 210.0, 205.0) * ATMOSPHERE_SUN_INTENSITY;

// Rayleigh: two authored tints blended to the hue used by the reference tuning,
// then normalised to the blue channel of the classic 0.03624 baseline.
const vec3 RAYLEIGH_SCATTERING_BASE =
    mix(vec3(46.0, 95.0, 233.0), vec3(46.0, 89.0, 207.0), 0.5) / 255.0 * 0.03624;

const vec3 OZONE_ABSORPTION_BASE = UNIT_TINT(190.0, 170.0, 0.0) * 0.0019;

const vec3 AEROSOL_ABSORPTION_BASE = vec3(1.0) * 0.0003;
const vec3 AEROSOL_SCATTERING_BASE = UNIT_TINT(160.0, 195.0, 255.0) * 0.03;

// Water-like ground, matching the blue haze colour of the reference tuning.
const vec3 GROUND_ALBEDO = UNIT_TINT(10.0, 40.0, 100.0);

#endif

// Scale heights, km — US Standard Atmosphere (8.5 km molecular, ~1.2 km haze).
const float MOLECULAR_HEIGHT_SCALE = 8.5;
const float AEROSOL_HEIGHT_SCALE   = 1.2;
const float AEROSOL_TURBIDITY      = 1.0;
const float AEROSOL_BASE_DENSITY   = 1.0;

// Spectral (4 band) → linear sRGB. The matrix was fitted so that a 4-band sun
// spectrum lands on the expected RGB ratios; the scale is a pure exposure match.
const mat4x3 SPECTRAL_TO_RGB = mat4x3(
    137.672389239975, -8.632904716299537, -1.7181567391931372,
    32.549094028629234, 91.29801417199785, -12.005406444382531,
    -38.91428392614275, 34.31665471469816, 29.89044807197628,
    8.572844237945445, -11.103384660054624, 117.47585277566478
);
const float SPECTRAL_TO_RGB_SCALE = 0.025;

// ═══ Scene glue ═════════════════════════════════════════════
// Minecraft's Y axis is in blocks; the atmosphere model is in km. 1 block =
// 0.02 km keeps the horizon at the height it has with the vanilla sky.
const float MC_SEA_LEVEL    = 64.0;
const float KM_PER_BLOCK    = 0.02;
const float MIN_ALTITUDE_KM = 0.001;

float altitudeFromEyePosition(float eyePosition)
{
    return max((eyePosition - MC_SEA_LEVEL) * KM_PER_BLOCK, MIN_ALTITUDE_KM);
}

// The sun disc is far smaller than a pixel, so it is faked by a very tight
// smoothstep scaled up by SUN_DISC_RADIANCE to keep the integrated energy.
// Fade bounds are the cosines of ~0.33° and ~0.26°; step() keeps the disc from
// bleeding outside the sun's angular radius.
const float SUN_DISC_FADE_START   = 0.999983;
const float SUN_DISC_FADE_END     = 1.00005;
const float SUN_DISC_EDGE_COS     = 0.9999893;
const float SUN_DISC_MIN_FRACTION = 0.02;
const float SUN_DISC_RADIANCE     = 1000.0;

float sunDiscMask(float cosAngle)
{
    float disc = smoothstep(SUN_DISC_FADE_START, SUN_DISC_FADE_END, cosAngle);
    return (disc * (1.0 - SUN_DISC_MIN_FRACTION) + SUN_DISC_MIN_FRACTION) * step(SUN_DISC_EDGE_COS, cosAngle);
}

// Sky-view LUT layout: the lowest SKYVIEW_GROUND_FRACTION of the V axis holds
// the below-horizon half, the rest is the sky.
const float SKYVIEW_GROUND_FRACTION = 0.125;

// ═══ Geometry ═══════════════════════════════════════════════

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

// Returns the nearest positive intersection distance, or -1.0 when the ray misses.
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

// ═══ Phase functions ════════════════════════════════════════

// Henyey-Greenstein, normalised over the sphere. g > 0 is forward scattering.
float hgPhase(float cosTheta, float g)
{
    float g2 = g * g;
    float denom = 1.0 + g2 + 2.0 * g * cosTheta;
    return INV_4PI * (1.0 - g2) / (denom * sqrt(denom));
}

// Haze phase: four HG lobes weighted so the result stays energy normalised
// (weights sum to 1), then gained by ATMOSPHERE_HAZE_GAIN. The multi-lobe shape
// reproduces the wide aerosol forward peak plus the soft back-scatter of the
// reference tuning; a single lobe cannot fit both ends of the curve.
const float HAZE_G0 = 0.62;
const float HAZE_G1 = 0.82;
const float HAZE_G2 = 0.93;
const float HAZE_G3 = 0.97;

const float HAZE_W0 = 0.650;
const float HAZE_W1 = 0.210;
const float HAZE_W2 = 0.112;
const float HAZE_W3 = 0.028;

float hazePhase(float cosTheta)
{
    float lobe = HAZE_W0 * hgPhase(cosTheta, HAZE_G0)
               + HAZE_W1 * hgPhase(cosTheta, HAZE_G1)
               + HAZE_W2 * hgPhase(cosTheta, HAZE_G2)
               + HAZE_W3 * hgPhase(cosTheta, HAZE_G3);
    return lobe * ATMOSPHERE_HAZE_GAIN;
}

// Rayleigh phase biased towards the anti-solar side so the horizon does not
// wash out. The first term is a hand-shaped lobe, the second the analytic
// Rayleigh phase; RAYLEIGH_ANALYTIC_MIX is the visual blend between them and is
// not an energy-conserving parameter.
const float RAYLEIGH_ANALYTIC_MIX = 0.8;

float rayleighPhase(float cosTheta)
{
    float shaped   = (1.0 / PI / 4.0) * 0.4 * -cosTheta + (1.0 / PI / 4.0) * 1.12;
    float analytic = (3.0 / (16.0 * PI)) * (1.0 + cosTheta * cosTheta);
    return mix(shaped, analytic, RAYLEIGH_ANALYTIC_MIX);
}

// ═══ Atmospheric coefficients ═══════════════════════════════

// Ozone tent profile, km.
const float OZONE_PEAK_ALTITUDE_KM  = 22.35;
const float OZONE_HALF_THICKNESS_KM = 35.66 * 0.5;

// Broadband absorption tail below the ozone peak. The three numbers come from a
// least-squares fit to a measured profile; the original data set was never
// recorded, so treat them as tuned rather than derived.
const float OZONE_TAIL_SCALE    = 1e-3;
const float OZONE_TAIL_DECAY    = 0.07771971;
const float OZONE_TAIL_EXPONENT = 1.16364243;

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

    aerosolAbsorption = AEROSOL_ABSORPTION_BASE * aerosolDensity * AEROSOL_TURBIDITY;
    aerosolScattering = AEROSOL_SCATTERING_BASE * aerosolDensity * AEROSOL_TURBIDITY;

    molecularScattering = RAYLEIGH_SCATTERING_BASE * exp(-h / MOLECULAR_HEIGHT_SCALE);

    float ozoneDensity = max(1.0 - abs(h - OZONE_PEAK_ALTITUDE_KM) / OZONE_HALF_THICKNESS_KM, 0.0);
    molecularAbsorption = OZONE_ABSORPTION_BASE * ozoneDensity;
    molecularAbsorption += OZONE_TAIL_SCALE * exp(-OZONE_TAIL_DECAY * pow(h + 1.0, OZONE_TAIL_EXPONENT));

    extinction = aerosolAbsorption + aerosolScattering + molecularAbsorption + molecularScattering;
}

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

// ═══ Sky-view LUT sampling (lat-long) ═══════════════════════

vec3 sampleSkyViewLUT(sampler2D skyViewLUT, vec3 viewDir, float viewHeight)
{
    // Horizon sits at SKYVIEW_GROUND_FRACTION; below it the V axis is remapped
    // linearly onto the ground half of the LUT.
    float r  = PLANET_RADIUS + viewHeight;
    float Vh = sqrt(max(0.0, r * r - PLANET_RADIUS * PLANET_RADIUS));
    float thetaHorizon = acos(clamp(Vh / r, 0.0, 1.0));

    float phi   = atan(viewDir.z, viewDir.x) + PI;
    float theta = acos(clamp(viewDir.y, -1.0, 1.0));

    float v;
    if (theta > thetaHorizon)
    {
        v = SKYVIEW_GROUND_FRACTION * (1.0 - (theta - thetaHorizon) / max(PI - thetaHorizon, 1e-6));
    }
    else
    {
        v = SKYVIEW_GROUND_FRACTION + (1.0 - theta / max(thetaHorizon, 1e-6)) * (1.0 - SKYVIEW_GROUND_FRACTION);
    }
    vec2 uv = vec2(phi / (2.0 * PI), clamp(v, 0.0, 1.0));
    return texture(skyViewLUT, uv).rgb;
}

vec3 rgbFromSpectral(vec4 L)
{
    return SPECTRAL_TO_RGB * L * SPECTRAL_TO_RGB_SCALE;
}

#endif
