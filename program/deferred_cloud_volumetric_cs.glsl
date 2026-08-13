// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}

// TEMP TEST

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"

uniform sampler2D depthtex0;
uniform sampler2D {{RT_BACK}};
uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunDirection;
uniform float eyeAltitude;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;

layout({{IMG_BACK_FORMAT}}) uniform writeonly image2D {{IMG_BACK}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

const float CLOUD_BASE      = 300.0;
const float CLOUD_THICKNESS = 200.0;
const float CLOUD_TOP       = CLOUD_BASE + CLOUD_THICKNESS;
const float CLOUD_COVERAGE  = 0.35;
const float CLOUD_DENSITY   = 35.0;

const float STEP_SIZE       = 60.0;
const float SHADOW_STEP     = 8.0;
const float NOISE_SCALE     = 0.003;

const float ABSORPTION      = 0.05;
const vec3  CLOUD_ALBEDO    = vec3(0.9, 0.92, 1.0);

float hash3(vec3 p)
{
    p  = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(mix(hash3(i + vec3(0,0,0)), hash3(i + vec3(1,0,0)), u.x),
            mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), u.x), u.y),
        mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), u.x),
            mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), u.x), u.y),
        u.z);
}

float fbm3(vec3 p)
{
    float sum = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++)
    {
        sum += noise3(p) * amp;
        p = p * 2.31 + 17.0;
        amp *= 0.5;
    }
    return sum / 0.9375;
}

float cloudDensity(vec3 worldPos)
{
    if (worldPos.y < CLOUD_BASE || worldPos.y > CLOUD_TOP) return 0.0;

    float hNorm = (worldPos.y - CLOUD_BASE) / CLOUD_THICKNESS;
    float capBottom = smoothstep(0.0, 0.25, hNorm);
    float capTop    = 1.0 - smoothstep(0.55, 1.0, hNorm);
    float shape     = capBottom * capTop;

    float n = fbm3(worldPos * NOISE_SCALE);

    float density = max(n - (1.0 - CLOUD_COVERAGE), 0.0) * shape;
    return density * CLOUD_DENSITY;
}

float cloudShadow(vec3 from, vec3 dir)
{
    float t = 0.0;
    float optical = 0.0;
    for (int i = 0; i < 4; i++)
    {
        vec3 p = from + dir * t;
        if (p.y > CLOUD_TOP || p.y < CLOUD_BASE) break;
        optical += cloudDensity(p) * SHADOW_STEP;
        t += SHADOW_STEP;
    }
    return exp(-optical * ABSORPTION);
}

float dualHG(vec3 viewDir, vec3 lightDir, float intensity)
{
    float cosTheta = dot(viewDir, lightDir);

    const float gForward = 0.9;
    const float gBack    = -0.3;
    const float weight   = 0.2;

    return mix(hgPhase(cosTheta, gForward), hgPhase(cosTheta, gBack), 1.0 - weight) * intensity;
}

// HanPi Volume Cloud © AshenOneArt
// https://github.com/AshenOneArt/HPVolumeCloud

const float PHIFWD_OMEGA0        = 0.999;
const float PHIFWD_KAPPA_OD_SCALE = sqrt(3.0 * (1.0 - PHIFWD_OMEGA0));
const float PHIFWD_INTENSITY     = 1.5;
const float PHIFWD_DEPTH_POW     = 1.0;
const float PHIFWD_BOTTOM_BIAS   = 0.2;
const float PHIFWD_MS_BUILD      = 4.0;
const float PHIFWD_COMPRESS      = 1.0;
float hpPhiFwd(vec3 samplePos, vec3 sunDir, float localHeight)
{
    float bottomSoftH = 0.1;
    float bottomConf  = (PHIFWD_DEPTH_POW > 0.0)
        ? 1.0 - exp(-max(localHeight + PHIFWD_BOTTOM_BIAS, 0.0)
                    / bottomSoftH * PHIFWD_DEPTH_POW)
        : 1.0;

    float phi   = 0.0;
    float Tcum  = 1.0;
    float odSum = 0.0;
    float dist  = 0.0;

    for (int j = 0; j < 4; j++)
    {
        vec3 p = samplePos + sunDir * (dist + STEP_SIZE * 0.5);
        float density = cloudDensity(p);
        if (density > 0.001)
        {
            float sigmaT  = density;
            float sigmaS  = sigmaT * PHIFWD_OMEGA0;
            float localOD = sigmaT * STEP_SIZE;
            float qSrc    = sigmaS * STEP_SIZE;                       // Q = σ_s·Δs
            float invD    = sigmaT;                                   // 1/D ≈ σ_t
            float kappaStep = localOD * PHIFWD_KAPPA_OD_SCALE;
            float perSrcExp = exp(-(odSum + kappaStep * 0.5));        // e^{-∫κ ds}
            float msBuild   = 1.0 - exp(-(odSum + localOD * 0.5) * PHIFWD_MS_BUILD);
            float invR      = 1.0 / max(dist + STEP_SIZE * 0.5, STEP_SIZE * 0.5);

            phi += Tcum * qSrc * invD * bottomConf * msBuild * perSrcExp * invR;

            odSum += localOD;
            Tcum  *= exp(-localOD * (1.0 - PHIFWD_OMEGA0));
        }
        dist += STEP_SIZE;
    }

    return phi;
}

