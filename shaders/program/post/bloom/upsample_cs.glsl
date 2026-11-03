// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/lighting/tuning.glsl"

// Tent upsample of one bloom level into the next finer one. The finer level
// already holds its own downsample result, so this pass accumulates:
// each invocation reads only its own texel of the destination and adds the
// tent-filtered coarser level, which keeps it race free without blending.
#if BLOOM_LEVEL == 7
    #define SRC_TEX    {{RT_BLOOM8}}
    #define DST_IMG    {{RT_BLOOM7_IMG}}
    #define DST_FORMAT {{RT_BLOOM7_FORMAT}}
#elif BLOOM_LEVEL == 6
    #define SRC_TEX    {{RT_BLOOM7}}
    #define DST_IMG    {{RT_BLOOM6_IMG}}
    #define DST_FORMAT {{RT_BLOOM6_FORMAT}}
#elif BLOOM_LEVEL == 5
    #define SRC_TEX    {{RT_BLOOM6}}
    #define DST_IMG    {{RT_BLOOM5_IMG}}
    #define DST_FORMAT {{RT_BLOOM5_FORMAT}}
#elif BLOOM_LEVEL == 4
    #define SRC_TEX    {{RT_BLOOM5}}
    #define DST_IMG    {{RT_BLOOM4_IMG}}
    #define DST_FORMAT {{RT_BLOOM4_FORMAT}}
#elif BLOOM_LEVEL == 3
    #define SRC_TEX    {{RT_BLOOM4}}
    #define DST_IMG    {{RT_BLOOM3_IMG}}
    #define DST_FORMAT {{RT_BLOOM3_FORMAT}}
#elif BLOOM_LEVEL == 2
    #define SRC_TEX    {{RT_BLOOM3}}
    #define DST_IMG    {{RT_BLOOM2_IMG}}
    #define DST_FORMAT {{RT_BLOOM2_FORMAT}}
#else
    #define SRC_TEX    {{RT_BLOOM2}}
    #define DST_IMG    {{RT_BLOOM1_IMG}}
    #define DST_FORMAT {{RT_BLOOM1_FORMAT}}
#endif

uniform sampler2D SRC_TEX;

// Read-write image: not `writeonly` because the accumulation reads the texel
// written by the previous pass.
layout(DST_FORMAT) uniform image2D DST_IMG;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
// The destination is one level finer than the source level being read.
const vec2 workGroupsRender = vec2(0.5 / float(1 << (BLOOM_LEVEL - 1)));

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dstSize = imageSize(DST_IMG);
    if (any(greaterThanEqual(pixelCoordinate, dstSize)))
    {
        return;
    }

    vec2 uv    = (vec2(pixelCoordinate) + 0.5) / vec2(dstSize);
    vec2 texel = 1.0 / vec2(textureSize(SRC_TEX, 0)) * max(BLOOM_SPREAD, 1.0);

    // 3x3 tent: weights 1-2-1 per axis, normalised by 16. BLOOM_SPREAD widens
    // the taps so the cascade reaches far enough across the screen; the source
    // levels are already blurred, so the bilinear filter fills the gaps.
    vec3 sum = vec3(0.0);
    for (int y = -1; y <= 1; ++y)
    {
        for (int x = -1; x <= 1; ++x)
        {
            float wx = (x == 0) ? 2.0 : 1.0;
            float wy = (y == 0) ? 2.0 : 1.0;
            sum += texture(SRC_TEX, uv + vec2(x, y) * texel).rgb * wx * wy;
        }
    }

    vec3 accumulated = imageLoad(DST_IMG, pixelCoordinate).rgb;
    imageStore(DST_IMG, pixelCoordinate, vec4(accumulated + sum / 16.0, 1.0));
}
#endif
