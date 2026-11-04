// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/universal/buffers.glsl"
#include "/lib/lighting/tuning.glsl"

uniform sampler2D {{RT_LUM}};
uniform float frameTime;

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

// One work group in one dispatch: the blocks are strided across the invocations
// and reduced through shared memory. The previous single-invocation loop was
// fine at 1080p (1980 blocks) but put every fetch on one dependency chain, and
// at 4K the buffer holds 8040 blocks.
shared float blockSum[256];
shared float blockWeight[256];

const int REDUCE_GROUP = 256;

void main()
{
    int tid = int(gl_LocalInvocationID.x);
    ivec2 lumSize = textureSize({{RT_LUM}}, 0);
    int total = lumSize.x * lumSize.y;

    // Weighted sum of the per-block log2(luma). Consecutive invocations read
    // consecutive texels, so the fetches coalesce.
    float localSum = 0.0;
    float localWeight = 0.0;
    for (int i = tid; i < total; i += REDUCE_GROUP)
    {
        vec2 value = texelFetch({{RT_LUM}}, ivec2(i % lumSize.x, i / lumSize.x), 0).rg;
        localSum    += value.x * value.y;
        localWeight += value.y;
    }

    blockSum[tid] = localSum;
    blockWeight[tid] = localWeight;
    barrier();

    // Fixed-order tree reduction: the sum is then bit-identical every frame,
    // which matters because a slightly different average would show up as
    // exposure shimmer.
    for (int stride = REDUCE_GROUP / 2; stride > 0; stride >>= 1)
    {
        if (tid < stride)
        {
            blockSum[tid]    += blockSum[tid + stride];
            blockWeight[tid] += blockWeight[tid + stride];
        }
        barrier();
    }

    if (tid != 0)
    {
        return;
    }

    // Undo the log encoding: the weighted mean of log2(luma) is the geometric
    // mean of luma.
    float averageLuma = exp2(blockSum[0] / max(blockWeight[0], EPS));

    // exposure = TARGET * (REFERENCE_LUMA / averageLuma)^STRENGTH, so the
    // reference scene receives exactly TARGET and every other scene is pulled
    // towards it by STRENGTH.
    float strength = clamp(EXPOSURE_ADAPT_STRENGTH, 0.0, 1.0);
    float target = EXPOSURE_TARGET
                 * pow(EXPOSURE_REFERENCE_LUMA / max(averageLuma, EPS), strength);
    target = clamp(target, EXPOSURE_MIN, EXPOSURE_MAX);

    // Frame-rate independent adaptation; EXPOSURE_ADAPT_RATE is 1/time-constant.
    float blend = 1.0 - exp(-frameTime * EXPOSURE_ADAPT_RATE);

    // Adapt on log2(exposure), not on the exposure itself. With a fixed fraction
    // of the *linear* distance, reaching a target below the current value takes
    // about 2.6x longer than reaching one above it (at the current tuning:
    // 2.30 s to darken against 0.88 s to brighten, both to within 0.25 stops),
    // so darkening crawled while brightening snapped. In log space one time
    // constant is the same number of stops in either direction.
    float currentLog = log2(max(exposureBlock.exposure, EPS));
    float targetLog  = log2(max(target, EPS));
    exposureBlock.exposure = exp2(mix(currentLog, targetLog, blend));
}
#endif