void cloudScatter(vec3 cameraPos, vec3 viewDir, vec3 sunDir, vec2 seed,
                  out vec3 inScatter, out vec3 transmittance)
{
    inScatter     = vec3(0.0);
    transmittance = vec3(1.0);

    float tEnter = (CLOUD_BASE - cameraPos.y) / viewDir.y;
    float tExit  = (CLOUD_TOP  - cameraPos.y) / viewDir.y;
    float tNear = max(min(tEnter, tExit), 0.0);
    float tFar  = max(tEnter, tExit);
    if (tFar <= tNear) return;

    float dither = hash3(vec3(seed, fract(frameTimeCounter) * 1000.0));
    float t = tNear + dither * STEP_SIZE;
    //float t = tNear;

    for (int i = 0; i < 16; i++)
    {
        if (t >= tFar) break;
        vec3 p = cameraPos + viewDir * t;
        float density = cloudDensity(p);
        if (density > 0.001)
        {
            float shadow = cloudShadow(p, sunDir);

            vec3 src = CLOUD_ALBEDO
                     * dualHG(viewDir, sunDir, shadow * 0.4)
                     * density * STEP_SIZE
                     + vec3(0.02, 0.03, 0.05) * 2.0;

            float localHeight = (p.y - CLOUD_BASE) / CLOUD_THICKNESS;
            float phi = hpPhiFwd(p, sunDir, localHeight);
            float phiScalar = phi * PHIFWD_INTENSITY;
            float phiMapped = (PHIFWD_COMPRESS > 0.0)
                ? (1.0 - exp(-phiScalar * PHIFWD_COMPRESS)) / PHIFWD_COMPRESS
                : phiScalar;
            vec3 phiSrc = CLOUD_ALBEDO * phiMapped;

            float dOpt  = density * STEP_SIZE * ABSORPTION;
            float Tstep = exp(-dOpt);

            inScatter     += transmittance * (src + phiSrc) * (1.0 - Tstep);
            transmittance *= Tstep;
        }
        t += STEP_SIZE;
    }
}

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 fullRes = ivec2(viewWidth, viewHeight);
    if (any(greaterThanEqual(pixelCoord, fullRes))) return;

    float depth = texelFetch(depthtex0, pixelCoord, 0).r;

    if (depth < 1.0)
    {
        return;
    }

    vec2 uv  = (vec2(pixelCoord) + 0.5) / vec2(viewWidth, viewHeight);
    vec3 clipPos   = vec3(uv * 2.0 - 1.0, 1.0);
    vec3 viewPos   = (gbufferProjectionInverse * vec4(clipPos, 1.0)).xyz;
    vec3 viewDir   = normalize(mat3(gbufferModelViewInverse) * viewPos);
    vec3 sunDir    = normalize(sunDirection);
    vec3 cameraPos = vec3(0.0, eyeAltitude, 0.0);

    vec3 background = texelFetch({{RT_BACK}}, pixelCoord, 0).rgb;

    vec3 cloudScat;
    vec3 cloudTrans;
    cloudScatter(cameraPos, viewDir, sunDir, vec2(pixelCoord), cloudScat, cloudTrans);

    float tEntry = max((CLOUD_BASE - cameraPos.y) / viewDir.y, 0.0);
    float distToCloud = length(viewDir * tEntry);
    float aerial = exp(-distToCloud * 0.0001);

    vec3 cloudOpacity = vec3(1.0) - cloudTrans;
    vec3 cloudContrib = cloudScat * aerial;

    vec3 outColor = background * (vec3(1.0) - cloudOpacity * aerial)
                  + cloudContrib;

    imageStore({{IMG_BACK}}, pixelCoord, vec4(outColor, 1.0));
}
