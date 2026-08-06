// ============================================================================
// prepare_atmosphere_froxel  —  屏幕空间大气散射 Froxel
// ============================================================================
//
// Froxel 是一个 3D 纹理（存储为 2D 图集），尺寸 64×512，布局：
//   8 层（layer），每层 64×64 像素
//
// 计算方法：严格遵循 computeInscattering（atmosphere.glsl）的实现，
// 仅将步进距离改为指数分布（100m ~ 100km），每两步写入对应层。
//
// 当光线到达地球内部或外太空时，将当前累积值填入剩余所有层并结束。
// ============================================================================

// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/atmosphere.glsl"

uniform vec3 sunDirection;
uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform float viewWidth;
uniform float viewHeight;
uniform float eyeAltitude;

layout({{IMG_FROXEL_FORMAT}}) uniform writeonly image2D {{IMG_FROXEL}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const ivec3 workGroups = ivec3(8, 8, 1); // dispatch 64×64 threads

// ── Write current (L, T) to a froxel layer ──────────────────

void writeLayer(ivec2 pixel, int layer, vec34 L, vec34 T)
{
    ivec2 storePos = ivec2(pixel.x, pixel.y + layer * 64);
    float transGray = dot(T.rgb, vec3(0.2126, 0.7152, 0.0722));
    #ifdef ENABLE_SPECTRAL
    imageStore({{IMG_FROXEL}}, storePos, vec4(rgbFromSpectral(L), transGray));
    #else
    imageStore({{IMG_FROXEL}}, storePos, vec4(L.rgb, transGray));
    #endif
}

// ── Fill remaining layers with current (L, T) and terminate ─

void fillAndStop(ivec2 pixel, int startLayer, vec34 L, vec34 T)
{
    for (int l = startLayer; l < FROXEL_LAYERS; l++)
    {
        writeLayer(pixel, l, L, T);
    }
}

void main()
{
    /*ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    ivec2 froxelSize = ivec2(64, 64);
    if (any(greaterThanEqual(pixel, froxelSize))) return;

    // ── Compute ray direction at this froxel pixel ───────────
    vec2 uv = (vec2(pixel) + 0.5) / vec2(froxelSize);
    vec3 clipPos = vec3(uv * 2.0 - 1.0, 1.0);
    vec3 viewPos = (gbufferProjectionInverse * vec4(clipPos, 1.0)).xyz;
    vec3 viewRay = mat3(gbufferModelViewInverse) * viewPos;
    vec3 rayDir = normalize(viewRay);

    // ── Atmosphere ray setup (identical to computeInscattering) ──
    float altitude = max((eyeAltitude - 64.0) * 0.02, 0.001);
    vec3 rayOrigin = vec3(0.0, PLANET_RADIUS + altitude, 0.0);
    vec3 sunDirN = normalize(sunDirection);
    float cosTheta = dot(rayDir, sunDirN);

    float atmosphereDist = raySphereIntersect(rayOrigin, rayDir, ATMOSPHERE_RADIUS);
    float groundDist = raySphereIntersect(rayOrigin, rayDir, PLANET_RADIUS);

    float rayLength = 0.0;
    bool inside = (length(rayOrigin) <= ATMOSPHERE_RADIUS);

    if (inside)
    {
        rayLength = (groundDist > 0.0) ? groundDist : atmosphereDist;
        // rayOrigin stays at camera position
    }
    else if (atmosphereDist > 0.0)
    {
        rayOrigin += rayDir * (atmosphereDist + 1e-4);
        float secondDist = raySphereIntersect(rayOrigin, rayDir, ATMOSPHERE_RADIUS);
        rayLength = (groundDist > 0.0) ? (groundDist - atmosphereDist) : secondDist;
    }
    else
    {
        // No atmosphere intersection — write zero for all layers and exit
        fillAndStop(pixel, 0, vec34(0.0), vec34(1.0));
        return;
    }

    if (rayLength <= 0.0)
    {
        fillAndStop(pixel, 0, vec34(0.0), vec34(1.0));
        return;
    }

    // ── Exponential distance steps: 100m to 100km ────────────
    const float FROXEL_MIN_DIST = 100.0;
    const float FROXEL_MAX_DIST = 100000.0;
    const int   FROXEL_STEPS = 16;

    float maxRay = min(rayLength, FROXEL_MAX_DIST);
    float logMin = log(FROXEL_MIN_DIST);
    float logMax = log(FROXEL_MAX_DIST);

    vec34 L = vec34(0.0);
    vec34 T = vec34(1.0);

    float rayleighPhaseVal = rayleighPhase(-cosTheta);
    float aerosolPhaseVal  = aerosolPhase(-cosTheta);

    for (int i = 0; i < FROXEL_STEPS; i++)
    {
        // Exponential step: sample position = center of [d_i, d_{i+1}]
        float d0 = exp(mix(logMin, logMax, float(i) / float(FROXEL_STEPS)));
        float d1 = exp(mix(logMin, logMax, float(i + 1) / float(FROXEL_STEPS)));
        float dt = d1 - d0;
        float t  = (d0 + d1) * 0.5;

        // ── Clamp to actual ray length ───────────────────────
        float sampleT = min(t, maxRay);
        vec3 p = rayOrigin + rayDir * sampleT;
        float r = length(p);

        // ── Check if sample is inside the planet (below surface) ──
        if (r <= PLANET_RADIUS)
        {
            // Below ground — clamp to ground level
            fillAndStop(pixel, (i + 1) / 2, L, T);
            return;
        }

        // ── Check if sample is outside the atmosphere ────────
        if (r >= ATMOSPHERE_RADIUS)
        {
            // Beyond atmosphere — keep current values for remaining layers
            fillAndStop(pixel, (i + 1) / 2, L, T);
            return;
        }

        float h = r - PLANET_RADIUS;
        float normalizedH = h / ATMOSPHERE_THICKNESS;
        float sunCosTheta = dot(p / r, sunDirN);

        vec34 aerosolAbsorption, aerosolScattering, molecularAbsorption, molecularScattering, ext;
        getAtmosphereCoefficients(h, aerosolAbsorption, aerosolScattering,
                                  molecularAbsorption, molecularScattering, ext);

        vec34 transToSun = transmittanceFromLUT({{IMG_TRANSMIT_LUT_SAMPLER}}, r, sunCosTheta);
        vec34 multiIso = multiScatteringIsotropic({{IMG_TRANSMIT_LUT_SAMPLER}}, sunCosTheta, normalizedH, r);

        vec34 singleScatter = (molecularScattering * rayleighPhaseVal
                            + aerosolScattering   * aerosolPhaseVal) * transToSun;
        vec34 multiScatter  = multiIso * (molecularScattering + aerosolScattering);
        vec34 source = SUN_RADIANCE * (singleScatter + multiScatter);

        vec34 stepT = exp(-ext * dt);
        vec34 integrated = (source - source * stepT) / max(ext, vec34(1e-6));

        L += T * integrated;
        T *= stepT;

        // ── Every 2 steps: write accumulated result to layer ──
        if ((i % 2) == 1)
        {
            writeLayer(pixel, i / 2, L, T);
        }

        // ── If we've reached the end of the ray, fill remaining ──
        if (d1 >= maxRay)
        {
            fillAndStop(pixel, (i + 1) / 2, L, T);
            return;
        }
    }*/

    // ── All 16 steps completed normally ──────────────────────
    // Layer 7 was already written at i=15, nothing more to do.
}
#endif
