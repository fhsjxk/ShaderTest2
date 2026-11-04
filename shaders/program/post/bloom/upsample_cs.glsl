// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/lighting/tuning.glsl"

// Tent upsample of one bloom level into the next finer one. The finer level
// already holds its own downsample result, so this pass accumulates:
// each invocation reads only its own texel of the destination and adds the
// tent-filtered coarser level, which keeps it race free without blending.
//
// The buffer pair and the dispatch scale are injected by the build; see the note
// in downsample_cs.glsl.
uniform sampler2D BLOOM_SRC;

// Read-write image: not `writeonly` because the accumulation reads the texel
// written by the previous pass.
layout({{RT_BLOOM1_FORMAT}}) uniform image2D BLOOM_DST_IMG;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
// The destination is one level finer than the source level being read.
const vec2 workGroupsRender = vec2(BLOOM_SCALE, BLOOM_SCALE);

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dstSize = imageSize(BLOOM_DST_IMG);

    // Same cut-off as the downsample side: once the level is a single texel there
    // is nothing left to accumulate into.
    if (max(dstSize.x, dstSize.y) <= 1)
    {
        return;
    }

    if (any(greaterThanEqual(pixelCoordinate, dstSize)))
    {
        return;
    }

    vec2 uv    = (vec2(pixelCoordinate) + 0.5) / vec2(dstSize);
    vec2 texel = 1.0 / vec2(textureSize(BLOOM_SRC, 0)) * max(BLOOM_SPREAD, 1.0);

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
            sum += texture(BLOOM_SRC, uv + vec2(x, y) * texel).rgb * wx * wy;
        }
    }

    vec3 accumulated = imageLoad(BLOOM_DST_IMG, pixelCoordinate).rgb;
    // Bounded per write: the sum of the levels is the one place in this chain
    // that can grow without an obvious ceiling, and an inf here would smear over
    // the whole screen through the next tent taps.
    imageStore(BLOOM_DST_IMG, pixelCoordinate,
               vec4(guardHalf(accumulated + sum / 16.0), 1.0));
}
#endif
